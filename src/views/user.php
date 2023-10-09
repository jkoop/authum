<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => $user['name'] . ' - Users']) ?></head>

<body>
    <h1>User: <?= e($user['name']) ?></h1>
    <?php view('navigation') ?>

    <fieldset>
        <legend>Administration</legend>
        <?php if (isset($user['id'])) : ?>
            <form method="post" action="/impersonate">
                <input type="hidden" name="user_id" value="<?= e($user['id']) ?>" />
                <button type="submit">Impersonate</button>
            </form>
        <?php else : ?>
            <button disabled>Impersonate</button>
        <?php endif ?>
    </fieldset>

    <form method="post">
        <fieldset>
            <legend>General</legend>
            <?php if (isset($user['id'])) : ?>
                <label>ID <?php view('discord-icon-link', ['id' => $user['id']]) ?> <input value="<?= e($user['id']) ?>" readonly /></label><br>
                <label>Name <input name="name" maxlength="255" value="<?= e($user['name']) ?>" required /></label><br>
            <?php else : ?>
                <label>ID <input name="id" minlength="1" maxlength="20" placeholder="leave blank for random" /></label><br>
                <label>Name <input name="name" maxlength="255" autofocus required /></label><br>
            <?php endif ?>
            <label>Comment <input name="comment" maxlength="255" value="<?= e($user['comment']) ?>" placeholder="only visible to admins" /></label><br>
            <label><input name="is_admin" type="checkbox" <?= $user['is_admin'] ? 'checked' : '' ?> /> Is admin?</label><br>
            <label><input name="is_enabled" type="checkbox" <?= $user['is_enabled'] ? 'checked' : '' ?> /> Is enabled?</label>
        </fieldset>

        <fieldset>
            <legend>Password</legend>
            <label>New <input name="password_new" type="password" /></label>
        </fieldset>

        <button type="submit">Save</button>
        <button type="submit" form="delete">Delete</button>
    </form>

    <form method="post" id="delete" style="display:none" onsubmit="return confirm(<?= e(json_encode('Really delete "' . $user['name'] . '" forever?')) ?>)">
        <input name="action" value="delete" />
    </form>

    <?php view('logged-in-footer') ?>
</body>

</html>
