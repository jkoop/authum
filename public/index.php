<?php

include_once __DIR__ . '/../vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

if ($_ENV['APP_ENV'] == 'local') {
    $whoops = new \Whoops\Run;
    $whoops->pushHandler(new \Whoops\Handler\PrettyPageHandler);
    $whoops->register();
}

session_start();

DB::$user = $_ENV['DB_USERNAME'];
DB::$password = $_ENV['DB_PASSWORD'];
DB::$dbName = $_ENV['DB_DATABASE'];
DB::$host = $_ENV['DB_HOST']; //defaults to localhost if omitted
DB::$port = $_ENV['DB_PORT']; // defaults to 3306 if omitted
DB::$encoding = 'utf8'; // defaults to latin1 if omitted

doMigrations();

doRouting([
    // requestMethod, path, responseFunction, ?gateFunction
    ['', '_authum/forward-auth', 'ForwardAuth::handle'],
    ['view', '/', 'home', 'loggedIn'],
    ['GET', 'login', 'Login::view'], // , 'notLoggedIn'], // We need to use a controller because of forward auth
    ['POST', 'login', 'Login::tryLogin', 'notLoggedIn'],
    ['GET', 'logout', 'Login::doLogout', 'loggedIn'],
    ['view', 'users', 'users', 'admin'],
    ['GET', 'user', 'User::view', 'admin'],
]);
