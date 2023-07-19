<fieldset id="navigation">
    <legend>Navigation</legend>
    <a href="/">Home</a><br>
    <?php if (Checks::isAdmin()) : ?>
        <a href="/acl" data-regex="/acl">ACL</a><br>
        <a href="/services" data-regex="/service(s|/|$)">Services</a><br>
        <a href="/users" data-regex="/user(s|/|$)">Users</a><br>
        <a href="/groups" data-regex="/group(s|/|$)">Groups</a><br>
    <?php endif ?>
</fieldset>

<?= scriptTag('navigation', async: true) ?>
