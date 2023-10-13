<footer>
    Authum<?= '' /* '/' . e(AUTHUM_VERSION) */ ?> -
    logged in as <?= e(loggedInUser()['name']) ?> <?php view('discord-icon-link', ['id' => loggedInUser()['id']]) ?>
</footer>
