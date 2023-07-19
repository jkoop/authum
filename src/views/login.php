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
        <input type="text" name="username" placeholder="id" autofocus /><br>
        <input type="password" name="password" placeholder="password" /><br>
        <button type="submit">Login</button>
    </form>
    <?php if (config('discord.enabled')) : ?>
        <span> &mdash; or &mdash; </span>
        <a href="<?= e('https://discord.com/api/oauth2/authorize?' . http_build_query([
                        'client_id' => config('discord.client_id'),
                        'redirect_uri' => config('app.url') . '/callback/discord',
                        'response_type' => 'code',
                        'scope' => 'identify',
                    ])) ?>"><img src="/discord_full_logo_white_RGB.svg" /></a>
    <?php endif ?>
</body>

</html>
