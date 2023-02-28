@extends('layouts.card')
@section('title', 'Login')
@section('content')

    <form method="post">
        @csrf
        <label>
            Email address<br>
            <input name="email" maxlength="255" autofocus required />
        </label><br>
        <label>
            Password<br>
            <input name="password" type="password" required />
        </label><br>
        <button type="submit">Log in</button>
    </form>

    <p><a href="/password-reset">Forgot password</a></p>

@endsection
