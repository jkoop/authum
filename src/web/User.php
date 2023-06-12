<?php

namespace Web;

use DB;

class User {
    static function view(): never {
        $user = DB::queryFirstRow('SELECT * FROM users WHERE id = %s', $_GET['id'] ?? abort(400));
        if (!$user) abort(404);

        $emailAddresses = DB::query('SELECT * FROM email_addresses WHERE user_id = %s', $_GET['id']);

        view('user', compact('user', 'emailAddresses'));
        exit;
    }

    static function update(): never {
        if (!DB::queryFirstRow('SELECT EXISTS(SELECT * FROM users WHERE id = %s)', $_GET['id'] ?? abort(400))) abort(404);

        DB::replace('users', [
            'id' => $_GET['id'],
            'name' => substr($_POST['name'], 0, 255),
            'is_admin' => isset($_POST['is_admin']),
            'is_enabled' => isset($_POST['is_enabled']),
        ]);

        if (strlen($_POST['password_new']) > 0) {
            DB::query('UPDATE users SET password = %s WHERE id = %s', password_hash($_POST['password_new'], null), $_GET['id']);
        }

        if (strlen($_POST['add_email_address']) > 0 && strlen($_POST['add_email_address']) < 256) {
            DB::insertIgnore('email_addresses', [
                'email_address' => $_POST['add_email_address'],
                'user_id' => $_GET['id'],
            ]);
        }
    }
}
