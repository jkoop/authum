@extends('layouts.html')
@section('actual-content')
    <nav>
        <a href="/">
            <h1>Authum</h1>
        </a>
        <a href="/">Home</a>

        @can('list', App\Models\User::class)
            <a href="/users">Users</a>
        @endcan

        <a href="/profile" class="ml-auto">Profile</a>

        @auth <a href="/logout">Logout</a> @endauth
    </nav>

    <article>
        <h1>@yield('title')</h1>

        @include('blocks.messages')

        @yield('content')
    </article>

    <footer>
        <div>Logged in as {{ Auth::user()?->name ?? Str::of('<i>nobody</i>')->toHtmlString() }}</div>
        <address class="ml-auto"><a href="https://github.com/jkoop/authum" target="_blank">Authum GitHub</a></address>
    </footer>
@endsection
