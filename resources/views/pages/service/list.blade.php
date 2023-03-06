@extends('layouts.main')
@section('title', __('Services'))
@section('content')
    <form method="post" action="/service/new">
        @csrf
        <button type="submit">{{ __('Create new service') }}</button>
    </form>

    <table>
        <thead>
            <tr>
                <th>{{ __('Name') }}</th>
                <th>{{ __('Domain Names') }}</th>
                <th>{{ __('Created At') }}</th>
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
                            onSubmit="return confirm({{ json_encode(__('Really delete :serviceName', ['serviceName' => $service->name])) }})">
                            @csrf
                            @method('DELETE')<button type="submit">{{ __('Delete') }}</button></form>
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>
@endsection
