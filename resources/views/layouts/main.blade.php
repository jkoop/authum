@extends('layouts.html')
@section('actual-content')
    @include('blocks.messages')

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
@endsection
