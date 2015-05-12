<?php

use Symfony\Component\Console\Application;

require_once '/var/www/owncloud/lib/base.php';

if(count($argv)!=2) die("usage: $argv[0] password\n");

print \OC::$server->getHasher()->hash($argv[1]);

?>
