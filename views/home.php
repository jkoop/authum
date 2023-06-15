<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => 'Home']) ?></head>

<body>
    <h1>Home</h1>

    <?php view('navigation') ?>

    <h2>Services</h2>

    <ul>
        <?php foreach (DB::query('SELECT DISTINCT id, name, domain_name FROM services INNER JOIN domain_names ON services.id = domain_names.service_id') as $service) : ?>
            <li><a href="//<?= e($service['domain_name']) ?>"><?= e($service['name']) ?></a></li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
