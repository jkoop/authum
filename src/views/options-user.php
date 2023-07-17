<?php foreach (memo('users', fn () => DB::query('SELECT id, `name` FROM users ORDER BY `name` ASC')) as $user) : ?>
    <option value="<?= e($user['id']) ?>" <?= ($selected ?? '') == $user['id'] ? 'selected' : '' ?>>
        <?= e($user['name']) ?>
    </option>
<?php endforeach ?>
