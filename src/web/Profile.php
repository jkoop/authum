<?php

namespace Web;

use DB;

class Profile {
    public static function update() {
        $name = substr(mb_convert_encoding(trim($_POST['name'] ?? ''), 'ascii'), 0, 255);
        $password = $_POST['password'] ?? '';
        $userId = loggedInUser()['id'];

        if ($name != '' && !preg_match('/^[0-9]+$/', $userId)) {
            DB::query('UPDATE `users` SET `name` = %s WHERE `id` = %s', $name, $userId);
        }

        if ($password != '') {
            DB::query('UPDATE `users` SET `password` = %s WHERE `id` = %s', password_hash($password, null), $userId);
        }

        redirect('/profile');
    }
}
