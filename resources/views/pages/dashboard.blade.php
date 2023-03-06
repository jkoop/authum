@extends('layouts.main')
@section('title', __('Dashboard'))
@section('content')

    <h2>{{ __('Services') }}</h2>

    @if ($services)
        <div class="flex flex-wrap gap-2">
            @foreach ($services as $service)
                <a target="_blank" href="{{ $service->entrypoint }}" class="hover:no-underline">
                    <div class="w-48 h-12 p-1 bg-slate-100 text-black hover:bg-slate-300">{{ $service->name }}
                    </div>
                </a>
            @endforeach
        </div>
    @else
        <i>{{ __('none') }}</i>
    @endif

@endsection
