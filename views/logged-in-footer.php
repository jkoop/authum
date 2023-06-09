<hr>
<address>
    Authum/<?= e(AUTHUM_VERSION) ?> -
    logged in as <?= e(loggedInUser()['name']) ?> -
    <a href="<?= e(rtrim($_ENV['APP_URL'])) ?>/logout">logout</a>
</address>
