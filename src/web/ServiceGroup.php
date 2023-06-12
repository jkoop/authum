<?php

namespace Web;

use DB;

class ServiceGroup {
    static function view(): never {
        $serviceGroup = DB::queryFirstRow('SELECT * FROM service_groups WHERE id = %s', $_GET['id'] ?? abort(400));

        if (!$serviceGroup) abort(404);

        $services = DB::query('SELECT * FROM services INNER JOIN service_service_group ON services.id = service_service_group.service_id WHERE service_group_id = %s', $_GET['id']);

        view('service-group', compact('serviceGroup', 'services'));
        exit;
    }
}
