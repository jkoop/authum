@extends('layouts.card')
@section('title', 'Reset password')
@section('content')

    <p>BTW, This is for {{ $user->name }}</p>

    <form method="post">
        @csrf
        <label>
            New password<br>
            <input name="password" type="password" autofocus required />
        </label><br>
        <label>
            New password, again<br>
            <input name="password_confirmation" type="password" required />
        </label><br>
        <button type="submit">Reset password</button>
    </form>

    <p><a href="/login">Login</a></p>

@endsection
