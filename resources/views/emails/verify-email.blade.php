<p>Hi {{ $user->name }},</p>

<p>Please verify your email address by following <a href="{{ $url }}">this link</a>. (it expires in ten
    minutes)</p>

<address>&mdash; {{ config('app.name') }}</address>
