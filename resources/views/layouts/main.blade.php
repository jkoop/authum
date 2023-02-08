@extends('layouts.html')
@section('actual-content')
    @include('blocks.messages')

    <div id="content">
        <h1>@yield('title')</h1>

        @yield('content')
    </div>

    <hr>
    <footer>
        Logged in as {{ Auth::user()?->name ?? Str::of('<i>nobody</i>')->toHtmlString() }}
        @auth <a href="/logout" style="float:right">Logout</a> @endauth
    </footer>
@endsection
