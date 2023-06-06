<?php

namespace Web;

use DB;

class User {
    static function view(): never {
        $user = DB::queryFirstRow('SELECT * FROM users WHERE id = %s', REQUEST_PAYLOAD['id'] ?? abort(400));

        if (!$user) abort(404);

        $emailAddresses = DB::query('SELECT * FROM email_addresses WHERE user_id = %s', REQUEST_PAYLOAD['id']);

        view('user', compact('user', 'emailAddresses'));
        exit;
    }
}
