<?php

namespace Web;

use DB;

class UserGroup {
    static function view(): never {
        $userGroup = DB::queryFirstRow('SELECT * FROM user_groups WHERE id = %s', $_GET['id'] ?? abort(400));

        if (!$userGroup) abort(404);

        $users = DB::query('SELECT * FROM users INNER JOIN user_user_group ON users.id = user_user_group.user_id WHERE user_group_id = %s', $_GET['id']);

        view('user-group', compact('userGroup', 'users'));
        exit;
    }
}
