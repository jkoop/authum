<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title><?= e($user['name']) ?> - Users - Authum</title>
</head>

<body>
    <h1><?= e($user['name']) ?></h1>
    <p>
        <a href="/">Home</a>
        <a href="/users">Users</a>
    </p>

    <h2>Email addresses</h2>

    <ul>
        <?php foreach ($emailAddresses as $emailAddress) : ?>
            <li>
                <a href="mailto:<?= e($emailAddress['email_address']) ?>"><?= e($emailAddress['email_address']) ?></a>
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
