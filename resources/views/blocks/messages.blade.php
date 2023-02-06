@if ($errors->count())
    @foreach ($errors->all() as $error)
        <p style="padding: 0.5rem; background-color: #f004; border: 2px solid #f00">
            {{ $error }}
        </p>
    @endforeach
@endif
