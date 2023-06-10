<?php foreach (memo('userGroups', fn () => DB::query('SELECT id, `name` FROM user_groups ORDER BY `name` ASC')) as $userGroup) : ?>
    <option value="<?= e($userGroup['id']) ?>" <?= ($selected ?? '') == $userGroup['id'] ? 'selected' : '' ?>>
        <?= e($userGroup['name']) ?>
    </option>
<?php endforeach ?>
