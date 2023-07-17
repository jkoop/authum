<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title><?= $status ?> <?= e($defaultMessages[$status] ?? '') ?> - Authum</title>
    <link rel="icon" href="<?= config('app.url') ?>/favicon.ico" />
    <?= styleTag('error', fullUrl: true) ?>
</head>

<body>
    <h1><?= e($defaultMessages[$status] ?? '') ?></h1>
    <?php if (strlen($message ?? '')): ?>
        <p><?= e($message) ?></p>
    <?php endif ?>
    <?php if (Checks::isLoggedIn()) : ?>
        <?php view('logged-in-footer') ?>
    <?php else : ?>
        <hr>
        <address>Authum<?= '' /* '/' . e(AUTHUM_VERSION) */ ?></address>
    <?php endif ?>
</body>

</html>
