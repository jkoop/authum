<?php

namespace Web;

use DB;
use mysqli_sql_exception;
use Ulid\Ulid;

class User {
    static function new(): never { // the new user page
        $user = [
            'name' => 'New User',
            'comment' => '',
            'is_admin' => 0,
            'is_enabled' => 1,
        ];

        view('user', compact('user'));
        exit;
    }

    static function create(): never { // create it for real
        self::update(createUser: true);
    }

    static function view(): never {
        $user = DB::queryFirstRow('SELECT * FROM `users` WHERE `id` = %s', $_GET['id'] ?? abort(400, 'The query parameter "id" is required'));
        if (!$user) abort(404);

        view('user', compact('user'));
        exit;
    }

    static function update(bool $createUser = false): never {
        if (!$createUser) {
            if (!DB::queryFirstField('SELECT EXISTS(SELECT * FROM `users` WHERE `id` = %s)', $_GET['id'] ?? abort(400, 'The query parameter "id" is required'))) abort(404);
            if (($_POST['action'] ?? null) == 'delete') self::delete($_GET['id']);
        }

        if ($createUser) {
            if (strlen($_POST['id'] ?? '') > 0) {
                $userId = substr($_POST['id'], 0, 20);
            } else {
                $userId = Ulid::generate();
            }
        } else {
            $userId = $_GET['id'];
        }

        if ($createUser) {
            try {
                DB::insert('users', [
                    'id' => $userId,
                    'name' => substr($_POST['name'], 0, 255),
                    'comment' => substr($_POST['comment'], 0, 255),
                    'is_admin' => isset($_POST['is_admin']),
                    'is_enabled' => isset($_POST['is_enabled']),
                ]);
            } catch (mysqli_sql_exception $e) {
                if (str_starts_with($e->getMessage(), 'Duplicate entry ')) {
                    abort(400, "The ID is already taken");
                }
                throw $e;
            }
        } else {
            DB::insertUpdate('users', [
                'id' => $userId,
                'name' => substr($_POST['name'], 0, 255),
                'comment' => substr($_POST['comment'], 0, 255),
                'is_admin' => isset($_POST['is_admin']),
                'is_enabled' => isset($_POST['is_enabled']),
            ]);
        }

        if (strlen($_POST['password_new']) > 0) {
            DB::query('UPDATE `users` SET `password` = %s WHERE `id` = %s', password_hash($_POST['password_new'], null), $userId);
        }

        if ($createUser) redirect("/user?id=$userId");
        else redirectBack();
    }

    private static function delete(string $userId): never {
        DB::delete('users', 'id=%s', $userId);
        redirect('/users');
    }
}
