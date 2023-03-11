<?php

namespace App\Http\Controllers;

use App\Mail\PasswordReset;
use App\Models\PasswordResetToken;
use App\Models\User;
use App\Rules\EmailAllowed;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Redirect;

class PasswordResetController extends Controller {
    public function submitEmailForm(Request $request) {
        $request->validate([
            'email' => ['required', 'email', 'max:255', new EmailAllowed],
        ]);

        $user = User::whereHas('emailAddresses', function ($query) use ($request) {
            $query->where('email_address', $request->email);
        })->first();

        if ($user === null) {
            return back()->withErrors([__("These credentials do not match our records")]);
        }

        Mail::to($request->email)->send(new PasswordReset($user));

        return Redirect::to('/login')->with('successes', [__("We sent you an email with a password reset link")]);
    }

    public function viewResetForm(string $token) {
        PasswordResetToken::where('expires_at', '<', now()->timestamp)->delete();

        $token = PasswordResetToken::find($token);
        if (!$token) {
            return response(view('pages.token.bad'), 400);
        }

        return view('pages.password.reset', [
            'user' => $token->user,
        ]);
    }

    public function submitResetForm(string $token, Request $request) {
        PasswordResetToken::where('expires_at', '<', now()->timestamp)->delete();

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

        return Redirect::to("/")->with('successes', [__("Changed password")]);
    }
}
