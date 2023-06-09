<?php

include_once __DIR__ . '/../vendor/autoload.php';

const AUTHUM_VERSION = '0.1';
define('REQUEST_PATH', explode('?', $_SERVER['REQUEST_URI'])[0]);
define('REQUEST_PAYLOAD', (function () {
    $result = [];

    foreach ($_GET as $key => $value) {
        $key = trim($key);
        $value = trim($value);
        if (strlen($value) > 0) {
            $result[$key] = $value;
        } else {
            $result[$key] = null;
        }
    }

    foreach ($_POST as $key => $value) {
        $key = trim($key);
        $value = trim($value);
        if (strlen($value) > 0) {
            $result[$key] = $value;
        } else {
            $result[$key] = null;
        }
    }

    return $result;
})());

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
        '500' => 'Internal Server Error',
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
    view('error', compact('status', 'defaultMessages', 'message'));
    exit();
}

function e(string $iffyString): string {
    return htmlentities($iffyString, encoding: 'utf-8');
}

function addError(string $message): void {
    $_SESSION['errors'] ??= [];
    $_SESSION['errors'][] = $message;
}

/**
 * @return void|never
 */
function responseFormValidationFailMaybe() {
    if (count($_SESSION['errors'] ?? []) > 0) redirectBack();
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
        abort(405);
    } else {
        abort(404);
    }

    exit;
}

/**
 * @return array|null null if not logged in
 */
function loggedInUser(): array|null {
    if (strlen($_COOKIE['authum_session'] ?? '') != 42) return null;
    if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM `sessions` WHERE `id` = %s)', $_COOKIE['authum_session']) == 0) return null;
    DB::query('UPDATE `sessions` SET `last_used_at` = UNIX_TIMESTAMP() WHERE `id` = %s', $_COOKIE['authum_session']);
    return DB::queryFirstRow('SELECT * FROM `users` WHERE `id` = (SELECT `user_id` FROM `sessions` WHERE `id` = %s) LIMIT 1', $_COOKIE['authum_session']);
}

function view(string $viewPath, array $variables = []): void {
    extract($variables);
    include __DIR__ . '/../views/' . $viewPath . '.php';
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
