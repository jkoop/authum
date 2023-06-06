<?php

class Checks {
    static function isAdmin(): bool {
        return self::isLoggedIn();
    }

    static function isLoggedIn() {
        return isset($_COOKIE['authum_login']);
    }
}
