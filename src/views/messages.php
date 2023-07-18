<?php foreach ($_SESSION['errors'] ?? [] as $error) : ?>
    <div class="error">
        <?= e($error) ?>
    </div>
<?php endforeach; ?>
<?php $_SESSION['errors'] = [] ?>
