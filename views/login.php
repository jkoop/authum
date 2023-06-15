<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title>Login - Authum</title>
    <link rel="stylesheet" href="/main.css" />
</head>

<body>
    <h1>Login</h1>
    <?php include __DIR__ . '/messages.php'; ?>
    <form method="post">
        <label>Email: <input type="email" name="email" autofocus /></label><br>
        <label>Password: <input type="password" name="password" /></label><br>
        <button type="submit">Login</button>
    </form>
</body>

</html>
