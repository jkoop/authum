@extends('layouts.card')
@section('title', 'Login')
@section('content')

    <form method="post">
        @csrf
        <label>
            Username or email<br>
            <input name="username" maxlength="255" autofocus required />
        </label><br>
        <label>
            Password<br>
            <input name="password" type="password" required />
        </label><br>
        <button type="submit">Log in</button>
    </form>

@endsection
