@extends('layouts.card')
@section('title', 'Forgot password')
@section('content')

    <form method="post">
        @csrf
        <label>
            Email address<br>
            <input name="email" type="email" maxlength="255" autofocus required />
        </label><br>
        <button type="submit">Send reset email</button>
    </form>

    <p><a href="/login">Login</a></p>

@endsection
