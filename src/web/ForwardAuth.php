<?php

namespace Web;

use Checks;
use DB;

class ForwardAuth {
    static function handle(): never {
        try {
            $method = strtoupper($_SERVER['HTTP_X_FORWARDED_METHOD']);
            $domainName = explode(':', $_SERVER['HTTP_X_FORWARDED_HOST'])[0];
            $path = ltrim(explode('?', $_SERVER['HTTP_X_FORWARDED_URI'])[0], '/');
            $queryString = explode('?', $_SERVER['HTTP_X_FORWARDED_URI'])[1] ?? '';

            if ($method == 'HEAD') $method = 'GET';
        } catch (\Exception $e) {
            abort(422);
        }

        if ($path == '_authum_login') {
            $_GET = [];
            parse_str(explode('?', $_SERVER['HTTP_X_FORWARDED_URI'])[1], $_GET);
            $token = $_GET['token'] ?? '';
            if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM `sessions` WHERE `id` = %s)', $token)) {
                setcookie("authum_session", $token, time() + config('session.timeout'), path: '/', domain: $domainName, httponly: true);
                setcookie("authum_session", $token, time() + config('session.timeout'), path: '/', domain: '.' . $domainName, httponly: true);
                redirect("//$domainName/" . ltrim($_GET['goto'] ?? '', '/'));
            } else {
                abort(403, 'bad token');
            }
        }

        if (!Checks::isLoggedIn()) {
            if (str_contains($_SERVER['HTTP_USER_AGENT'] ?? '', 'Mozilla/5.0')) { // web browser
                redirect(
                    config('app.url') .
                        '/login?' .
                        http_build_query([
                            'from' => $_SERVER['HTTP_X_FORWARDED_HOST'] . '/' . ltrim($_SERVER['HTTP_X_FORWARDED_URI'], '/')
                        ])
                );
            } else { // curl or a file browser trying to get WebDAV
                header('WWW-Authenticate: Basic realm="' . parse_url(config('app.url'), PHP_URL_HOST) . '"');
                abort(401);
            }
        }

        $service = DB::queryFirstRow('SELECT `id`, `logout_path` FROM `services` WHERE `domain_name` = %s', $domainName);

        // logout
        if ($path == $service['logout_path']) {
            Login::doLogout();
        }

        if (self::doesAclAllow($service['id'], loggedInUser()['id'], $method, $path, $queryString)) {
            exit();
        } else {
            abort(403);
        }
    }

    public static function doesAclAllow(string $serviceId, string $userId, string $method, string $path, string $queryString): bool {
        return DB::queryFirstField(
            <<<SQL
                SELECT if_matches
                FROM acl
                    LEFT OUTER JOIN group_user ON group_user.group_id = acl.group_id
                WHERE
                    service_invert != (acl.service_id IS NULL OR acl.service_id = %s)
                    AND user_invert != ((acl.user_id IS NULL OR acl.user_id = %s) AND (acl.group_id IS NULL OR group_user.user_id = %s))
                    AND method_regex_invert != ((acl.method_regex IS NULL OR %s REGEXP acl.method_regex))
                    AND path_regex_invert != ((acl.path_regex IS NULL OR %s REGEXP acl.path_regex))
                    AND query_string_regex_invert != ((acl.query_string_regex IS NULL OR %s REGEXP acl.query_string_regex))
                ORDER BY `order` ASC
            SQL,
            $serviceId,
            $userId,
            $userId,
            strtoupper($method),
            $path,
            $queryString,
        ) == 'allow';
    }
}
