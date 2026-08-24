#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
db_password=${TKL_TEST_DB_PASS:?TKL_TEST_DB_PASS is required}
base=https://localhost
remote_file=tkl-v19-acceptance-$$.txt
payload_one=/tmp/tkl-owncloud-payload-one.$$
payload_two=/tmp/tkl-owncloud-payload-two.$$
response=/tmp/tkl-owncloud-response.$$
headers=/tmp/tkl-owncloud-headers.$$
adminer_cookies=/tmp/tkl-owncloud-adminer-cookies.$$
update_check=/tmp/tkl-owncloud-update.$$
policy=/tmp/tkl-owncloud-policy.$$
test_user=tkl-v19-user-$$

report_error() {
    printf 'test_failure line=%s status=%s command=%q\n' \
        "$1" "$2" "$3" >&2
    exit "$2"
}
trap 'report_error "$LINENO" "$?" "$BASH_COMMAND"' ERR

cleanup() {
    curl --insecure --silent --user "admin:$app_password" --request DELETE \
        "$base/remote.php/dav/files/admin/$remote_file" >/dev/null 2>&1 || true
    OC_PASS=$app_password turnkey-occ user:delete "$test_user" >/dev/null 2>&1 || true
    rm -f -- "$payload_one" "$payload_two" "$response" "$headers" \
        "$adminer_cookies" "$update_check" "$policy"
}
trap cleanup EXIT

systemctl --quiet is-active docker.service owncloud-network.service \
    owncloud.service apache2.service mariadb.service redis-server.service \
    postfix.service multi-user.target
systemctl --quiet is-enabled docker.service owncloud-network.service \
    owncloud.service apache2.service mariadb.service redis-server.service \
    postfix.service
apache2ctl -t
apache2ctl -M 2>/dev/null | grep -F ' proxy_module ' >/dev/null
apache2ctl -M 2>/dev/null | grep -F ' proxy_http_module ' >/dev/null
test -e /etc/owncloud/configured

owncloud_version=$(turnkey-occ status | awk '/versionstring:/ {print $3}')
test "$owncloud_version" = 11.0.0
grep -Fxq 'version=11.0.0' /etc/owncloud/image-source
grep -Fxq \
    'digest=sha256:dbebc24fe77a35c5de621d38a3f7264ffb43e3ee321928cde9a563a72b8ff366' \
    /etc/owncloud/image-source
source /etc/owncloud/image.conf
test "$OWNCLOUD_VERSION" = 11.0.0
test "$OWNCLOUD_DIGEST" = \
    sha256:dbebc24fe77a35c5de621d38a3f7264ffb43e3ee321928cde9a563a72b8ff366
test "$(docker inspect --format '{{.Config.Image}}' owncloud_server)" = \
    "$OWNCLOUD_IMAGE"
test "$(docker inspect --format '{{.State.Running}}' owncloud_server)" = true
test "$(docker inspect --format '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}}{{end}}' owncloud_server)" = owncloud
test "$(docker network inspect --format '{{(index .IPAM.Config 0).Subnet}}' owncloud)" = 172.28.0.0/24
test "$(docker network inspect --format '{{(index .IPAM.Config 0).Gateway}}' owncloud)" = 172.28.0.1
docker_storage_driver=$(docker info --format '{{.Driver}}')
case "$docker_storage_driver" in
    overlay2|fuse-overlayfs) ;;
    *) echo "unexpected Docker storage driver: $docker_storage_driver" >&2; exit 1;;
esac

curl --insecure --silent --show-error --dump-header "$headers" \
    --output /dev/null http://localhost/
grep -Eq '^HTTP/.* 301' "$headers"
grep -Eqi '^location: https://localhost/' "$headers"
curl --insecure --fail --silent --show-error "$base/status.php" >"$response"
grep -q '"installed":true' "$response"
grep -q '"versionstring":"11.0.0"' "$response"
curl --insecure --fail --silent --show-error --location "$base/" >"$response"
grep -qi 'owncloud' "$response"

curl --insecure --fail --silent --show-error --user "admin:$app_password" \
    "$base/ocs/v1.php/cloud/user?format=json" >"$response"
grep -q '"statuscode":100' "$response"
grep -q '"id":"admin"' "$response"

printf 'ownCloud v19 first payload\n' >"$payload_one"
printf 'ownCloud v19 updated payload\n' >"$payload_two"
curl --insecure --fail --silent --show-error --user "admin:$app_password" \
    --upload-file "$payload_one" \
    "$base/remote.php/dav/files/admin/$remote_file"
curl --insecure --fail --silent --show-error --user "admin:$app_password" \
    "$base/remote.php/dav/files/admin/$remote_file" >"$response"
cmp "$payload_one" "$response"
curl --insecure --fail --silent --show-error --user "admin:$app_password" \
    --upload-file "$payload_two" \
    "$base/remote.php/dav/files/admin/$remote_file"
curl --insecure --fail --silent --show-error --user "admin:$app_password" \
    "$base/remote.php/dav/files/admin/$remote_file" >"$response"
cmp "$payload_two" "$response"
mariadb --batch --skip-column-names owncloud \
    --execute="SELECT path FROM oc_filecache WHERE name='$remote_file';" | \
    grep -F "/$remote_file"
curl --insecure --fail --silent --show-error --user "admin:$app_password" \
    --request DELETE "$base/remote.php/dav/files/admin/$remote_file"
if curl --insecure --silent --user "admin:$app_password" --output /dev/null \
    --write-out '%{http_code}' \
    "$base/remote.php/dav/files/admin/$remote_file" | grep -vq '^404$'; then
    echo 'deleted WebDAV file remained accessible' >&2
    exit 1
fi

