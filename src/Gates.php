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
            $_SESSION['intended'] = REQUEST_PATH . '?' . http_build_query($_GET);
            setcookie("authum_session", '', 0);
            redirect('/login');
        }
    }

    /**
     * @return void|never
     */
    static function notLoggedIn() {
        if (Checks::isLoggedIn()) redirect('/');
    }
}
