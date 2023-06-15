<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => 'Service Groups']) ?></head>

<body>
    <h1>Service Groups</h1>
    <?php view('navigation') ?>

    <ul>
        <?php foreach (DB::query('SELECT id, `name` FROM service_groups ORDER BY `name`') as $serviceGroup) : ?>
            <li>
                <a href="/service-group?id=<?= $serviceGroup['id'] ?>"><?= e($serviceGroup['name']) ?></a>
                &lt;<?= e(implode(', ', DB::queryFirstColumn('SELECT `name` FROM services INNER JOIN service_service_group ON services.id = service_service_group.service_id WHERE service_group_id = %s', $serviceGroup['id']))) ?>&gt;
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
