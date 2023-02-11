@extends('layouts.main')
@section('title', 'Profile')
@section('content')

    <h2>General</h2>

    <form method="post" action="/profile/change-password">
        @csrf
        <label>
            Name<br>
            <input name="name" value="{{ old('name') ?? $user->name }}" maxlength="255" />
        </label><br>
        <label>
            Current password<br>
            <input name="current_password" type="password" />
        </label><br>
        <label>
            New password<br>
            <input name="password" type="password" />
        </label><br>
        <label>
            New password, again<br>
            <input name="password_confirmation" type="password" />
        </label><br>
        <button type="submit">Save</button>
    </form>

    <h2>Email addresses</h2>

    <ul>
        @foreach ($emailAddresses as $emailAddress)
            <li>{{ $emailAddress->email_address }}</li>
        @endforeach
    </ul>

@endsection
