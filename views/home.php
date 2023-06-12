<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title>Home - Authum</title>
</head>

<body>
    <h1>Home</h1>

    <?php if (Checks::isAdmin()) : ?>
        <ul>
            <li><a href="/acl">ACL</a></li>
            <li><a href="/services">Services</a></li>
            <li><a href="/service-groups">Service Groups</a></li>
            <li><a href="/users">Users</a></li>
            <li><a href="/user-groups">User Groups</a></li>
        </ul>
    <?php endif ?>

    <h2>Services</h2>

    <ul>
        <?php foreach (DB::query('SELECT DISTINCT id, name, domain_name FROM services INNER JOIN domain_names ON services.id = domain_names.service_id') as $service) : ?>
            <li><a href="//<?= e($service['domain_name']) ?>"><?= e($service['name']) ?></a></li>
        <?php endforeach ?>
    </ul>

    <?php view('logged-in-footer') ?>
</body>

</html>
