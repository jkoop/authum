@extends('layouts.html')
@section('actual-content')
    @include('blocks.messages')

    <div id="content">
        <h1>@yield('title')</h1>

        @yield('content')
    </div>

    @auth
        <hr>
        <footer>
            Logged in as {{ Auth::user()->name }}
            <a href="/logout" style="float:right">Logout</a>
        </footer>
    @endauth
@endsection
