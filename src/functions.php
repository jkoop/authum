<?php

include_once __DIR__ . '/../vendor/autoload.php';

const AUTHUM_VERSION = 'dev';
define('REQUEST_PATH', ltrim(explode('?', $_SERVER['REQUEST_URI'])[0], '/'));

function config(string $key): string|int|float|null {
    return match ($key) {
        'app.env' => trim($_ENV['APP_ENV']),
        'app.url' => rtrim($_ENV['APP_URL'], '/'),
        'db.host' => trim($_ENV['DB_HOST']),
        'db.post' => (int) $_ENV['DB_PORT'],
        'db.database' => trim($_ENV['DB_DATABASE']),
        'db.username' => trim($_ENV['DB_USERNAME']),
        'db.password' => trim($_ENV['DB_PASSWORD']),
        'db.pruning-lottery' => (int) $_ENV['DB_PRUNING_LOTTERY'],
        'discord.enabled' => (bool) config('discord.client_id') && config('discord.client_secret'),
        'discord.client_id' => $_ENV['DISCORD_CLIENT_ID'] ?? null,
        'discord.client_secret' => $_ENV['DISCORD_CLIENT_SECRET'] ?? null,
        'session.timeout' => $_ENV['SESSION_TIMEOUT'] * 60,
        default => null,
    };
}

function abort(int $status, string $message = null): never {
    if ($status < 400 || $status > 599) throw new InvalidArgumentException('$status must between 400 and 599, inclusive');

    static $defaultMessages = [
        '400' => 'Bad Request',
        '401' => 'Unauthorized',
        '402' => 'Payment Required',
        '403' => 'Forbidden',
        '404' => 'Not Found',
        '405' => 'Method Not Allowed',
        '406' => 'Not Acceptable',
        '407' => 'Proxy Authentication Required',
        '408' => 'Request Timeout',
        '409' => 'Conflict',
        '410' => 'Gone',
        '411' => 'Length Required',
        '412' => 'Precondition Failed',
        '413' => 'Payload Too Large',
        '414' => 'URI Too Long',
        '415' => 'Unsupported Media Type',
        '416' => 'Range Not Satisfiable',
        '417' => 'Expectation Failed',
        '418' => "I'm a teapot",
        '421' => 'Misdirected Request',
        '422' => 'Unprocessable Entity',
        '423' => 'Locked',
        '424' => 'Failed Dependency',
        '425' => 'Too Early',
        '426' => 'Upgrade Required',
        '428' => 'Precondition Required',
        '429' => 'Too Many Requests',
        '431' => 'Request Header Fields Too Large',
        '451' => 'Unavailable For Legal Reasons',
        '500' => 'Server Error',
        '501' => 'Not Implemented',
        '502' => 'Bad Gateway',
        '503' => 'Service Unavailable',
        '504' => 'Gateway Timeout',
        '505' => 'HTTP Version Not Supported',
        '506' => 'Variant Also Negotiates',
        '507' => 'Insufficient Storage',
        '508' => 'Loop Detected',
        '510' => 'Not Extended',
        '511' => 'Network Authentication Required',
    ];

    http_response_code($status);
    loggedInUser(); // to refresh the cookie
    view('error', compact('status', 'defaultMessages', 'message'));
    exit();
}

function e(string $iffyString): string {
    return htmlentities($iffyString, encoding: 'utf-8');
}

global $errors;
$errors = json_decode($_COOKIE['authum_errors'] ?? '');
if (!is_array($errors)) $errors = [];
if (!array_is_list($errors)) $errors = [];

function addError(string $message): void {
    global $errors;
    $errors[] = $message;
    if (!headers_sent())
        setcookie("authum_errors", json_encode($errors), time() + config('session.timeout'), path: '/', httponly: true);
}

/**
 * @return void|never
 */
