@extends('layouts.html')
@section('actual-content')
    <nav>
        <a href="/">
            <h1>{{ config('app.name') }}</h1>
        </a>
        <a href="/">{{ __('Home') }}</a>

        @if (Auth::user()?->is_admin)
            <a href="/users">{{ __('Users') }}</a>
            <a href="/services">{{ __('Services') }}</a>
        @endif

        <a href="/profile" class="ml-auto">{{ __('Profile') }}</a>

        @auth <a href="/logout">{{ __('Logout') }}</a> @endauth
    </nav>

    <article>
        <h1>@yield('title')</h1>

        @include('blocks.messages')

        @yield('content')
    </article>

    <footer>
        <div>
            {{ __('Logged in as :userName', ['userName' => Auth::user()?->name ?? 'nobody']) }}
        </div>
        <address class="ml-auto"><a href="https://github.com/jkoop/authum" target="_blank">{{ __('Authum GitHub') }}</a>
        </address>
    </footer>
@endsection
