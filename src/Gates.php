<?php

class Gates {

    /**
     * @return void|never
     */
    static function admin() {
        self::loggedIn();
        if (!Checks::isAdmin()) abort(403);
    }

    /**
     * @return void|never
     */
    static function loggedIn() {
        if (!Checks::isLoggedIn()) {
            setcookie("authum_session", '', 1, path: '/', httponly: true);
            redirect('/login?' . http_build_query(['from' => config('app.url') . $_SERVER['REQUEST_URI']]));
        }
    }

    /**
     * @return void|never
     */
    static function notLoggedIn() {
        if (Checks::isLoggedIn()) redirect('/');
    }
}