function responseFormValidationFailMaybe(string $forceUrl = null) {
    global $errors;
    if (count($errors) > 0) {
        if (is_null($forceUrl)) {
            redirectBack();
        } else {
            redirect($forceUrl);
        }
    }
}

function redirectBack(): never {
    redirect($_SERVER['HTTP_REFERER']);
}

function redirect(string $location): never {
    http_response_code(302);
    header('Location: ' . $location);
    exit;
}

function dd($data): never {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode($data, JSON_PRETTY_PRINT);
    exit();
}

function transliterate(string $string): string {
    $string = \Transliterator::create('NFKC; [:Nonspacing Mark:] Remove; NFKC; Any-Latin; Latin-ASCII;')->transliterate($string);
    $string = mb_convert_encoding($string, 'ascii');
    return $string;
}

function doesRouteStringMatchString(string $routeString, string $string): bool {
    return ltrim($routeString, '/') == ltrim($string, '/');
}

function doRouting(array $routes): never {
    header('Server: authum/' . AUTHUM_VERSION);

    $routesThatMatch = [];
    $routesThatMatchPath = [];

    foreach ($routes as $route) {
        if (doesRouteStringMatchString($route[1], REQUEST_PATH)) {
            $routesThatMatchPath[] = $route;
            if ($route[0] == '' || $route[0] == 'view' && $_SERVER['REQUEST_METHOD'] == 'GET' || $route[0] == $_SERVER['REQUEST_METHOD']) {
                $routesThatMatch[] = $route;
            }
        }
    }

    if (!empty($routesThatMatch)) {
        if (isset($routesThatMatch[0][3])) ('Gates::' . $routesThatMatch[0][3])(); // gate

        if ($routesThatMatch[0][0] == 'view') {
            view($routesThatMatch[0][2]);
        } else {
            ('Web\\' . ucfirst($routesThatMatch[0][2]))(); // response handler
        }
    } else if (!empty($routesThatMatchPath)) {
        header('Allow: ' . implode(', ', array_column($routesThatMatchPath, '0')));
        abort(405, 'Allowed: ' . implode(', ', array_column($routesThatMatchPath, '0')));
    } else {
        abort(404);
    }

    exit;
}

/**
 * @return array empty array is not logged in
 */
function loggedInUser(): array {
    return memo('loggedInUser', function (): array {
        $user = [];

        $sessionId = $_COOKIE['authum_session'] ?? null;
        $id = $_SERVER["PHP_AUTH_USER"] ?? null;
        $password = $_SERVER["PHP_AUTH_PW"] ?? null;

        if (strlen($sessionId ?? '') != 42) $sessionId = null;

        if (
            !is_null($sessionId)
            && DB::queryFirstField('SELECT EXISTS(SELECT * FROM `sessions` WHERE `id` = %s AND last_used_at > %i)', $sessionId, time() - config('session.timeout')) == 1
        ) {
            if (!headers_sent())
                setcookie("authum_session", $_COOKIE['authum_session'], time() + config('session.timeout'), path: '/', httponly: true); // refresh the cookie

            DB::query('UPDATE `sessions` SET `last_used_at` = UNIX_TIMESTAMP() WHERE `id` = %s', $sessionId);
            $user = DB::queryFirstRow('SELECT * FROM `users` WHERE `id` = (SELECT `user_id` FROM `sessions` WHERE `id` = %s) AND `is_enabled` = 1 LIMIT 1', $_COOKIE['authum_session']) ?? [];
        } else {
            if (!is_null($sessionId)) DB::query('DELETE FROM `sessions` WHERE `id` = %s', $sessionId);
            if (!headers_sent()) setcookie("authum_session", '', 1, path: '/', httponly: true); // delete the cookie
        }

        if (empty($user) && !empty($id) && !empty($password)) {
            $user = DB::queryFirstRow('SELECT * FROM `users` WHERE `id` = %s', $id) ?? [];
            if (isset($user['password']) && !password_verify($password, $user['password'])) $user = [];
        }

        return $user;
    });
}

