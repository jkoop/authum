<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => 'Login']) ?></head>

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
