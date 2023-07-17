<fieldset>
    <legend>Navigation</legend>
    <a href="/">Home</a><br>
    <?php if (Checks::isAdmin()) : ?>
        <a href="/acl">ACL</a><br>
        <a href="/services">Services</a><br>
        <a href="/service-groups">Service Groups</a><br>
        <a href="/users">Users</a><br>
        <a href="/user-groups">User Groups</a><br>
    <?php endif ?>
</fieldset>
