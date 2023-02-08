@extends('layouts.card')
@section('title', 'Login')
@section('backdrop')

    <iframe src="/dashboard/fake"
        style="border: none; position: absolute; left: 0; top: 0; width: 100%; height: 100%; overflow: hidden;"></iframe>

@endsection

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
