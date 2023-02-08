@extends('layouts.card')
@section('title', 'Reset password')
@section('backdrop')

    <iframe src="/dashboard/fake"
        style="border: none; position: absolute; left: 0; top: 0; width: 100%; height: 100%; overflow: hidden;"></iframe>

@endsection

@section('content')

    <p>BTW: This is for {{ $user->name }}</p>

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
