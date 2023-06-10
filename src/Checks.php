<?php

class Checks {
    static function isAdmin(): bool {
        return loggedInUser()['is_admin'] ?? false;
    }

    static function isLoggedIn() {
        return !empty(loggedInUser());
    }

    static function getRegexErrors(string $regex): ?string {
        try {
            DB::query('SELECT `name` FROM migrations WHERE `name` REGEXP %s LIMIT 1', $regex);
            return null;
        } catch (mysqli_sql_exception $e) {
            if (str_contains($e->getMessage(), 'Regex error')) {
                return $e->getMessage();
            }

            throw $e;
        }
    }
}
