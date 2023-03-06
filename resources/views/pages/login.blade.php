@extends('layouts.card')
@section('title', __('Login'))
@section('content')

    <form method="post">
        @csrf
        <label>
            {{ __('Email address') }}<br>
            <input name="email" maxlength="255" autofocus required />
        </label><br>
        <label>
            {{ __('Password') }}<br>
            <input name="password" type="password" required />
        </label><br>
        <button type="submit">{{ __('Log in') }}</button>
    </form>

    <p><a href="/password-reset">{{ __('Forgot password') }}</a></p>

@endsection
