@extends('layouts.main')
@section('title', __('Profile'))
@section('content')

    <h2>{{ __('General') }}</h2>

    <form method="post" action="/profile">
        @csrf
        <x-string-input :label="__('Name')" name="name" :value="$user->name" required /><br>
        <button type="submit">{{ __('Save') }}</button>
    </form>

    <h2>{{ __('Change password') }}</h2>

    <form method="post" action="/profile/change-password">
        @csrf
        <label>
            {{ __('Current password') }}<br>
            <input type="password" name="current_password" required />
        </label><br>
        <label>
            {{ __('New password') }}<br>
            <input type="password" name="password" minlength="8" required />
        </label><br>
        <label>
            {{ __('New password, again') }}<br>
            <input type="password" name="password_confirmation" minlength="8" required />
        </label><br>
        <button type="submit">{{ __('Change password') }}</button>
    </form>

    <h2>{{ __('Email addresses') }}</h2>

    @if ($user->emailAddresses->count() > 0)
        <table>
            <tbody>
                @foreach ($emailAddresses as $emailAddress)
                    <tr>
                        <td>{{ $emailAddress->email_address }}</td>
                        @if ($user->emailAddresses->count() >= 2)
                            <td>
                                <form method="post" action="/email-address/{{ $emailAddress->email_address }}"
                                    onSubmit="return confirm({{ json_encode(__("Really delete :emailAddress? You won't be able to log in with it anymore", ['emailAddress' => $emailAddress->email_address])) }})">
                                    @csrf @method('DELETE')
                                    <button type="submit">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        @endif
                    </tr>
                @endforeach
            </tbody>
        </table>
    @else
        <i>{{ __("You don't have any email addresses, and won't be able to log in") }}</i>
    @endif

    <form method="post" action="/email-address">
        @csrf
        <label>
            {{ __('New email address') }}<br>
            <input name="email" type="email" required />
        </label><br>
        <button type="submit">{{ __('Send verification email') }}</button>
    </form>

@endsection
