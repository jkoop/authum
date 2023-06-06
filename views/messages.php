<?php foreach ($_SESSION['errors'] ?? [] as $error) : ?>
    <div style="background-color:red;color:white;padding:1rem">
        <?= e($error) ?>
    </div>
<?php endforeach; ?>
<?php $_SESSION['errors'] = [] ?>
