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

    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>ID</th>
                <th colspan="2">Is</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach (DB::query('SELECT `id`, `name`, `is_admin`, `is_enabled` FROM users ORDER BY `name`') as $user) : ?>
                <tr>
                    <td><a href="/user?id=<?= strtolower($user['id']) ?>"><?= e($user['name']) ?></a></td>
                    <td><?= e(strtolower($user['id'])) ?> <?php view('discord-icon-link', ['id' => $user['id']]) ?></td>
                    <td><?= $user['is_admin'] ? 'admin' : '' ?></td>
                    <td><?= $user['is_enabled'] ? 'enabled' : '' ?></td>
                </tr>
            <?php endforeach ?>
        </tbody>
    </table>

    <?php view('logged-in-footer') ?>
</body>

</html>
