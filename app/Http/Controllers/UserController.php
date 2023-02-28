<?php

namespace App\Http\Controllers;

use App\Models\EmailAddress;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller {
    public function list() {
        $users = User::orderBy('name')->with('emailAddresses')->get();
        return view('pages.user.list', compact('users'));
    }

    public function view(User $user) {
        return view('pages.user.view', compact('user'));
    }

    public function create() {
        $user = User::create([
            'name' => 'NEW_USER',
        ]);
        return redirect("/user/$user->id");
    }

    public function update(User $user, Request $request) {
        $request->validate([
            'name' => 'required|string|max:255',
            // 'is_admin' => 'checkbox',
            // 'is_enabled' => 'checkbox',
        ]);

        $user->name = $request->name;
        $user->is_admin = $request->has('is_admin');
        $user->is_enabled = $request->has('is_enabled');

        $user->save();

        return back();
    }

    public function changePassword(User $user, Request $request) {
        $request->validate([
            'password' => 'required|string|min:8',
        ]);

        $user->password = Hash::make($request->password);
        $user->save();

        return back()->with(['success' => 'Successfully changed password']);
    }

    public function addEmailAddress(User $user, Request $request) {
        $request->validate([
            'email' => 'required|email|unique:email_addresses,email_address',
        ]);

        EmailAddress::create([
            'email_address' => $request->email,
            'user_id' => $user->id,
        ]);

        return back()->with(['success' => 'Successfully added email address.']);
    }
}
