<?php

namespace App\Http\Controllers;

use App\Mail\PasswordReset;
use App\Models\PasswordResetToken;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;

class PasswordResetController extends Controller {
    public function submitEmailForm(Request $request) {
        $request->validate([
            'email' => 'required|email|max:255',
        ]);

        $user = User::whereHas('emailAddresses', function ($query) use ($request) {
            $query->where('email_address', $request->email);
        })->first();

        if ($user === null) {
            return back()->withErrors(["These credentials do not match our records."]);
        }

        Mail::to($request->email)->send(new PasswordReset($user));

        session()->put('success', "We sent you an email with a password reset link.");
        return redirect('/login');
    }

    public function viewResetForm(string $token) {
        PasswordResetToken::where('updated_at', '<', now()->timestamp - 60 * 10)->delete();

        $token = PasswordResetToken::find($token);
        if (!$token) {
            return response(view('pages.token.bad'), 400);
        }

        return view('pages.password.reset', [
            'user' => $token->user,
        ]);
    }

    public function submitResetForm(string $token, Request $request) {
        PasswordResetToken::where('updated_at', '<', now()->timestamp - 60 * 10)->delete();

        $token = PasswordResetToken::find($token);
        if (!$token) {
            return response(view('pages.token.bad'), 400);
        }

        $request->validate([
            'password' => 'required|string|min:8',
            'password_confirmation' => 'required|same:password',
        ]);

        $user = $token->user;
        $user->update(['password' => Hash::make($request->password)]);

        $token->delete();

        session()->put('success', "Successfully reset your password.");
        return redirect("/");
    }
}
