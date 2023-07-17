document.querySelectorAll('#navigation a').forEach(a => {
    if (location.href == a.href || a.dataset.regex?.length > 0 && new RegExp(a.dataset.regex).test(location.pathname)) {
        a.after(document.createTextNode(' ⇐'));
    }
});
