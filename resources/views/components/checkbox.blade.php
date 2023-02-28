@props(['label', 'name', 'checked'])

<label>
    <input type="checkbox" name="{{ $name }}" @checked(old($name) !== null || (count(old()) < 1 && $checked)) />
    {{ $label }}
</label>
