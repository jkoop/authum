<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => $service['name'] . ' - Services']) ?></head>

<body>
    <?php view('navigation') ?>

    <main>
        <h1>Service: <?= e($service['name']) ?></h1>

        <p>
            Name: <?= e($service['name']) ?><br>
            Domain Name: <?= e($service['domain_name']) ?><br>
            Logout Path: <?= e($service['logout_path']) ?><br>
        </p>
    </main>

    <?php view('footer') ?>
</body>

</html>
