<?php

namespace Web;

use DB;

class Service {
    static function view(): never {
        $service = DB::queryFirstRow('SELECT * FROM services WHERE id = %s', $_GET['id'] ?? abort(400, 'The query parameter "id" is required'));
        if (!$service) abort(404);

        view('service', compact('service'));
        exit;
    }
}
