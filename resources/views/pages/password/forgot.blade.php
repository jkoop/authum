@extends('layouts.card')
@section('title', __('Forgot password'))
@section('content')

    <form method="post">
        @csrf
        <label>
            {{ __('Email address') }}<br>
            <input name="email" type="email" maxlength="255" autofocus required />
        </label><br>
        <button type="submit">{{ __('Send reset email') }}</button>
    </form>

    <p><a href="/login">{{ __('Login') }}</a></p>

@endsection
