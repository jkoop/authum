<?php

namespace App\Http\Controllers;

use App\Mail\VerifyEmail;
use App\Models\EmailAddress;
use App\Models\EmailVerifyToken;
use App\Rules\EmailAllowed;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Redirect;

class ProfileController extends Controller {
    public function view() {
        $user = Auth::user();
        $emailAddresses = $user->emailAddresses->sortBy('sortValue');

        return view('pages.profile', compact('user', 'emailAddresses'));
    }

    public function updateGeneral(Request $request) {
        $request->validate([
            'name' => 'required|string|min:2|max:255',
        ]);

        /** @var User $user */
        $user = Auth::user();
        $user->name = $request->name;
        $user->save();

        return back()->with(['successes' => ["Saved"]]);
    }

    public function changePassword(Request $request) {
        $request->validate([
            'current_password' => 'required|string',
            'password' => 'required|string|min:8',
            'password_confirmation' => 'required|string|same:password',
        ]);

        /** @var User $user */
        $user = Auth::user();

        if (!Hash::check($request->current_password, $user->password)) {
            return back()->withErrors(["These credentials do not match our records."]);
        }

        $user->password = Hash::make($request->password);
        $user->save();

        return Redirect::to('/profile')->with(['successes' => ['Changed password']]);
    }

    public function sendVerifyEmailEmail(Request $request) {
        $request->validate([
            'email' => ['required', 'email', 'unique:email_addresses,email_address', 'max:255', new EmailAllowed],
        ]);

        Mail::to($request->email)->send(new VerifyEmail($request->email, Auth::user()));

        return back()->with(['successes' => ['We sent you an email with an email confirmation link']]);
    }

    public function verifyEmail(string $token) {
        EmailVerifyToken::where('expires_at', '<', now()->timestamp)->delete();

        $token = EmailVerifyToken::find($token);
        if (!$token) {
            return response(view('pages.token.bad'), 400);
        }

        if ($token->user_id != Auth::id()) {
            return Redirect::to('/profile')->withErrors(["You must be logged in as the user who requested the email validation"]);
        }

        if (EmailAddress::where('email_address', $token->email_address)->exists()) {
            return Redirect::to('/profile')->withErrors(['Email address is already taken']);
        }

        EmailAddress::create([
            'user_id' => Auth::id(),
            'email_address' => $token->email_address,
        ]);

        return Redirect::to('/profile')->with('successes', ["Added $token->email_address"]);
    }

    public function deleteEmail(EmailAddress $emailAddress) {
        $emailAddress->delete();
        return back()->with('successes', ["Deleted $emailAddress->email_address"]);
    }
}
