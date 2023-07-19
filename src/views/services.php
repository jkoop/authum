<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => 'Services']) ?></head>

<body>
    <h1>Services</h1>
    <?php view('navigation') ?>

    <ul>
        <?php foreach (DB::query('SELECT `id`, `name`, `domain_name` FROM `services` ORDER BY `name`') as $service) : ?>
            <li>
                <a href="/service?id=<?= $service['id'] ?>"><?= e($service['name']) ?></a>
                &lt;<?= e($service['domain_name']) ?>&gt;
            </li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