OC_PASS=$app_password turnkey-occ user:add --password-from-env "$test_user"
turnkey-occ user:list | grep -F "$test_user"
mariadb --batch --skip-column-names owncloud \
    --execute="SELECT uid FROM oc_users WHERE uid='$test_user';" | \
    grep -Fx "$test_user"
turnkey-occ user:delete "$test_user"

ss -ltn | grep -Eq '127\.0\.0\.1:8080[[:space:]]'
ss -ltn | grep -Eq '172\.28\.0\.1:3306[[:space:]]'
ss -ltn | grep -Eq '172\.28\.0\.1:6379[[:space:]]'
if ss -ltn | grep -Eq '(0\.0\.0\.0|\[::\]):(3306|6379|8080)[[:space:]]'; then
    echo 'an ownCloud backend unexpectedly listens on every interface' >&2
    exit 1
fi
redis_password=$(sed -n 's/^OWNCLOUD_REDIS_PASSWORD=//p' \
    /etc/owncloud/owncloud.env)
redis-cli --host 172.28.0.1 --pass "$redis_password" ping 2>/dev/null | \
    grep -Fx PONG
if redis-cli --host 172.28.0.1 ping 2>&1 | grep -Fq PONG; then
    echo 'Redis accepted an unauthenticated request' >&2
    exit 1
fi

curl --insecure --fail --silent --show-error \
    https://127.0.0.1:12322/ >"$response"
grep -qi 'Adminer' "$response"
curl --insecure --silent --show-error --location \
    --cookie-jar "$adminer_cookies" --cookie "$adminer_cookies" \
    --data-urlencode 'auth[driver]=server' \
    --data-urlencode 'auth[server]=localhost' \
    --data-urlencode 'auth[username]=adminer' \
    --data-urlencode "auth[password]=$db_password" \
    --data-urlencode 'auth[db]=owncloud' \
    https://127.0.0.1:12322/ >"$response"
grep -qi 'owncloud' "$response"
grep -qi 'Logout' "$response"
if grep -qi 'Invalid credentials\|Access denied' "$response"; then
    echo 'Adminer rejected its firstboot MariaDB credentials' >&2
    exit 1
fi

docker_image_before=$(docker image inspect --format '{{.Id}}' "$OWNCLOUD_IMAGE")
owncloud-update --check 11.0.0 >"$update_check"
grep -Fxq 'version=11.0.0' "$update_check"
grep -Eq '^digest=sha256:[0-9a-f]{64}$' "$update_check"
grep -Fxq 'source=docker.io/owncloud/server' "$update_check"
test "$(docker image inspect --format '{{.Id}}' "$OWNCLOUD_IMAGE")" = \
    "$docker_image_before"

apache_version=$(dpkg-query -W -f='${Version}' apache2)
mariadb_version=$(dpkg-query -W -f='${Version}' mariadb-server)
redis_version=$(dpkg-query -W -f='${Version}' redis-server)
docker_version=$(dpkg-query -W -f='${Version}' docker.io)
docker_cli_version=$(dpkg-query -W -f='${Version}' docker-cli)
fuse_overlayfs_version=$(dpkg-query -W -f='${Version}' fuse-overlayfs)
skopeo_version=$(dpkg-query -W -f='${Version}' skopeo)
before="$apache_version|$mariadb_version|$redis_version|$docker_version|$docker_cli_version|$fuse_overlayfs_version|$skopeo_version"
apt-get update >/dev/null
for package in apache2 mariadb-server redis-server docker.io docker-cli fuse-overlayfs skopeo; do
    apt-cache policy "$package" >"$policy"
    candidate=$(awk '/Candidate:/ {print $2}' "$policy")
    test -n "$candidate"
    test "$candidate" != '(none)'
    grep -Eq 'trixie|deb13' "$policy"
done
after="$(dpkg-query -W -f='${Version}' apache2)|$(dpkg-query -W -f='${Version}' mariadb-server)|$(dpkg-query -W -f='${Version}' redis-server)|$(dpkg-query -W -f='${Version}' docker.io)|$(dpkg-query -W -f='${Version}' docker-cli)|$(dpkg-query -W -f='${Version}' fuse-overlayfs)|$(dpkg-query -W -f='${Version}' skopeo)"
test "$after" = "$before"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Debian 13 Trixie APT repositories for Docker Engine and client, fuse-overlayfs, Skopeo, Apache, MariaDB, Redis and Adminer; official ownCloud Server image from Docker Hub
installed_version=ownCloud $owncloud_version; apache2 $apache_version; mariadb-server $mariadb_version; redis-server $redis_version; docker.io $docker_version; docker-cli $docker_cli_version; fuse-overlayfs $fuse_overlayfs_version; skopeo $skopeo_version
runtime_checks=normal init; Docker storage driver $docker_storage_driver; private Docker network; official ownCloud container behind Apache HTTPS; firstboot administrator authentication; WebDAV file create, read, update and delete with MariaDB readback; turnkey-occ user create and delete; authenticated Redis; Adminer login
updater_command=owncloud-update --check 11.0.0; apt-get update and apt-cache policy apache2 mariadb-server redis-server docker.io docker-cli fuse-overlayfs skopeo
updater_result=official amd64 ownCloud image candidate and digest resolved without changing the running image; signed Trixie metadata refreshed with eligible candidates and installed versions unchanged
updater_channel=reviewed official ownCloud Server version tags on Docker Hub; Debian and TurnKey Trixie APT repositories
integrity_evidence=build source pins ownCloud amd64 manifest sha256:dbebc24fe77a35c5de621d38a3f7264ffb43e3ee321928cde9a563a72b8ff366; Skopeo verifies registry manifests and blobs; APT accepted signed metadata; no Bookworm source remained
EOF
