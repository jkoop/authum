<?php

namespace App\Http\Controllers;

use App\Mail\VerifyEmail;
use App\Models\EmailAddress;
use App\Models\EmailVerifyToken;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;

class ProfileController extends Controller {
    public function view() {
        $user = Auth::user();
        $emailAddresses = $user->emailAddresses->sortBy(function ($emailAddresses) {
            $address = explode('@', $emailAddresses->email_address);
            $address = array_reverse($address);
            $address = array_map(function ($thing) {
                $thing = explode('.', $thing);
                $thing = array_reverse($thing);
                return implode('.', $thing);
            }, $address);
            return implode('@', $address);
        });

        return view('pages.profile', compact('user', 'emailAddresses'));
    }

    public function updateGeneral(Request $request) {
        $request->validate([
            'name' => 'required|string|min:2|max:255',
        ]);

        $user = Auth::user();
        $user->name = $request->name;
        $user->save();

        return back();
    }

    public function changePassword(Request $request) {
        $request->validate([
            'current_password' => 'required|string',
            'password' => 'required|string|min:8',
            'password_confirmation' => 'required|string|same:password',
        ]);

        $user = Auth::user();

        if (!Hash::check($request->current_password, $user->password)) {
            return back()->withErrors(["These credentials do not match our records."]);
        }

        $user->password = Hash::make($request->password);
        $user->save();

        return redirect('/profile')->with(['success' => 'Successfully changed password']);
    }

    public function sendVerifyEmailEmail(Request $request) {
        $request->validate([
            'email' => 'required|email|unique:email_addresses,email_address',
        ]);

        Mail::to($request->email)->send(new VerifyEmail($request->email, Auth::user()));

        return back()->with(['success' => 'We sent you an email with a email confirmation link.']);
    }

    public function verifyEmail(string $token) {
        EmailVerifyToken::where('expires_at', '<', now()->timestamp)->delete();

        $token = EmailVerifyToken::find($token);
        if (!$token) {
            return response(view('pages.token.bad'), 400);
        }

        if ($token->user_id != Auth::id()) {
            return redirect('/profile')->withErrors(["You aren't logged in as the user who requested the email validation."]);
        }

        if (EmailAddress::where('email_address', $token->email_address)->exists()) {
            return redirect('/profile')->withErrors(['Email address is already taken.']);
        }

        EmailAddress::create([
            'user_id' => Auth::id(),
            'email_address' => $token->email_address,
        ]);

        return redirect('/profile')->with(['success' => 'Successfully added email address.']);
    }
}
