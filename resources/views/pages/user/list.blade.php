@extends('layouts.main')
@section('title', 'Users')
@section('content')
    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>Email Addresses</th>
                <th>Is Admin?</th>
                <th>Created At</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($users as $user)
                <tr>
                    <td>{{ $user->name }}</td>
                    <td>
                        @foreach ($user->emailAddresses->sortBy('sortValue') as $emailAddress)
                            <span class="block">
                                <a href="mailto:{{ $emailAddress->email_address }}">{{ $emailAddress->email_address }}</a>
                            </span>
                        @endforeach
                    </td>
                    <td>{{ $user->is_admin ? 'Yes' : 'No' }}</td>
                    <td>{{ $user->created_at->format('Y M d H:i') }}<span
                            class="opacity-50">{{ $user->created_at->format(':s') }}</span></td>
                </tr>
            @endforeach
        </tbody>
    </table>
@endsection
