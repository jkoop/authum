<?php

namespace App\Http\Controllers;

use App\Models\Service;
use Illuminate\Http\Request;

class DashboardController extends Controller {
    public function view(Request $request) {
        $services = Service::with('domainNames')->get();

        return view('pages.dashboard', compact('services'));
    }
}
