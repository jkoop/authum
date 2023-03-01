@if ($errors->count())
    @foreach ($errors->all() as $error)
        <p style="padding: 0.5rem; background-color: #f004; border: 2px solid #f00">
            {{ $error }}
        </p>
    @endforeach
@endif

@if (session()->has('successes'))
    @foreach (session('successes') as $success)
        <p style="padding: 0.5rem; background-color: #0f04; border: 2px solid #0f0">
            {{ $success }}
        </p>
    @endforeach

    @php(session()->forget('successes'))
@endif

@if (session()->has('warnings'))
    @foreach (session('warnings') as $warning)
        <p style="padding: 0.5rem; background-color: #fc04; border: 2px solid #fc0">
            {{ $warning }}
        </p>
    @endforeach

    @php(session()->forget('warnings'))
@endif
