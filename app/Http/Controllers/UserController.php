<?php

namespace App\Http\Controllers;

use App\Models\EmailAddress;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Session;

class UserController extends Controller {
    public function list() {
        $users = User::orderBy('name')->with('emailAddresses')->get();
        return view('pages.user.list', compact('users'));
    }

    public function view(User $user) {
        if ($user->password == null) Session::push('warnings', "$user->name doesn't have a password");
        if ($user->emailAddresses->count() < 1) Session::push('warnings', "$user->name doesn't have any email addresses");
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

        return back()->with('successes', [__("Saved")]);
    }

    public function delete(User $user) {
        $user->delete();
        return back()->with('successes', ["Deleted $user->name"]);
    }

    public function changePassword(User $user, Request $request) {
        $request->validate([
            'password' => 'required|string|min:8',
        ]);

        $user->password = Hash::make($request->password);
        $user->save();

        return back()->with('successes', ['Changed password']);
    }

    public function addEmailAddress(User $user, Request $request) {
        $request->validate([
            'email' => 'required|email|unique:email_addresses,email_address',
        ]);

        EmailAddress::create([
            'email_address' => $request->email,
            'user_id' => $user->id,
        ]);

        return back()->with('successes', ["Added $request->email to $user->name"]);
    }
}