@props(['label', 'name', 'value'])

<label>
    {{ $label }}<br>
    <input name="{{ $name }}" @if ($value !== null) value="{{ old($name, $value) }}" @endif
        maxlength="255" {{ $attributes }} />
</label>
