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
    if ($status < 400 || $status > 599) throw new InvalidArgumentException('$message must between 400 and 599, inclusive');

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
    include __DIR__ . '/views/error.php';
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
        if (isset($routesThatMatch[0][3])) ('gate' . ucfirst($routesThatMatch[0][3]))(); // gate

        if ($routesThatMatch[0][0] == 'view') {
            include(__DIR__ . '/views/' . $routesThatMatch[0][2] . '.php');
        } else {
            ('web' . ucfirst($routesThatMatch[0][2]))(); // response handler
        }
    } else if (!empty($routesThatMatchPath)) {
        header('Allow: ' . implode(', ', array_column($routesThatMatchPath, '0')));
        abort(405);
    } else {
        abort(404);
    }

    exit;
}

function loggedInUser(): array|null {
	return DB::queryFirstRow('SELECT * FROM users LIMIT 1');
}

function isAdmin(): bool {
    return isLoggedIn();
}

function isLoggedIn() {
    return isset($_COOKIE['authum_login']);
}

/**
 * @return void|never
 */
function gateAdmin() {
    gateLoggedIn();
    if (!isAdmin()) abort(403);
}

/**
 * @return void|never
 */
function gateLoggedIn() {
    if (!isLoggedIn()) {
        $_SESSION['intended'] = REQUEST_PATH . '?' . http_build_query($_GET);
        redirect('/login');
    }
}

/**
 * @return void|never
 */
function gateNotLoggedIn() {
    if (isLoggedIn()) redirect('/');
}

function webHandleForwardAuth(): never {
    dd([
        $_SERVER,
        $_POST,
        $_GET,
        $_COOKIE
    ]);
    redirect('//authum.localhost/login?return_token=9346193761');
}

function webTryLogin(): never {
    $email = REQUEST_PAYLOAD['email'] ?? addError('email is required');
    $password = REQUEST_PAYLOAD['password'] ?? addError('password is required');

    responseFormValidationFailMaybe();

    $passwordHash = DB::queryFirstField(<<<SQL
        SELECT `password`
        FROM `users`
        INNER JOIN `email_addresses` ON `email_addresses`.`user_id` = `users`.`id`
        WHERE `email_address` = %s;
    SQL, $email);

    if (!$passwordHash) addError('no such user or bad password');
    responseFormValidationFailMaybe();
    if (!password_verify($password, $passwordHash ?? '')) addError('no such user or bad password');
    responseFormValidationFailMaybe();

    setcookie("authum_login", '123456', strtotime('+1 hour'));

    $location = $_SESSION['intended'] ?? '/';
    unset($_SESSION['intended']);
    redirect($location);
}

function webDoLogout(): never {
    setcookie("authum_login", '', 0);
    redirect('/login');
}

function webViewUser(): never {
    $user = DB::queryFirstRow('SELECT * FROM users WHERE id = %s', REQUEST_PAYLOAD['id'] ?? abort(400));

    if (!$user) abort(404);

    $emailAddresses = DB::query('SELECT * FROM email_addresses WHERE user_id = %s', REQUEST_PAYLOAD['id']);

    include 'views/user.php';
    exit;
}
