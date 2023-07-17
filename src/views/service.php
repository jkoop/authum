<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => $service['name'] . ' - Services']) ?></head>

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
