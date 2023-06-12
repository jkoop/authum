<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title>User Groups - Authum</title>
</head>

<body>
    <h1>User Groups</h1>
    <p>
        <a href="/">Home</a>
    </p>

    <ul>
        <?php foreach (DB::query('SELECT id, `name` FROM user_groups ORDER BY `name`') as $userGroup) : ?>
            <li>
                <a href="/user-group?id=<?= $userGroup['id'] ?>"><?= e($userGroup['name']) ?></a>
                &lt;<?= e(implode(', ', DB::queryFirstColumn('SELECT `name` FROM users INNER JOIN user_user_group ON users.id = user_user_group.user_id WHERE user_group_id = %s', $userGroup['id']))) ?>&gt;
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
