<nav>
    <a href="/">Home</a>
    <?php if (Checks::isAdmin()) : ?>
        <a href="/acl" data-regex="/acl">ACL</a>
        <a href="/services" data-regex="/service(s|/|$)">Services</a>
        <a href="/users" data-regex="/user(s|/|$)">Users</a>
        <a href="/groups" data-regex="/group(s|/|$)">Groups</a>
    <?php endif ?>
    <a href="/profile">Profile</a>
    <a href="/logout">Logout</a>
</nav>

<?= scriptTag('navigation', async: true) ?>
