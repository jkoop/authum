<footer>
<span style="color:red">this site needs to be rewritten</span><br>
    Authum<?= '' /* '/' . e(AUTHUM_VERSION) */ ?> -
    logged in as <?= e(loggedInUser()['name']) ?> <?php view('discord-icon-link', ['id' => loggedInUser()['id']]) ?>
</footer>
