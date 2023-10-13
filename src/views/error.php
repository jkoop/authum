<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title><?= $status ?> <?= e($defaultMessages[$status] ?? '') ?> - Authum</title>
    <link rel="icon" href="<?= config('app.url') ?>/favicon.ico" />
    <link rel="icon" href="<?= config('app.url') ?>/favicon.png" />
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Slabo+27px&display=swap" rel="stylesheet">
    <?= styleTag('error', fullUrl: true) ?>
    <?= styleTag('main', fullUrl: true) ?>
</head>

<body>
    <h1><?= e($defaultMessages[$status] ?? '') ?></h1>
    <?php if (strlen($message ?? '')) : ?>
        <p><?= e($message) ?></p>
    <?php endif ?>
    <hr>
    <address>
        Authum<?= '' /* '/' . e(AUTHUM_VERSION) */ ?>
        <?php if (Checks::isLoggedIn()) : ?>
            - logged in as <?= e(loggedInUser()['name']) ?> <?php view('discord-icon-link', ['id' => loggedInUser()['id']]) ?>
            - <a href="<?= config('app.url') ?>">Home</a>
            - <a href="<?= config('app.url') ?>/logout">Logout</a>
        <?php endif ?>
    </address>
</body>

</html>
