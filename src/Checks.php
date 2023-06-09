<?php

class Checks {
    static function isAdmin(): bool {
        return loggedInUser()['is_admin'] ?? false;
    }

    static function isLoggedIn() {
        return !empty(loggedInUser());
    }
}
