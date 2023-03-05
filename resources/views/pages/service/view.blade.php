@extends('layouts.main')
@section('title', "Service: $service->name")
@section('content')

    <h2>General</h2>

    <form method="post" action="/service/{{ $service->id }}">
        @csrf
        <x-string-input label="Name" name="name" :value="$service->name" required /><br>
        <button type="submit">Save</button>
    </form>

    <h2>Domain names</h2>

    @if ($service->domainNames->count() > 0)
        <table>
            <tbody>
                @foreach ($service->domainNames->sortBy('sortValue') as $domainName)
                    <tr>
                        <td>{{ $domainName->domain_name }}</td>
                        <td>
                            <form method="post" action="/domain-name/{{ $domainName->domain_name }}"
                                onSubmit="return confirm('Really delete ' + {{ json_encode($domainName->domain_name) }} + ' from ' + {{ json_encode($service->name) }} + '?')">
                                @csrf @method('DELETE')
                                <button type="submit">Delete</button>
                            </form>
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    @else
        <i>{{ $service->name }} doesn't have any domain names</i>
    @endif

    <form method="post" action="/service/{{ $service->id }}/domain-name">
        @csrf
        <label>
            New domain name<br>
            <input name="domain" pattern="^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$"
                required />
        </label><br>
        <button type="submit">Add domain name</button>
    </form>

@endsection
