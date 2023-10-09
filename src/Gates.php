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
            redirect('/login?', http_build_query(['from' => REQUEST_PATH . '?' . http_build_query($_GET)]));
        }
    }

    /**
     * @return void|never
     */
    static function notLoggedIn() {
        if (Checks::isLoggedIn()) redirect('/');
    }
}
