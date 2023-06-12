<?php

include_once __DIR__ . '/../vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

if (config('app.env') == 'local') {
    $whoops = new \Whoops\Run;
    $whoops->pushHandler(new \Whoops\Handler\PrettyPageHandler);
    $whoops->register();
}

session_start();

DB::$user = config('db.username');
DB::$password = config('db.password');
DB::$dbName = config('db.database');
DB::$host = config('db.host'); //defaults to localhost if omitted
DB::$port = config('db.port'); // defaults to 3306 if omitted
DB::$encoding = 'utf8'; // defaults to latin1 if omitted

doMigrations();
doDbPruning();

doRouting([
    // requestMethod, path, responseFunction, ?gateFunction
    ['', '_authum/forward-auth', 'ForwardAuth::handle'],
    ['view', '/', 'home', 'loggedIn'],
    ['GET', 'login', 'Login::view'], // , 'notLoggedIn'], // We need to use a controller because of forward auth
    ['POST', 'login', 'Login::tryLogin', 'notLoggedIn'],
    ['GET', 'logout', 'Login::doLogout', 'loggedIn'],

    ['view', 'acl', 'acl', 'admin'],
    ['POST', 'acl', 'Acl::update', 'admin'],

    ['view', 'services', 'services', 'admin'],
    ['GET', 'service', 'Service::view', 'admin'],

    ['view', 'service-groups', 'service-groups', 'admin'],
    ['GET', 'service-group', 'ServiceGroup::view', 'admin'],

    ['view', 'users', 'users', 'admin'],
    ['GET', 'user', 'User::view', 'admin'],
    ['POST', 'user', 'User::update', 'admin'],

    ['view', 'user-groups', 'user-groups', 'admin'],
    ['GET', 'user-group', 'UserGroup::view', 'admin'],
]);
