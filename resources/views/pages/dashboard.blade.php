@extends('layouts.main')
@section('title', 'Dashboard')
@section('content')

    <h2>Services</h2>

    @unless($services)
        <i>none</i>
    @endunless

    @foreach ($services as $service)
        <div>
            <a target="_blank" href="{{ $service->entrypoint }}">{{ $service->name }}</a>
        </div>
    @endforeach

@endsection
