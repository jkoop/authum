<?php

namespace Web;

use DB;
use Ulid\Ulid;

class Group {
    static function new(): never { // the new user page
        $group = [
            'name' => 'New Group',
        ];

        $users = [];

        view('group', compact('group', 'users'));
        exit;
    }

    static function create(): never { // create it for real
        self::update(createGroup: true);
    }

    static function view(): never {
        $group = DB::queryFirstRow('SELECT * FROM `groups` WHERE `id` = %s', $_GET['id'] ?? abort(400, 'The query parameter "id" is required'));

        if (!$group) abort(404);

        $users = DB::query(<<<SQL
            SELECT *
            FROM `users`
            INNER JOIN `group_user` ON `users`.`id` = `group_user`.`user_id`
            WHERE `group_id` = %s
            ORDER BY `name`
        SQL, $_GET['id']);

        view('group', compact('group', 'users'));
        exit;
    }

    static function update(bool $createGroup = false): never {
        if (!$createGroup) {
            if (!DB::queryFirstField('SELECT EXISTS(SELECT * FROM `groups` WHERE `id` = %s)', $_GET['id'] ?? abort(400, 'The query parameter "id" is required'))) abort(404);
            if (($_POST['action'] ?? null) == 'delete') self::delete($_GET['id']);
        }

        $groupId = $createGroup ? Ulid::generate() : $_GET['id'];

        DB::insertUpdate('groups', [
            'id' => $groupId,
            'name' => substr($_POST['name'], 0, 255),
        ]);

        foreach ($_POST['detach_users'] ?? [] as $userId) {
            DB::query('DELETE FROM `group_user` WHERE `group_id` = %s AND `user_id` = %s', $groupId, $userId);
        }

        if (strlen($_POST['add_user']) > 0) {
            DB::insertIgnore('group_user', [
                'user_id' => $_POST['add_user'],
                'group_id' => $groupId,
            ]);
        }

        if ($createGroup) redirect("/group?id=$groupId");
        else redirectBack();
    }

    private static function delete(string $groupId): never {
        DB::delete('groups', 'id=%s', $groupId);
        redirect('/groups');
    }
}
