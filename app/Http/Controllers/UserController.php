<?php

namespace App\Http\Controllers;

use App\Models\User;

class UserController extends Controller {
    public function list() {
        $users = User::orderBy('name')->with('emailAddresses')->get();
        return view('pages.user.list', compact('users'));
    }
}
