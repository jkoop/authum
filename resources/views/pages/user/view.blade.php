@extends('layouts.main')
@section('title', __('User: :userName', ['userName' => $user->name]))
@section('content')

    <h2>{{ __('General') }}</h2>

    <form method="post" action="/user/{{ $user->id }}">
        @csrf
        <x-string-input :label="__('Name')" name="name" :value="$user->name" required /><br>
        <x-checkbox :label="__('Is Admin?')" name="is_admin" :checked="$user->is_admin" /><br>
        <x-checkbox :label="__('Is Enabled?')" name="is_enabled" :checked="$user->is_enabled" /><br>
        <button type="submit">{{ __('Save') }}</button>
    </form>

    <h2>{{ __('Change password') }}</h2>

    <form method="post" action="/user/{{ $user->id }}/change-password">
        @csrf
        <label>
            {{ __('New password') }}<br>
            <input type="password" name="password" minlength="8" required />
        </label><br>
        <button type="submit">{{ __('Change password') }}</button>
    </form>

    <h2>{{ __('Email addresses') }}</h2>

    @if ($user->emailAddresses->count() > 0)
        <table>
            <tbody>
                @foreach ($user->emailAddresses->sortBy('sortValue') as $emailAddress)
                    <tr>
                        <td>{{ $emailAddress->email_address }}</td>
                        <td>
                            <form method="post" action="/email-address/{{ $emailAddress->email_address }}"
                                onSubmit="return confirm({{ json_encode(
                                    __('Really delete :email from :userName?', [
                                        'email' => $emailAddress->email_address,
                                        'userName' => $user->name,
                                    ]),
                                ) }})">
                                @csrf @method('DELETE')
                                <button type="submit">{{ __('Delete') }}</button>
                            </form>
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    @else
        <i>{{ __(":userName doesn't have any email addresses", ['userName' => $user->name]) }}</i>
    @endif

    <form method="post" action="/user/{{ $user->id }}/email-address">
        @csrf
        <label>
            {{ __('New email address') }}<br>
            <input name="email" type="email" required />
        </label><br>
        <button type="submit">{{ __('Add email address') }}</button>
    </form>

@endsection
