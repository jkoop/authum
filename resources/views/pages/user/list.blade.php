@extends('layouts.main')
@section('title', __('Users'))
@section('content')
    <form method="post" action="/user/new">
        @csrf
        <button type="submit">{{ __('Create new user') }}</button>
    </form>

    <table>
        <thead>
            <tr>
                <th>{{ __('Name') }}</th>
                <th>{{ __('Email Addresses') }}</th>
                <th>{{ __('Is Admin?') }}</th>
                <th>{{ __('Is Enabled?') }}</th>
                <th>{{ __('Created At') }}</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($users as $user)
                <tr>
                    <td><a href="/user/{{ $user->id }}">{{ $user->name }}</a></td>
                    <td>
                        @foreach ($user->emailAddresses->sortBy('sortValue') as $emailAddress)
                            <span class="block">{{ $emailAddress->email_address }}</span>
                        @endforeach
                    </td>
                    <td>{{ $user->is_admin ? __('Yes') : __('No') }}</td>
                    <td>{{ $user->is_enabled ? __('Yes') : __('No') }}</td>
                    <td>{{ $user->created_at->format('Y M d H:i') }}<span
                            class="opacity-50">{{ $user->created_at->format(':s e') }}</span></td>
                    <td>
                        <form method="post" action="/user/{{ $user->id }}"
                            onSubmit="return confirm({{ json_encode(__('Really delete :userName?', ['userName' => $user->name])) }})">
                            @csrf
                            @method('DELETE')<button type="submit">{{ __('Delete') }}</button></form>
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>
@endsection
