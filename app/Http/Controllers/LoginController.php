<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

final class LoginController extends Controller {
    public function view(Request $request) {
        return view('pages.login');
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

        return redirect("/");
    }

    public function logout(Request $request) {
        Auth::logout();
        return redirect("/login");
    }
}
