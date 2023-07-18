<?php

namespace Web;

use Checks;
use DB;
use SKleeschulte\Base32;
use Ulid\Ulid;

class Login {
    static function view(): never {
        if (($_GET['from'] ?? '') != '' && Checks::isLoggedIn()) {
            $domainName = explode('/', str_replace(':', '/', $_GET['from']))[0];
            if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM `domain_names` WHERE `domain_name` = %s)', $domainName) == 0) redirect('/login');
            redirect('//' . $domainName . '/_authum_login?' . http_build_query(['token' => $_COOKIE['authum_session']]));
        }

        view('login');
        exit;
    }

    static function tryLogin(): never {
        $email = $_POST['email'] ?? addError('email is required');
        $password = $_POST['password'] ?? addError('password is required');

        responseFormValidationFailMaybe();

        $user = DB::queryFirstRow(<<<SQL
            SELECT `id`, `password`, `is_enabled`
            FROM `users`
            INNER JOIN `email_addresses` ON `email_addresses`.`user_id` = `users`.`id`
            WHERE `email_address` = %s
        SQL, $email);

        if (!isset($user['password'])) addError('no such user or bad password');
        responseFormValidationFailMaybe();
        if (!password_verify($password, $user['password'])) addError('no such user or bad password');
        responseFormValidationFailMaybe();

        self::doLogin($user);
    }

    private static function doLogin(array $user): never {
        if (!$user['is_enabled']) addError('the account is disabled');
        responseFormValidationFailMaybe('/login');

        $sessionId = Ulid::generate() . Base32::encodeByteStrToCrockford(random_bytes(10));
        DB::query('INSERT INTO `sessions` (`id`, `user_id`, `created_at`, `last_used_at`) VALUES (%s, %s, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())', $sessionId, $user['id']);

        setcookie("authum_session", $sessionId, time() + config('session.timeout'), path: '/', httponly: true);

        if ($_GET['from'] ?? '' != '') {
            $domainName = explode('/', str_replace(':', '/', $_GET['from']))[0];
            if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM `domain_names` WHERE `domain_name` = %s)', $domainName) == 1) {
                redirect('//' . $domainName . '/_authum_login?' . http_build_query([
                    'token' => $sessionId,
                    'goto' => implode('/', array_slice(explode('/', $_GET['from']), 1)),
                ]));
            }
        }

        $location = '/' . ($_SESSION['intended'] ?? '');
        unset($_SESSION['intended']);
        redirect($location);
    }

    static function doLogout(): never {
        DB::query('DELETE FROM `sessions` WHERE `id` = %s', $_COOKIE['authum_session']);
        setcookie("authum_session", '', 0, path: '/', httponly: true);
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

        DB::insertUpdate('discord_users', [
            'id' => $user->id,
            'username' => $user->username,
            'discriminator' => $user->discriminator,
            'global_name' => $user->global_name,
            'avatar' => $user->avatar,
        ]);

        if (isset($user->bot)) DB::query('UPDATE `discord_users` SET `bot` = %i WHERE `id` = %i', $user->bot, $user->id);
        if (isset($user->system)) DB::query('UPDATE `discord_users` SET `system` = %i WHERE `id` = %i', $user->system, $user->id);
        if (isset($user->mfa_enabled)) DB::query('UPDATE `discord_users` SET `mfa_enabled` = %i WHERE `id` = %i', $user->mfa_enabled, $user->id);
        if (isset($user->banner)) DB::query('UPDATE `discord_users` SET `banner` = %s WHERE `id` = %i', $user->banner, $user->id);
        if (isset($user->accent_color)) DB::query('UPDATE `discord_users` SET `accent_color` = %i WHERE `id` = %i', $user->accent_color, $user->id);
        if (isset($user->locale)) DB::query('UPDATE `discord_users` SET `locale` = %s WHERE `id` = %i', $user->locale, $user->id);
        if (isset($user->verified)) DB::query('UPDATE `discord_users` SET `verified` = %i WHERE `id` = %i', $user->verified, $user->id);
        if (isset($user->email)) DB::query('UPDATE `discord_users` SET `email` = %s WHERE `id` = %i', $user->email, $user->id);
        if (isset($user->flags)) DB::query('UPDATE `discord_users` SET `flags` = %i WHERE `id` = %i', $user->flags, $user->id);
        if (isset($user->premium_type)) DB::query('UPDATE `discord_users` SET `premium_type` = %i WHERE `id` = %i', $user->premium_type, $user->id);
        if (isset($user->public_flags)) DB::query('UPDATE `discord_users` SET `public_flags` = %i WHERE `id` = %i', $user->public_flags, $user->id);
        if (isset($user->avatar_decoration)) DB::query('UPDATE `discord_users` SET `avatar_decoration` = %s WHERE `id` = %i', $user->avatar_decoration, $user->id);

        if (!($user->verified ?? false)) {
            addError("the discord account must have a verified email address");
            redirect('/login');
        }

        // create or attach authum user
        DB::query('START TRANSACTION');
        DB::query('UPDATE `email_addresses` SET `discord_user_id` = NULL WHERE `discord_user_id` = %i', $user->id);
        if (DB::queryFirstField('SELECT EXISTS (SELECT * FROM `email_addresses` WHERE `email_address` = %s)', $user->email)) {
            DB::query(<<<SQL
                UPDATE `email_addresses`
                SET `discord_user_id` = %i
                WHERE `email_address` = %s
            SQL, $user->id, $user->email);
        } else {
            $userId = Ulid::generate();
            DB::query('INSERT INTO `users` (`id`, `name`, `is_admin`, `is_enabled`) VALUES (%s, %s, 0, 0)', $userId, $user->global_name);
            DB::query('INSERT INTO `email_addresses` (`email_address`, `user_id`, `discord_user_id`) VALUES (%s, %s, %i)', $user->email, $userId, $user->id);
        }
        DB::query('COMMIT');

        self::doLogin($user = DB::queryFirstRow(<<<SQL
            SELECT `id`, `is_enabled`
            FROM `users`
            INNER JOIN `email_addresses` ON `email_addresses`.`user_id` = `users`.`id`
            WHERE `email_address` = %s
        SQL, $user->email));
    }
}
