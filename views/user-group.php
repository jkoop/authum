<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title><?= e($userGroup['name']) ?> - User Groups - Authum</title>
</head>

<body>
    <h1><?= e($userGroup['name']) ?></h1>
    <p>
        <a href="/">Home</a>
        <a href="/user-groups">User Groups</a>
    </p>

    <h2>Users</h2>

    <ul>
        <?php foreach ($users as $user) : ?>
            <li>
                <a href="/user?id=<?= e($user['id']) ?>"><?= e($user['name']) ?></a>
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
