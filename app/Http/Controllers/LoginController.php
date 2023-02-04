<?php

namespace App\Http\Controllers;

use App\Models\AuthenticationReturnToken;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Hash;

final class LoginController extends Controller {
    public function view(Request $request) {
        $request->validate([
            'from' => 'nullable|url',
        ]);

        return view('pages.login');
    }

    public function login(Request $request) {
        $request->validate([
            'username' => 'required|string|max:255',
            'password' => 'required',
            'from' => 'nullable|url',
        ]);

        $user = User::where('username', $request->username)->orWhereHas('emailAddresses', function ($query) use ($request) {
            $query->where('email_address', $request->username);
        })->first();

        if ($user === null || !Hash::check($request->password, $user->password)) {
            return back()->withErrors(["These credentials do not match our records."]);
        }

        Auth::login($user);

        if ($request->has('from')) {
            $authorizationReturnToken = AuthenticationReturnToken::create([
                'user_id' => $user->id,
                'forward_to' => substr($request->from, 0, 4095),
            ]);

            $url = parse_url($request->from);
            $goto = $url['scheme'] . '://' . $url['host'] . ':' . $url['port'] . '/_authum/from-login?' . http_build_query([
                'token' => Crypt::encryptString($authorizationReturnToken->id),
            ]);

            return redirect($goto);
        } else {
            return redirect("/");
        }
    }

    public function logout(Request $request) {
        Auth::logout();
        return redirect("/login");
    }
}
