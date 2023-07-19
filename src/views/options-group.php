<?php foreach (memo('groups', fn () => DB::query('SELECT id, `name` FROM groups ORDER BY `name` ASC')) as $group) : ?>
    <option value="<?= e($group['id']) ?>" <?= ($selected ?? '') == $group['id'] ? 'selected' : '' ?>>
        <?= e($group['name']) ?>
    </option>
<?php endforeach ?>