/**
 * Recall or compute
 * @param callable
 */
function memo(string $key, callable $callable): mixed {
    static $memos = [];
    if (isset($memos[$key])) return $memos[$key];
    $memos[$key] = $callable();
    return $memos[$key];
}

function view(string $viewPath, array $variables = []): void {
    global $errors;
    if (!headers_sent()) setcookie('authum_errors', '', 1, path: '/', httponly: true);
    extract($variables);
    include __DIR__ . '/views/' . $viewPath . '.php';
}

function viewAsString(string $viewPath, array $variables = []): string {
    ob_start();
    view($viewPath, $variables);
    return ob_get_clean();
}

/**
 * Check if there are database migrations to perform and, if there are, perform them.
 * @return void|never
 */
function doMigrations() {
    if (DB::queryFirstField('SELECT IS_USED_LOCK("authum_migrating")') !== null) {
        view('migrations-running');
        exit;
    }

    $migrationsTableIsMissing = DB::queryFirstField(<<<SQL
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = %s AND TABLE_NAME = "migrations"
    SQL, DB::$dbName) == 0;

    // filenames in migrations/ that aren't hidden, with their extensions removed
    $migrations = array_map(fn ($a) => substr($a, 0, -4), array_filter(scandir(__DIR__ . '/../migrations'), fn ($a) => $a[0] != '.'));

    if ($migrationsTableIsMissing) {
        $pendingMigrations = $migrations;
    } else {
        $pendingMigrations = array_diff($migrations, DB::queryFirstColumn('SELECT `name` FROM `migrations`'));
    }

    if (count($pendingMigrations) > 0) {
        DB::query('SELECT GET_LOCK("authum_migrating", -1)'); // get lock; wait for it forever

        if ($migrationsTableIsMissing) {
            $pendingMigrations = $migrations;
        } else {
            $pendingMigrations = array_diff($migrations, DB::queryFirstColumn('SELECT `name` FROM `migrations`'));
        }

        $pendingMigrations = array_unique($pendingMigrations);
        sort($pendingMigrations);

        foreach ($pendingMigrations as $name) {
            if (file_exists(__DIR__ . "/../migrations/$name.php")) {
                include(__DIR__ . "/../migrations/$name.php");
            } else {
                DB::get()->multi_query(file_get_contents(__DIR__ . "/../migrations/$name.sql"));
            }
            while (DB::get()->next_result()); // flush multi_queries
            DB::query('INSERT INTO `migrations` VALUES (%s)', $name);
        };

        DB::query('SELECT RELEASE_LOCK("authum_migrating")');
    }
}

function doDbPruning(): void {
    if (random_int(1, config('db.pruning-lottery')) != 1) return;
    DB::query('DELETE FROM `sessions` WHERE last_used_at < %i', time() - config('session.timeout'));
}

function getTypeFromId(string $id): ?string {
    if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM services WHERE id = %s)', $id)) return 'service';
    if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM users WHERE id = %s)', $id)) return 'user';
    if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM groups WHERE id = %s)', $id)) return 'group';
    return null;
}

function scriptTag(string $filename, bool $fullUrl = false, bool $async = false): string {
    $result = '<script src="';
    if ($fullUrl) $result .= config('app.url');
    $result .= '/' . $filename . '.js?v=' . substr(md5(file_get_contents(publicPath($filename . '.js'))), -8) . '"';
    if ($async) $result .= " async";
    $result .= '></script>';
    return $result;
}

function styleTag(string $filename, bool $fullUrl = false): string {
    $result = '<link rel="stylesheet" href="';
    if ($fullUrl) $result .= config('app.url');
    $result .= '/' . $filename . '.css?v=' . substr(md5(file_get_contents(publicPath($filename . '.css'))), -8) . '" />';
    return $result;
}

function publicPath(string $filepath): string {
    return __DIR__ . '/../public/' . $filepath;
}
