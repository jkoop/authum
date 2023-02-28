@extends('layouts.main')
@section('title', 'Profile')
@section('content')

    <h2>General</h2>

    <form method="post" action="/profile">
        @csrf
        <label>
            Name<br>
            <input name="name" value="{{ old('name') ?? $user->name }}" maxlength="255" />
        </label><br>
        <button type="submit">Save</button>
    </form>

    <h2>Change password</h2>

    <form method="post" action="/profile/change-password">
        @csrf
        <label>
            Current password<br>
            <input type="password" name="current_password" required />
        </label><br>
        <label>
            New password<br>
            <input type="password" name="password" minlength="8" required />
        </label><br>
        <label>
            New password, again<br>
            <input type="password" name="password_confirmation" minlength="8" required />
        </label><br>
        <button type="submit">Change password</button>
    </form>

    <h2>Email addresses</h2>

    <table>
        <tbody>
            @foreach ($emailAddresses as $emailAddress)
                <tr>
                    <td>{{ $emailAddress->email_address }}</td>
                    @if ($user->emailAddresses->count() >= 2)
                        <td>
                            <form method="post" action="/email-address/{{ $emailAddress->email_address }}"
                                onSubmit="return confirm('Really delete ' + {{ json_encode($emailAddress->email_address) }} + '? You won\'t be able to log in with it anymore.')">
                                @csrf @method('DELETE')
                                <button type="submit">Delete</button>
                            </form>
                        </td>
                    @endif
                </tr>
            @endforeach
        </tbody>
    </table>

    <form method="post" action="/email-address">
        @csrf
        <label>
            New email address<br>
            <input name="email" type="email" />
        </label><br>
        <button type="submit">Send verification email</button>
    </form>

@endsection
