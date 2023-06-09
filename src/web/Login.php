<?php

namespace Web;

use DB;
use SKleeschulte\Base32;
use Ulid\Ulid;

class Login {
    static function tryLogin(): never {
        $email = REQUEST_PAYLOAD['email'] ?? addError('email is required');
        $password = REQUEST_PAYLOAD['password'] ?? addError('password is required');

        responseFormValidationFailMaybe();

        $user = DB::queryFirstRow(<<<SQL
            SELECT `id`, `password`
            FROM `users`
            INNER JOIN `email_addresses` ON `email_addresses`.`user_id` = `users`.`id`
            WHERE `email_address` = %s;
        SQL, $email);

        if (!$user['password']) addError('no such user or bad password');
        responseFormValidationFailMaybe();
        if (!password_verify($password, $user['password'] ?? '')) addError('no such user or bad password');
        responseFormValidationFailMaybe();

        $sessionId = Ulid::generate() . Base32::encodeByteStrToCrockford(random_bytes(10));
        DB::query('INSERT INTO `sessions` (`id`, `user_id`, `created_at`, `last_used_at`) VALUES (%s, %s, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())', $sessionId, $user['id']);

        setcookie("authum_session", $sessionId, strtotime('+1 hour'));

        $location = $_SESSION['intended'] ?? '/';
        unset($_SESSION['intended']);
        redirect($location);
    }

    static function doLogout(): never {
        DB::query('DELETE FROM `sessions` WHERE `id` = %s', $_COOKIE['authum_session']);
        setcookie("authum_session", '', 0);
        redirect('/login');
    }
}
