<?php

namespace Web;

use Checks;
use DB;
use Gates;
use SKleeschulte\Base32;
use Ulid\Ulid;

class Login {
    static function view(): never {
        if (isset($_GET['from'])) {
            if (Checks::isLoggedIn()) {
                $url = parse_url($_GET['from']);
                if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM `services` WHERE `domain_name` = %s)', $url['host']) == 0) redirect('/login');
                redirect('//' . $url['host'] . '/_authum_login?' . http_build_query(['token' => $_COOKIE['authum_session']]));
            } else {
                setcookie("authum_from", $_GET['from'], time() + config('session.timeout'), path: '/', httponly: true);
            }
        }

        Gates::notLoggedIn();
        view('login');
        exit;
    }

    static function tryLogin(): never {
        $id = $_POST['username'] ?? addError('id is required');
        $password = $_POST['password'] ?? addError('password is required');

        responseFormValidationFailMaybe();

        $user = DB::queryFirstRow(<<<SQL
            SELECT `id`, `password`, `is_enabled`
            FROM `users`
            WHERE `id` = %s
        SQL, $id);

        if (!isset($user['password'])) addError('no such user or bad password');
        responseFormValidationFailMaybe();
        if (!password_verify($password, $user['password'])) addError('no such user or bad password');
        responseFormValidationFailMaybe();

        self::doLogin($user, $_GET['from'] ?? null);
    }

    private static function doLogin(array $user, string $redirection = null): never {
        if (!$user['is_enabled']) addError('the account is disabled');
        responseFormValidationFailMaybe('/login');

        $sessionId = Ulid::generate() . Base32::encodeByteStrToCrockford(random_bytes(10));
        DB::query('INSERT INTO `sessions` (`id`, `user_id`, `created_at`, `last_used_at`) VALUES (%s, %s, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())', $sessionId, $user['id']);

        setcookie("authum_session", $sessionId, time() + config('session.timeout'), path: '/', httponly: true);
        setcookie("authum_from", '', 1, path: '/', httponly: true);

        if ($_GET['from'] ?? '' != '') {
            $domainName = explode('/', str_replace(':', '/', $_GET['from']))[0];
            if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM `services` WHERE `domain_name` = %s)', $domainName) == 1) {
                redirect('//' . $domainName . '/_authum_login?' . http_build_query([
                    'token' => $sessionId,
                    'goto' => implode('/', array_slice(explode('/', $_GET['from']), 1)),
                ]));
            }
        }

        if ($redirection == '') $redirection = null;
        redirect($redirection ?? '/');
    }

    static function doLogout(): never {
        DB::query('DELETE FROM `sessions` WHERE `id` = %s', $_COOKIE['authum_session']);
        setcookie("authum_session", '', 1, path: '/', httponly: true);
        setcookie("authum_from", '', 1, path: '/', httponly: true);
        redirect(config('app.url') . '/login');
    }

    static function impersonate(): never {
        try {
            DB::update('sessions', ['user_id' => $_POST['user_id'] ?? abort(400, 'The post parameter "user_id" is required')], "id=%s", $_COOKIE['authum_session']);
        } catch (\Exception $e) {
            abort(404);
        }

        redirect('/');
        exit;
    }

    static function loginWithDiscord(): never {
        $code = $_GET['code'] ?? abort(400, 'The query parameter "code" is required');

        $response = @file_get_contents(
            'https://discord.com/api/oauth2/token',
            context: stream_context_create([
                'http' => [
                    'header' => "Content-type: application/x-www-form-urlencoded\r\n",
                    'method' => 'POST',
                    'content' => http_build_query([
                        'client_id' => config('discord.client_id'),
                        'client_secret' => config('discord.client_secret'),
                        'grant_type' => 'authorization_code',
                        'code' => $code,
                        'redirect_uri' => config('app.url') . '/callback/discord',
                    ]),
                ],
            ]),
        );
        if ($response === false) abort(400, 'The query parameter "code" is invalid');

        $accessToken = json_decode($response)->access_token ?? abort(500, "Discord gave a bad response (access token)");

        $response = @file_get_contents(
            'https://discord.com/api/v10/users/@me',
            context: stream_context_create([
                'http' => [
                    'header' => "Authorization: Bearer $accessToken\r\n",
                ],
            ]),
        );
        if ($response === false) abort(500, "Couldn't get user data from Discord");

        $user = json_decode($response) ?? abort(500, "Discord gave a bad response (user data)");

        DB::insertUpdate('users', [
            'id' => $user->id,
            'name' => $user->global_name ?? ($user->username . '#' . $user->discriminator),
            'is_admin' => 0,
            'is_enabled' => 0,
        ], [
            'name' => $user->global_name ?? ($user->username . '#' . $user->discriminator),
        ]);

        $user = DB::queryFirstRow(<<<SQL
            SELECT `id`, `is_enabled`
            FROM `users`
            WHERE `id` = %s
        SQL, $user->id);

        self::doLogin($user, $_COOKIE['authum_from'] ?? null);
    }
}
