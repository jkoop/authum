@extends('layouts.main')
@section('title', 'Services')
@section('content')
    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>Domain Names</th>
                <th>Created At</th>
                <td>
                    <form method="post" action="/service/new">
                        @csrf
                        <button type="submit">Create new service</button>
                    </form>
                </td>
            </tr>
        </thead>
        <tbody>
            @foreach ($services as $service)
                <tr>
                    <td><a href="/service/{{ $service->id }}">{{ $service->name }}</a></td>
                    <td>
                        @foreach ($service->domainNames->sortBy('sortValue') as $domainName)
                            <span class="block">{{ $domainName->domain_name }}</span>
                        @endforeach
                    </td>
                    <td>{{ $service->created_at->format('Y M d H:i') }}<span
                            class="opacity-50">{{ $service->created_at->format(':s e') }}</span></td>
                    <td>
                        <form method="post" action="/service/{{ $service->id }}"
                            onSubmit="return confirm('Really delete '+{{ json_encode($service->name) }}+'?')">@csrf
                            @method('DELETE')<button type="submit">Delete</button></form>
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>
@endsection
