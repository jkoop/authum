<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title><?= $status ?> - Authum</title>
</head>

<body>
    <h1><?= $status ?> <?= e($defaultMessages[$status] ?? '') ?></h1>
    <p>
        <?= e($message ?? '') ?>
    </p>
    <?php if (Checks::isLoggedIn()) : ?>
        <?php view('logged-in-footer') ?>
    <?php else : ?>
        <hr>
        <address>Authum/<?= e(AUTHUM_VERSION) ?></address>
    <?php endif ?>
</body>

</html>
