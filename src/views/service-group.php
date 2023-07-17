<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => $serviceGroup['name'] . ' - Service Groups']) ?></head>

<body>
    <h1><?= e($serviceGroup['name']) ?></h1>
    <?php view('navigation') ?>

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
