<!DOCTYPE html>
<html lang="en-CA">

<head><?php view('head', ['title' => $group['name'] . ' - Groups']) ?></head>

<body>
    <?php view('navigation') ?>

    <main>
        <h1>Group: <?= e($group['name']) ?></h1>

        <form method="post">
            <fieldset>
                <legend>General</legend>
                <?php if (isset($group['id'])) : ?>
                    <label>Name <input name="name" maxlength="255" value="<?= e($group['name']) ?>" required /></label><br>
                <?php else : ?>
                    <label>Name <input name="name" maxlength="255" autofocus required /></label><br>
                <?php endif ?>
            </fieldset>

            <fieldset>
                <legend>Users</legend>
                <table>
                    <thead>
                        <th>User</th>
                        <th>Detach?</th>
                    </thead>
                    <tbody>
                        <?php foreach ($users as $user) : ?>
                            <tr>
                                <td><a href="/user?id=<?= e($user['id']) ?>"><?= e($user['name']) ?></a></td>
                                <td><input name="detach_users[]" value="<?= e($user['id']) ?>" type="checkbox" /></td>
                            </tr>
                        <?php endforeach ?>
                        <tr>
                            <td>
                                <select name="add_user">
                                    <option value="">-- add user --</option>
                                    <?php view('options-user') ?>
                                </select>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </fieldset>

            <button type="submit">Save</button>
            <button type="submit" form="delete">Delete</button>
        </form>

        <form method="post" id="delete" style="display:none" onsubmit="return confirm(<?= e(json_encode('Really delete "' . $group['name'] . '" forever?')) ?>)">
            <input name="action" value="delete" />
        </form>
    </main>

    <?php view('footer') ?>
</body>

</html>
