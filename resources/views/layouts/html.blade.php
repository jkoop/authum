<!doctype html>
<html lang="en_CA">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title') - {{ config('app.name') }}</title>

    <style>
        /* quikscript */
        @font-face {
            font-family: "Quikscript Geometric";
            font-style: normal;
            font-weight: 400;
            font-display: swap;
            src: url(/fonts/QuikscriptGeometric.woff2) format("woff2");
            unicode-range: U+E650-E67F;
        }
    </style>

    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>

<body>
    @yield('actual-content')
</body>

</html>
