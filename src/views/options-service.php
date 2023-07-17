<?php foreach (memo('services', fn () => DB::query('SELECT id, `name` FROM services ORDER BY `name` ASC')) as $service) : ?>
    <option value="<?= e($service['id']) ?>" <?= ($selected ?? '') == $service['id'] ? 'selected' : '' ?>>
        <?= e($service['name']) ?>
    </option>
<?php endforeach ?>
