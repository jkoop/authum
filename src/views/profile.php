<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => 'Profile']) ?></head>

<body>
    <h1>Profile</h1>
    <?php view('navigation') ?>

    <form method="post">
        <fieldset>
            <legend>General</legend>
            <label>ID <?php view('discord-icon-link', ['id' => loggedInUser()['id']]) ?> <input name="username" value="<?= e(loggedInUser()['id']) ?>" readonly /></label><br>
            <?php if (preg_match('/^[0-9]+$/', loggedInUser()['id'])) : ?>
                <label>Name <input value="<?= e(loggedInUser()['name']) ?>" readonly /></label><br>
                Your name is taken from Discord<br>
            <?php else : ?>
                <label>Name <input name="name" maxlength="255" value="<?= e(loggedInUser()['name']) ?>" required /></label><br>
            <?php endif ?>
        </fieldset>

        <fieldset>
            <legend>Password</legend>
            <label>New <input name="password" type="password" /></label><br>
            <p style="margin-bottom: 0">This password lets you log in without having to use Discord. This can be useful for old browsers, slow connections, WebDAV <a href="https://en.wikipedia.org/wiki/WebDAV" target="_blank">(?)</a>, <code>curl</code> <a href="https://en.wikipedia.org/wiki/CURL#curl" target="_blank">(?)</a>, etc.</p>
        </fieldset>

        <button type="submit">Save</button>
    </form>

    <?php view('logged-in-footer') ?>
</body>

</html>
