<?php

namespace Web;

use DB;

class Service {
    static function view(): never {
        $service = DB::queryFirstRow('SELECT * FROM services WHERE id = %s', $_GET['id'] ?? abort(400));

        if (!$service) abort(404);

        $domainNames = DB::query('SELECT * FROM domain_names WHERE service_id = %s', $_GET['id']);

        view('service', compact('service', 'domainNames'));
        exit;
    }
}
