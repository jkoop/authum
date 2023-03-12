@extends('layouts.main')
@section('title', 'Email Permissions')
@section('content')
    <p>
        Whenever an email is to be sent, its destination email address is compared against these permissions in order from
        top to bottom. The first permission whose <a href="https://regex101.com" target="_blank">regex</a> matches the email
        address dictates whether the email is sent (pass) or not
        (fail).
    </p>

    @vite(['resources/js/email-permissions.js'])

    <form method="post" action="/email-permissions">
        @csrf

        <table>
            <thead>
                <tr>
                    <th>Regex</th>
                    <th>If Matches</th>
                    <th>Comment</th>
                    <td><button type="button" onClick="create()">Create new permission</button></td>
                </tr>
            </thead>
            <tbody id="permissions">
                @foreach ($emailPermissions as $permission)
                    <tr id="{{ $permission->id }}">
                        <td>
                            <input name="{{ $permission->id }}[regex]" type="text" maxLength="255"
                                value="{{ $permission->regex }}" required />
                        </td>
                        <td><select name="{{ $permission->id }}[if_matches]">
                                <option>pass</option>
                                <option>fail</option>
                            </select></td>
                        <td><input name="{{ $permission->id }}[comment]" type="text" maxLength="255"
                                value="{{ $permission->comment }}" /></td>
                        <td>
                            <button type="button" onClick="moveUp(this)">Up</button>
                            <button type="button" onClick="moveDown(this)">Down</button>
                            <button type="button" onClick="deleteRow(this)">Delete</button>
                        </td>

                        @if (@preg_match($permission->regex, null) === false)
                            <td class="text-orange-500">This is not valid regex; it will never match</td>
                        @endif
                    </tr>
                @endforeach

                <tr id="fallback">
                    <td><input value="/.*/i" disabled /></td>
                    <td><select disabled>
                            <option>fail</option>
                        </select></td>
                    <td><input value="Forbid every email address" disabled /></td>
                </tr>
            </tbody>
        </table>
        <button type="submit">Save</button>
    </form>
@endsection
