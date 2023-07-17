<style>
    #navigation a .active {
        color: black;
        text-decoration: none;
    }
</style>

<fieldset id="navigation">
    <legend>Navigation</legend>
    <a href="/">Home</a><br>
    <?php if (Checks::isAdmin()) : ?>
        <a href="/acl" data-regex="/acl">ACL</a><br>
        <a href="/services" data-regex="/service(s|/|$)">Services</a><br>
        <a href="/service-groups" data-regex="/service-group(s|/|$)">Service Groups</a><br>
        <a href="/users" data-regex="/user(s|/|$)">Users</a><br>
        <a href="/user-groups" data-regex="/user-group(s|/|$)">User Groups</a><br>
    <?php endif ?>
</fieldset>

<script>
    document.querySelectorAll('#navigation a').forEach(a => {
        if (location.href == a.href || a.dataset.regex?.length > 0 && new RegExp(a.dataset.regex).test(location.pathname)) {
            let span = document.createElement('span');
            span.classList.add('active');
            span.textContent = ' ⇐';
            a.parentNode.insertBefore(span, a.nextElementSibling);
        }
    });
</script>
