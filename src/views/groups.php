<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => 'Groups']) ?></head>

<body>
    <?php view('navigation') ?>

    <main>
        <h1>Groups</h1>

        <fieldset>
            <legend>Actions</legend>
            <a href="/group/new">Create user group</a>
        </fieldset>

        <ul>
            <?php foreach (DB::query('SELECT `id`, `name` FROM `groups` ORDER BY `name`') as $group) : ?>
                <li>
                    <a href="/group?id=<?= $group['id'] ?>"><?= e($group['name']) ?></a>
                    (<?php
                        $users = DB::query('SELECT `id`, `name` FROM `users` INNER JOIN `group_user` ON `users`.`id` = `group_user`.`user_id` WHERE `group_id` = %s ORDER BY `name`', $group['id']);
                        foreach ($users as $index => $user) {
                            echo e($user['name']);
                            $link = trim(viewAsString('discord-icon-link', ['id' => $user['id']]));
                            if (strlen($link)) echo ' ' . $link;
                            if ($index < count($users) - 1) echo ', ';
                        }
                        ?>)
                </li>
            <?php endforeach ?>
        </ul>
    </main>

    <?php view('footer') ?>
</body>

</html>
