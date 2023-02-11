@extends('layouts.html')
@section('actual-content')
    <div id="content">
        <h1>@yield('title')</h1>

        @include('blocks.messages')

        <nav>
            <ul>
                <li><a href="/">Home</a></li>
                <li><a href="/profile">Profile</a></li>
                @auth <li><a href="/logout">Logout</a></li> @endauth
            </ul>
        </nav>

        @yield('content')
    </div>

    <hr>
    <footer>
        Logged in as {{ Auth::user()?->name ?? Str::of('<i>nobody</i>')->toHtmlString() }}
    </footer>
@endsection
