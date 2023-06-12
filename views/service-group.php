<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title><?= e($serviceGroup['name']) ?> - Service Groups - Authum</title>
</head>

<body>
    <h1><?= e($serviceGroup['name']) ?></h1>
    <p>
        <a href="/">Home</a>
        <a href="/service-groups">Service Groups</a>
    </p>

    <h2>Services</h2>

    <ul>
        <?php foreach ($services as $service) : ?>
            <li>
                <a href="/service?id=<?= e($service['id']) ?>"><?= e($service['name']) ?></a>
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
