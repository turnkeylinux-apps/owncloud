#!/usr/bin/python3
"""Set ownCloud admin password and domain to serve

Option:
    --pass=     unless provided, will ask interactively
    --domain=   unless provided, will ask interactively
                DEFAULT=www.example.com
"""

import sys
import getopt
import json
import os
import subprocess
import time
import urllib.request

from libinithooks.dialog_wrapper import Dialog

DEFAULT_DOMAIN = "www.example.com"


def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)


def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'domain='])
    except getopt.GetoptError as e:
        usage(e)

    password = ""
    domain = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--domain':
            domain = val

    if not password:
        d = Dialog('TurnKey GNU/Linux - First boot configuration')
        password = d.get_password(
            "ownCloud Password",
            "Enter new password for the ownCloud 'admin' account.")

    if not domain:
        if 'd' not in locals():
            d = Dialog('TurnKey GNU/Linux - First boot configuration')

        domain = d.get_input(
            "ownCloud Domain",
            "Enter the domain to serve ownCloud.",
            DEFAULT_DOMAIN)

    if domain == "DEFAULT":
        domain = DEFAULT_DOMAIN

    occ = '/usr/local/bin/turnkey-occ'
    for _ in range(150):
        status = subprocess.run([occ, 'status'], check=False,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL,
                                text=True)
        if status.returncode == 0 and '- installed: true' in status.stdout:
            break
        time.sleep(2)
    else:
        raise RuntimeError('ownCloud did not become ready within 300 seconds')

    env = os.environ.copy()
    env['OC_PASS'] = password
    subprocess.run([occ, 'user:resetpassword', '--password-from-env', 'admin'],
                   check=True, env=env)
    subprocess.run([occ, 'config:system:set', 'trusted_domains', '1',
                    f'--value={domain}'], check=True)
    subprocess.run([occ, 'config:system:set', 'overwrite.cli.url',
                    f'--value=https://{domain}'], check=True)

    env_path = '/etc/owncloud/owncloud.env'
    with open(env_path, encoding='utf-8') as source:
        lines = source.readlines()
    replacements = {
        'OWNCLOUD_DOMAIN': domain,
        'OWNCLOUD_TRUSTED_DOMAINS': f'localhost,127.0.0.1,{domain}',
        'OWNCLOUD_OVERWRITE_CLI_URL': f'https://{domain}',
    }
    with open(env_path, 'w', encoding='utf-8') as target:
        for line in lines:
            key = line.partition('=')[0]
            if key == 'OWNCLOUD_ADMIN_PASSWORD':
                continue
            if key in replacements:
                target.write(f'{key}={replacements[key]}\n')
            else:
                target.write(line)
    os.chmod(env_path, 0o600)

    for _ in range(150):
        try:
            with urllib.request.urlopen(
                    'http://127.0.0.1:8080/status.php', timeout=2) as response:
                status = json.load(response)
            if status.get('installed') is True:
                break
        except (OSError, ValueError):
            pass
        time.sleep(2)
    else:
        raise RuntimeError('ownCloud HTTP endpoint was not ready within 300 seconds')

    with open('/etc/owncloud/configured', 'w', encoding='utf-8'):
        pass


if __name__ == "__main__":
    main()
