<?php

namespace Web;

use DB;

class Login {
    static function tryLogin(): never {
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

    static function doLogout(): never {
        setcookie("authum_login", '', 0);
        redirect('/login');
    }
}
