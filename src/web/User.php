<?php

namespace Web;

use DB;
use Ulid\Ulid;

class User {
    static function new(): never { // the new user page
        $user = [
            'name' => 'New User',
            'is_admin' => 0,
            'is_enabled' => 1,
        ];

        $emailAddresses = [];

        view('user', compact('user', 'emailAddresses'));
        exit;
    }

    static function create(): never { // create it for real
        self::update(createUser: true);
    }

    static function view(): never {
        $user = DB::queryFirstRow('SELECT * FROM `users` WHERE `id` = %s', $_GET['id'] ?? abort(400, 'The query parameter "id" is required'));
        if (!$user) abort(404);

        $emailAddresses = DB::query('SELECT * FROM `email_addresses` WHERE `user_id` = %s ORDER BY `email_address`', $_GET['id']);

        view('user', compact('user', 'emailAddresses'));
        exit;
    }

    static function update(bool $createUser = false): never {
        if (!$createUser) {
            if (!DB::queryFirstField('SELECT EXISTS(SELECT * FROM `users` WHERE `id` = %s)', $_GET['id'] ?? abort(400, 'The query parameter "id" is required'))) abort(404);
            if (($_POST['action'] ?? null) == 'delete') self::delete($_GET['id']);
        }

        $userId = $createUser ? Ulid::generate() : $_GET['id'];

        DB::insertUpdate('users', [
            'id' => $userId,
            'name' => substr($_POST['name'], 0, 255),
            'is_admin' => isset($_POST['is_admin']),
            'is_enabled' => isset($_POST['is_enabled']),
        ]);

        if (strlen($_POST['password_new']) > 0) {
            DB::query('UPDATE `users` SET `password` = %s WHERE `id` = %s', password_hash($_POST['password_new'], null), $userId);
        }

        foreach ($_POST['delete_email_addresses'] ?? [] as $emailAddress) {
            DB::query('DELETE FROM `email_addresses` WHERE `email_address` = %s AND `user_id` = %s', $emailAddress, $userId);
        }

        if (strlen($_POST['add_email_address']) > 0 && strlen($_POST['add_email_address']) < 256) {
            DB::insertIgnore('email_addresses', [
                'email_address' => $_POST['add_email_address'],
                'user_id' => $userId,
            ]);
        }

        if ($createUser) redirect("/user?id=$userId");
        else redirectBack();
    }

    private static function delete(string $userId): never {
        DB::delete('users', 'id=%s', $userId);
        redirect('/users');
    }
}
