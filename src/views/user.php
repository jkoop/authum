<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => $user['name'] . ' - Users']) ?></head>

<body>
    <h1><?= e($user['name']) ?></h1>
    <?php view('navigation') ?>

    <form method="post" action="/impersonate?user_id=<?= e($user['id']) ?>">
        <fieldset>
            <legend>Administration</legend>
            <button type="submit">Impersonate</button>
        </fieldset>
    </form>

    <form method="post">
        <fieldset>
            <legend>General</legend>
            <label>Name <input name="name" maxlength="255" value="<?= e($user['name']) ?>" /></label><br>
            <label><input name="is_admin" type="checkbox" <?= $user['is_admin'] ? 'checked' : '' ?> /> Is admin?</label><br>
            <label><input name="is_enabled" type="checkbox" <?= $user['is_enabled'] ? 'checked' : '' ?> /> Is enabled?</label>
        </fieldset>

        <fieldset>
            <legend>Password</legend>
            <table>
                <!-- <tr>
                    <th>Current</th>
                    <td><input name="password" type="password" /></td>
                </tr> -->
                <tr>
                    <th>New</th>
                    <td><input name="password_new" type="password" /></td>
                </tr>
                <!-- <tr>
                    <th>New, again</th>
                    <td><input name="password_new2" type="password" /></td>
                </tr> -->
            </table>
        </fieldset>

        <fieldset>
            <legend>Email Addresses</legend>
            <table>
                <thead>
                    <th>Email Address</th>
                    <th>Delete?</th>
                </thead>
                <tbody>
                    <?php foreach ($emailAddresses as $emailAddress) : ?>
                        <tr>
                            <td><a href="mailto:<?= e($emailAddress['email_address']) ?>"><?= e($emailAddress['email_address']) ?></a></td>
                            <td><input name="delete_<?= e($emailAddress['email_address']) ?>" type="checkbox" /></td>
                        </tr>
                    <?php endforeach ?>
                    <tr>
                        <td>
                            <input name="add_email_address" type="email" maxlength="255" placeholder="add address" />
                        </td>
                    </tr>
                </tbody>
            </table>
        </fieldset>

        <button type="submit">Save</button>
    </form>

    <?php view('logged-in-footer') ?>
</body>

</html>
