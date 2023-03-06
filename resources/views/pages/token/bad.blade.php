@extends('layouts.card')
@section('title', __('Invalid Token'))
@section('content')

    <p>{{ __("Token expired or doesn't exist") }}</p>
    <p><a href="/">{{ __('Log in') }}</a></p>

@endsection
