document.querySelectorAll('nav a').forEach(a => {
    if (location.pathname == a.pathname || a.dataset.regex?.length > 0 && new RegExp(a.dataset.regex).test(location.pathname)) {
        a.classList.add('active');
    }
});
