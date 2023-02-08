@if ($errors->count())
    @foreach ($errors->all() as $error)
        <p style="padding: 0.5rem; background-color: #f004; border: 2px solid #f00">
            {{ $error }}
        </p>
    @endforeach
@endif

@if (session()->has('success'))
    <p style="padding: 0.5rem; background-color: #0f04; border: 2px solid #0f0">
        {{ session('success') }}
    </p>

    @php(session()->forget('success'))
@endif
