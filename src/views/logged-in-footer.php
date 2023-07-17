<hr>
<address>
    Authum/<?= e(AUTHUM_VERSION) ?> -
    logged in as <?= e(loggedInUser()['name']) ?> -
    <a href="<?= e(config('app.url')) ?>/logout">logout</a>
</address>
