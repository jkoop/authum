@extends('layouts.main')
@section('title', 'Users')
@section('content')
    <form method="post" action="/user/new">
        @csrf
        <button type="submit">Create new user</button>
    </form>

    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>Email Addresses</th>
                <th>Is Admin?</th>
                <th>Is Enabled?</th>
                <th>Created At</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($users as $user)
                <tr>
                    <td><a href="/user/{{ $user->id }}">{{ $user->name }}</a></td>
                    <td>
                        @foreach ($user->emailAddresses->sortBy('sortValue') as $emailAddress)
                            <span class="block">
                                <a href="mailto:{{ $emailAddress->email_address }}">{{ $emailAddress->email_address }}</a>
                            </span>
                        @endforeach
                    </td>
                    <td>{{ $user->is_admin ? 'Yes' : 'No' }}</td>
                    <td>{{ $user->is_enabled ? 'Yes' : 'No' }}</td>
                    <td>{{ $user->created_at->format('Y M d H:i') }}<span
                            class="opacity-50">{{ $user->created_at->format(':s e') }}</span></td>
                    <td>
                        <form method="post" action="/user/{{ $user->id }}"
                            onSubmit="return confirm('Really delete '+{{ json_encode($user->name) }}+'?')">@csrf
                            @method('DELETE')<button type="submit">Delete</button></form>
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>
@endsection
