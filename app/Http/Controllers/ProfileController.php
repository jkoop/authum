<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class ProfileController extends Controller {
    public function view() {
        return view('pages.profile', [
            'user' => Auth::user(),
            'emailAddresses' => Auth::user()->emailAddresses->sortBy(function ($emailAddresses) {
                $address = explode('@', $emailAddresses->email_address);
                $address = array_reverse($address);
                $address = array_map(function ($thing) {
                    $thing = explode('.', $thing);
                    $thing = array_reverse($thing);
                    return implode('.', $thing);
                }, $address);
                return implode('@', $address);
            }),
        ]);
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
}
