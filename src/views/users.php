<!DOCTYPE html>
<html lang="en-CA">

<head>
    <?php view('head', ['title' => 'Users']) ?>
    <?= styleTag('users') ?>
</head>

<body>
    <?php view('navigation') ?>

    <main>
        <h1>Users</h1>

        <fieldset>
            <legend>Actions</legend>
            <a href="/user/new">Create user</a>
        </fieldset>

        <table>
            <thead>
                <tr>
                    <th>Name</th>
                    <th>ID</th>
                    <th>Created At</th>
                    <th colspan="3">Is / Has</th>
                    <th>Comment</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach (DB::query('SELECT `id`, `name`, `comment`, `is_admin`, `is_enabled`, `password` IS NOT NULL AS `has_password`, `created_at` FROM users ORDER BY `name`') as $user) : ?>
                    <tr>
                        <td><a href="/user?id=<?= strtolower($user['id']) ?>"><?= e($user['name']) ?></a></td>
                        <td><?= e(strtolower($user['id'])) ?> <?php view('discord-icon-link', ['id' => $user['id']]) ?></td>
                        <td title="<?= date('r', $user['created_at']) ?>"><?= date('Y-m-d h:i', $user['created_at']) ?></td>
                        <td><?= $user['is_admin'] ? 'admin' : '' ?></td>
                        <td><?= $user['is_enabled'] ? 'enabled' : '' ?></td>
                        <td><?= $user['has_password'] ? 'passwd' : '' ?></td>
                        <td><?= e($user['comment']) ?></td>
                    </tr>
                <?php endforeach ?>
            </tbody>
        </table>
    </main>

    <?php view('footer') ?>
</body>

</html>
