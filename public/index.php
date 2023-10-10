<?php

include_once __DIR__ . '/../vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

if (config('app.env') == 'local') {
    $whoops = new \Whoops\Run;
    $whoops->pushHandler(new \Whoops\Handler\PrettyPageHandler);
    $whoops->register();
}

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
    ['GET', '/', 'Home::view', 'loggedIn'],
    ['GET', 'login', 'Login::view'],
    ['POST', 'login', 'Login::tryLogin', 'notLoggedIn'],
    ['GET', 'logout', 'Login::doLogout', 'loggedIn'],
    ['POST', 'impersonate', 'Login::impersonate', 'admin'],
    ['GET', 'callback/discord', 'Login::loginWithDiscord', 'notLoggedIn'],

    ['view', 'acl', 'acl', 'admin'],
    ['POST', 'acl', 'Acl::update', 'admin'],

    ['view', 'services', 'services', 'admin'],
    ['GET', 'service', 'Service::view', 'admin'],

    ['view', 'users', 'users', 'admin'],
    ['GET', 'user/new', 'User::new', 'admin'],
    ['POST', 'user/new', 'User::create', 'admin'],
    ['GET', 'user', 'User::view', 'admin'],
    ['POST', 'user', 'User::update', 'admin'],

    ['view', 'groups', 'groups', 'admin'],
    ['GET', 'group/new', 'Group::new', 'admin'],
    ['POST', 'group/new', 'Group::create', 'admin'],
    ['GET', 'group', 'Group::view', 'admin'],
    ['POST', 'group', 'Group::update', 'admin'],

    ['view', 'profile', 'profile', 'loggedIn'],
    ['POST', 'profile', 'Profile::update', 'loggedIn'],
]);
