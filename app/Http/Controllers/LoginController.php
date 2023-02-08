<?php

namespace App\Http\Controllers;

use App\Helpers\Crockford32;
use App\Models\AuthenticationReturnToken;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Session;
use Illuminate\Support\Str;

final class LoginController extends Controller {
    public function view(Request $request) {
        if (Auth::check()) {
            if ($request->has('from')) {
                return $this->redirectWithToken($request);
            } else {
                return redirect('/');
            }
        } else {
            return view('pages.login');
        }
    }

    public function login(Request $request) {
        $request->validate([
            'username' => 'required|string|max:255',
            'password' => 'required',
        ]);

        $user = User::where('username', $request->username)->orWhereHas('emailAddresses', function ($query) use ($request) {
            $query->where('email_address', $request->username);
        })->first();

        if ($user === null || !Hash::check($request->password, $user->password)) {
            return back()->withErrors(["These credentials do not match our records."]);
        }

        Auth::login($user);

        if ($request->has('from')) {
            return $this->redirectWithToken($request);
        } else {
            return redirect("/");
        }
    }

    private function redirectWithToken(Request $request) {
        $request->validate([
            'from' => 'url',
        ]);

        $authorizationReturnToken = AuthenticationReturnToken::create([
            'id' => strtolower(Str::ulid() . Crockford32::encode(random_bytes(10))),
            'parent_session_id' => Session::getId(),
            'forward_to' => substr($request->from, 0, 4095),
            'expires_at' => now()->addMinute()->timestamp, // I actually think one minute might be too long
        ]);

        $url = parse_url($request->from);
        $goto = $url['scheme'] . '://' . $url['host'] . ':' . $url['port'] . '/_authum/from-login?' . http_build_query([
            'token' => $authorizationReturnToken->id,
        ]);

        return redirect($goto);
    }

    public function logout(Request $request) {
        Auth::logout();
        return redirect("/login");
    }
}
