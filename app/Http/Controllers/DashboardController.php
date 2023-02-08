<?php

namespace App\Http\Controllers;

use App\Models\Service;

class DashboardController extends Controller {
    public function view() {
        $services = Service::with('domainNames')->get();

        return view('pages.dashboard', compact('services'));
    }

    public function viewFake() {
        $services = Service::factory(rand(4, 6))->make(); // create() would save them

        return view('pages.dashboard', compact('services'));
    }
}
