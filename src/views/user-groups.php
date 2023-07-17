<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => 'User Groups']) ?></head>

<body>
    <h1>User Groups</h1>
    <?php view('navigation') ?>

    <fieldset>
        <legend>Actions</legend>
        <a href="/user-group/new">Create user group</a>
    </fieldset>

    <ul>
        <?php foreach (DB::query('SELECT `id`, `name` FROM `user_groups` ORDER BY `name`') as $userGroup) : ?>
            <li>
                <a href="/user-group?id=<?= $userGroup['id'] ?>"><?= e($userGroup['name']) ?></a>
                &lt;<?= e(implode(', ', DB::queryFirstColumn('SELECT `name` FROM `users` INNER JOIN `user_user_group` ON `users`.`id` = `user_user_group`.`user_id` WHERE `user_group_id` = %s ORDER BY `name`', $userGroup['id']))) ?>&gt;
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
