<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title><?= e($service['name']) ?> - Services - Authum</title>
    <link rel="stylesheet" href="/main.css" />
</head>

<body>
    <h1><?= e($service['name']) ?></h1>
    <?php view('navigation') ?>

    <h2>Domain Names</h2>

    <ul>
        <?php foreach ($domainNames as $domainName) : ?>
            <li>
                <a href="//<?= e($domainName['domain_name']) ?>"><?= e($domainName['domain_name']) ?></a>
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
