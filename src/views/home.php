<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => 'Home']) ?></head>

<body>
    <?php view('navigation') ?>

    <main>
        <h1>Home</h1>
        <h2>Services</h2>

        <?php if (empty($services)) : ?>
            <p><i>There are no services of which you may <span style="font-family: monospace">GET /</span>.</i></p>
        <?php else : ?>
            <ul>
                <?php foreach ($services as $service) : ?>
                    <li><a href="//<?= e($service['domain_name']) ?>"><?= e($service['name']) ?></a></li>
                <?php endforeach ?>
            </ul>
        <?php endif ?>

        <?php if (count($services) != DB::queryFirstField('SELECT COUNT(*) FROM `services`')) : ?>
            <p>There may be more services than those listed above of which you are only permitted to access a subset.</p>
        <?php endif ?>
    </main>

    <?php view('footer') ?>
</body>

</html>
