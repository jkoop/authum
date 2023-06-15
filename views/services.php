<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title>Services - Authum</title>
    <link rel="stylesheet" href="/main.css" />
</head>

<body>
    <h1>Services</h1>
    <?php view('navigation') ?>

    <ul>
        <?php foreach (DB::query('SELECT id, `name` FROM services ORDER BY `name`') as $service) : ?>
            <li>
                <a href="/service?id=<?= $service['id'] ?>"><?= e($service['name']) ?></a>
                &lt;<?= e(implode(', ', DB::queryFirstColumn('SELECT domain_name FROM domain_names WHERE service_id = %s', $service['id']))) ?>&gt;
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
