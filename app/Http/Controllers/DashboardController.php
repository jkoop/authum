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

        return response(
            view('pages.dashboard', compact('services')),
            headers: [
                'Cache-Control' => 'public, max-age=86400', // 1 day
                'Expires' => now()->addDay()->format('r'),
            ]
        );
    }
}
