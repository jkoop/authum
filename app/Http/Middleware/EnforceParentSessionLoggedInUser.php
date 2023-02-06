<?php

namespace App\Http\Middleware;

use App\Models\Session as ModelsSession;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class EnforceParentSessionLoggedInUser {
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure(\Illuminate\Http\Request): (\Illuminate\Http\Response|\Illuminate\Http\RedirectResponse)  $next
     * @return \Illuminate\Http\Response|\Illuminate\Http\RedirectResponse
     */
    public function handle(Request $request, Closure $next) {
        if (
            session()->has('parentSessionId') &&
            $parentSession = ModelsSession::find(session('parentSessionId'))
        ) {
            if ($parentSession?->user_id && Auth::id() != $parentSession->user_id) {
                Auth::login($parentSession->user);
            } else {
                Auth::logout();
            }
        }

        return $next($request);
    }
}
