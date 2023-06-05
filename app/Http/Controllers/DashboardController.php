<?php

namespace App\Http\Controllers;

use App\Models\Service;
use Illuminate\Support\Collection;

class DashboardController extends Controller {
    public function view() {
        $services = Service::with('domainNames')->get();
        return view('pages.dashboard', compact('services'));
    }

    public function viewFake() {
        $services = new Collection();

        for ($i = rand(0, 2); $i < 6; $i++) {
            $name = "";

            for ($j = rand(0, 7); $j < 10; $j++) {
                $name .= chr(rand(97, 122));
            }

            $name .= " ";

            for ($j = rand(2, 5); $j < 10; $j++) {
                $name .= chr(rand(97, 122));
            }

            $services[] = new Service(compact('name'));
        }

        return response(
            view('pages.dashboard', compact('services')),
            headers: [
                'Cache-Control' => 'public, max-age=86400', // 1 day
                'Expires' => now()->addDay()->format('r'),
            ]
        );
    }
}
