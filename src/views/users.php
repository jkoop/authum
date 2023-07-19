<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => 'Users']) ?></head>

<body>
    <h1>Users</h1>
    <?php view('navigation') ?>

    <fieldset>
        <legend>Actions</legend>
        <a href="/user/new">Create user</a>
    </fieldset>

    <ul>
        <?php foreach (DB::query('SELECT id, `name` FROM users ORDER BY `name`') as $user) : ?>
            <li>
                <a href="/user?id=<?= $user['id'] ?>"><?= e($user['name']) ?></a>
                <?php view('discord-icon-link', ['id' => $user['id']]) ?>
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
