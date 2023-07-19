<hr>
<address>
    Authum<?= '' /* '/' . e(AUTHUM_VERSION) */ ?> -
    logged in as <?= e(loggedInUser()['name']) ?> <?php view('discord-icon-link', ['id' => loggedInUser()['id']]) ?> -
    <a href="<?= e(config('app.url')) ?>/logout">logout</a>
</address>
