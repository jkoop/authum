@extends('layouts.card')
@section('title', 'Forgot password')
@section('backdrop')

    <iframe src="/dashboard/fake"
        style="border: none; position: absolute; left: 0; top: 0; width: 100%; height: 100%; overflow: hidden;"></iframe>

@endsection

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
