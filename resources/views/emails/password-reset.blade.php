<p>Hi {{ $user->name }},</p>

<p>You requested a link to reset your password. <a href="{{ $url }}">Here you go!</a> (it expires in ten
    minutes)</p>

<address>&mdash; {{ config('app.name') }}</address>
