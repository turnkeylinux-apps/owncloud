#!/usr/bin/python
"""Set ownCloud admin password and domain to serve

Option:
    --pass=     unless provided, will ask interactively
    --domain=   unless provided, will ask interactively
                DEFAULT=www.example.com
"""

import sys
import getopt
import subprocess
from subprocess import call
from os.path import *
from os import chdir

from dialog_wrapper import Dialog

def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

DEFAULT_DOMAIN="www.example.com"



def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'domain='])
    except getopt.GetoptError, e:
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

    sedcom = """
        /0 => 'localhost',/ a\
    1 => '%s',
    """

    call(['sed', '-i', "/1 => /d", '/usr/share/owncloud/config/config.php'])
    call(['sed', '-i', sedcom % domain, '/usr/share/owncloud/config/config.php'])

    chdir("/usr/share/owncloud")
    call(['sudo', '-Eu', 'www-data', 'php', 'occ', 'user:resetpassword', '--password-from-env', 'admin'],env={"OC_PASS":password})

if __name__ == "__main__":
    main()

