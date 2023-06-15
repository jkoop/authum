<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => $userGroup['name'] . ' - User Groups']) ?></head>

<body>
    <h1><?= e($userGroup['name']) ?></h1>
    <?php view('navigation') ?>

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
