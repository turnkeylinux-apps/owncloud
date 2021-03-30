ownCloud - Share files, music, calendar
=======================================

`ownCloud`_ helps store your files, folders, contacts, photo galleries,
calendars and more on a server of your choosing. Access that folder from
your mobile device, your desktop, or a web browser. Access your data
wherever you are, when you need it.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- ownCloud Server:
   
   - Installed from official zip file to /var/www/owncloud.

     **Security note**: Updates to ownCloud may require supervision so
     they **ARE NOT** configured to install automatically. See `ownCloud
     documentation`_ for upgrading.

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
.. _ownCloud documentation: https://doc.owncloud.org/server/10.6/admin_manual/maintenance/upgrade.html
.. _Adminer: https://www.adminer.org
