<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title>Users - Authum</title>
    <link rel="stylesheet" href="/main.css" />
</head>

<body>
    <h1>Users</h1>
    <?php view('navigation') ?>

    <ul>
        <?php foreach (DB::query('SELECT id, `name` FROM users ORDER BY `name`') as $user) : ?>
            <li>
                <a href="/user?id=<?= $user['id'] ?>"><?= e($user['name']) ?></a>
                &lt;<?= e(implode(', ', DB::queryFirstColumn('SELECT email_address FROM email_addresses WHERE user_id = %s', $user['id']))) ?>&gt;
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
