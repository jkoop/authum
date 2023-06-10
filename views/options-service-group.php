<?php foreach (memo('serviceGroups', fn () => DB::query('SELECT id, `name` FROM service_groups ORDER BY `name` ASC')) as $serviceGroup) : ?>
    <option value="<?= e($serviceGroup['id']) ?>" <?= ($selected ?? '') == $serviceGroup['id'] ? 'selected' : '' ?>>
        <?= e($serviceGroup['name']) ?>
    </option>
<?php endforeach ?>
