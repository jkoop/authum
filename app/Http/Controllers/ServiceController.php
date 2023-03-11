<?php

namespace App\Http\Controllers;

use App\Models\DomainName;
use App\Models\Service;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Session;

class ServiceController extends Controller {
    public function list() {
        $services = Service::orderBy('name')->with('domainNames')->get();
        return view('pages.service.list', compact('services'));
    }

    public function view(Service $service) {
        if ($service->domainNames->count() < 1) {
            Session::push('warnings', "$service->name doesn't have any domain names");
        }
        return view('pages.service.view', compact('service'));
    }

    public function create() {
        $service = Service::create([
            'name' => 'NEW_SERVICE',
        ]);
        return redirect("/service/$service->id");
    }

    public function update(Service $service, Request $request) {
        $request->validate([
            'name' => 'required|string|max:255',
        ]);

        $service->name = $request->name;
        $service->save();

        return back()->with('successes', ["Saved"]);
    }

    public function delete(Service $service) {
        $service->delete();
        return back()->with('successes', ["Deleted $service->name"]);
    }

    public function addDomainName(Service $service, Request $request) {
        $request->validate([
            'domain' => 'required|unique:domain_names,domain_name|regex:/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$/mi',
        ]);

        DomainName::create([
            'domain_name' => $request->domain,
            'service_id' => $service->id,
        ]);

        return back()->with('successes', ["Added $request->domain to $service->name"]);
    }

    public function deleteDomainName(DomainName $domainName) {
        $domainName->delete();
        return back()->with('successes', ["Deleted $domainName->domain_name"]);
    }
}
