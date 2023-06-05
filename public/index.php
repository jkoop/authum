<?php

include __DIR__ . '/../vendor/autoload.php';
include __DIR__ . '/../functions.php';

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

if ($_ENV['APP_ENV'] == 'local') {
    $whoops = new \Whoops\Run;
    $whoops->pushHandler(new \Whoops\Handler\PrettyPageHandler);
    $whoops->register();
}

doRouting([
    ['view', '/login', 'login'],
]);
