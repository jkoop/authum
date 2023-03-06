@extends('layouts.card')
@section('title', __('Reset password'))
@section('content')

    <p>{{ __('BTW, this is for :userName', ['userName' => $user->name]) }}</p>

    <form method="post">
        @csrf
        <label>
            {{ __('New password') }}<br>
            <input name="password" type="password" autofocus required />
        </label><br>
        <label>
            {{ __('New password, again') }}<br>
            <input name="password_confirmation" type="password" required />
        </label><br>
        <button type="submit">{{ __('Reset password') }}</button>
    </form>

    <p><a href="/login">{{ __('Login') }}</a></p>

@endsection
