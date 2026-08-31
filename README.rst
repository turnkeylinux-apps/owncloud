ownCloud - Share files, music, calendar
=======================================

`ownCloud`_ helps store your files, folders, contacts, photo galleries,
calendars and more on a server of your choosing. Access that folder from
your mobile device, your desktop, or a web browser. Access your data
wherever you are, when you need it.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- ownCloud Server 11:
   
   - Runs from the official ownCloud container image, pinned to a verified
     amd64 manifest digest.
   - Stores persistent configuration and user files under
     /var/lib/owncloud.
   - Uses Debian MariaDB and Redis services on a dedicated local Docker
     network.
   - Includes occ_ script for command line administration and configuration.
     Also includes turnkey-occ_ wrapper script (runs occ as www-data user).

     **Security note**: ownCloud updates require supervision and are not
     installed automatically. Use ``owncloud-update --check VERSION`` to
     inspect the official amd64 image digest, then run
     ``owncloud-update VERSION DIGEST`` after reviewing the release and
     backing up the appliance. See `ownCloud documentation`_ for upgrading.

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  ownCloud: username **admin**


.. _ownCloud: https://owncloud.org/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _occ: https://doc.owncloud.com/server/admin_manual/configuration/server/occ_command.html
.. _turnkey-occ: https://github.com/turnkeylinux-apps/owncloud/blob/master/overlay/usr/local/bin/turnkey-occ
.. _ownCloud documentation: https://doc.owncloud.com/server/11.0/admin_manual/maintenance/upgrading/manual_upgrade.html
.. _Adminer: https://www.adminer.org
