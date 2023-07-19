<?php

namespace Web;

use DB;

class Home {
    static function view(): never {
        $services = DB::query(<<<SQL
            SELECT DISTINCT `id`, `name`, `domain_name`
            FROM `services`
            ORDER BY `name`
        SQL);

        $services = array_filter($services, function ($service): bool {
            return ForwardAuth::doesAclAllow(
                serviceId: $service['id'],
                userId: loggedInUser()['id'],
                method: 'GET',
                path: '', // '/'
                queryString: '',
            );
        });

        view('home', compact('services'));
        exit;
    }
}
