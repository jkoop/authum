@extends('layouts.main')
@section('title', "User: $user->name")
@section('content')

    <h2>General</h2>

    <form method="post" action="/user/{{ $user->id }}">
        @csrf
        <x-string-input label="Name" name="name" :value="$user->name" required /><br>
        <x-checkbox label="Is Admin?" name="is_admin" :checked="$user->is_admin" /><br>
        <x-checkbox label="Is Enabled?" name="is_enabled" :checked="$user->is_enabled" /><br>
        <button type="submit">Save</button>
    </form>

    <h2>Change password</h2>

    <form method="post" action="/user/{{ $user->id }}/change-password">
        @csrf
        <label>
            New password<br>
            <input type="password" name="password" minlength="8" required />
        </label><br>
        <button type="submit">Change password</button>
    </form>

    <h2>Email addresses</h2>

    <table>
        <tbody>
            @foreach ($user->emailAddresses->sortBy('sortValue') as $emailAddress)
                <tr>
                    <td>{{ $emailAddress->email_address }}</td>
                    <td>
                        <form method="post" action="/email-address/{{ $emailAddress->email_address }}"
                            onSubmit="return confirm('Really delete ' + {{ json_encode($emailAddress->email_address) }} + ' from ' + {{ json_encode($user->name) }} + '?')">
                            @csrf @method('DELETE')
                            <button type="submit">Delete</button>
                        </form>
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>

    <form method="post" action="/user/{{ $user->id }}/email-address">
        @csrf
        <label>
            New email address<br>
            <input name="email" type="email" required />
        </label><br>
        <button type="submit">Add email address</button>
    </form>

@endsection
