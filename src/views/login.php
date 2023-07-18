<!DOCTYPE html>
<html lang="en-CA">

<head>
    <?php view('head', ['title' => 'Login']) ?>
    <?= styleTag('login') ?>
</head>

<body>
    <h1>Login</h1>
    <?php include __DIR__ . '/messages.php'; ?>
    <form method="post">
        <input type="email" name="email" placeholder="email" autofocus /><br>
        <input type="password" name="password" placeholder="password" /><br>
        <button type="submit">Login</button>
    </form>
    <?php if (config('discord.enabled')) : ?>
        <span> &mdash; or &mdash; </span>
        <a href="https://joekoop.com"><img src="/discord_full_logo_white_RGB.svg" /></a>
    <?php endif ?>
</body>

</html>
