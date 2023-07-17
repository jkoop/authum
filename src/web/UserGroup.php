<?php

namespace Web;

use DB;
use Ulid\Ulid;

class UserGroup {
    static function new(): never { // the new user page
        $userGroup = [
            'name' => 'New User Group',
        ];

        $users = [];

        view('user-group', compact('userGroup', 'users'));
        exit;
    }

    static function create(): never { // create it for real
        self::update(createUserGroup: true);
    }

    static function view(): never {
        $userGroup = DB::queryFirstRow('SELECT * FROM `user_groups` WHERE `id` = %s', $_GET['id'] ?? abort(400, 'The query parameter "id" is required'));

        if (!$userGroup) abort(404);

        $users = DB::query(<<<SQL
            SELECT *
            FROM `users`
            INNER JOIN `user_user_group` ON `users`.`id` = `user_user_group`.`user_id`
            WHERE `user_group_id` = %s
            ORDER BY `name`
        SQL, $_GET['id']);

        view('user-group', compact('userGroup', 'users'));
        exit;
    }

    static function update(bool $createUserGroup = false): never {
        if (!$createUserGroup) {
            if (!DB::queryFirstRow('SELECT EXISTS(SELECT * FROM `user_groups` WHERE `id` = %s)', $_GET['id'] ?? abort(400, 'The query parameter "id" is required'))) abort(404);
            if (($_POST['action'] ?? null) == 'delete') self::delete($_GET['id']);
        }

        $userGroupId = $createUserGroup ? Ulid::generate() : $_GET['id'];

        DB::insertUpdate('user_groups', [
            'id' => $userGroupId,
            'name' => substr($_POST['name'], 0, 255),
        ]);

        foreach ($_POST['detach_users'] ?? [] as $userId) {
            DB::query('DELETE FROM `user_user_group` WHERE `user_group_id` = %s AND `user_id` = %s', $userGroupId, $userId);
        }

        if (strlen($_POST['add_user']) == 26) {
            DB::insertIgnore('user_user_group', [
                'user_id' => $_POST['add_user'],
                'user_group_id' => $userGroupId,
            ]);
        }

        if ($createUserGroup) redirect("/user-group?id=$userGroupId");
        else redirectBack();
    }

    private static function delete(string $userGroupId): never {
        DB::delete('user_groups', 'id=%s', $userGroupId);
        redirect('/user-groups');
    }
}
