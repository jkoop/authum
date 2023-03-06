@extends('layouts.main')
@section('title', __('Service: :serviceName', ['serviceName' => $service->name]))
@section('content')

    <h2>{{ __('General') }}</h2>

    <form method="post" action="/service/{{ $service->id }}">
        @csrf
        <x-string-input :label="__('Name')" name="name" :value="$service->name" required /><br>
        <button type="submit">{{ __('Save') }}</button>
    </form>

    <h2>{{ __('Domain names') }}</h2>

    @if ($service->domainNames->count() > 0)
        <table>
            <tbody>
                @foreach ($service->domainNames->sortBy('sortValue') as $domainName)
                    <tr>
                        <td>{{ $domainName->domain_name }}</td>
                        <td>
                            <form method="post" action="/domain-name/{{ $domainName->domain_name }}"
                                onSubmit="return confirm({{ json_encode(
                                    __('Really delete :domainName from :serviceName?', [
                                        'domainName' => $domainName->domain_name,
                                        'serviceName' => $service->name,
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
        <i>{{ __(":serviceName doesn't have any domain names", ['serviceName' => $service->name]) }}</i>
    @endif

    <form method="post" action="/service/{{ $service->id }}/domain-name">
        @csrf
        <label>
            {{ __('New domain name') }}<br>
            <input name="domain" pattern="^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$"
                required />
        </label><br>
        <button type="submit">{{ __('Add domain name') }}</button>
    </form>

@endsection
