<!doctype html>
<html lang="en_CA">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title') - {{ config('app.name') }}</title>
</head>

<body>
    @if ($errors->count())
        Errors:<br>
        <ul id="errors">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    @endif

    <article id="content">
        <h1>@yield('title')</h1>

        @yield('content')
    </article>

    @auth
        <hr>
        <footer>
            Logged in as {{ Auth::user()->name }}
            <a href="/logout" style="float:right">Logout</a>
        </footer>

        @dump(Session::getId())
    @endauth
</body>

</html>
