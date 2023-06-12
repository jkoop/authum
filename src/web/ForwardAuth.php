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
                setcookie("authum_session", $token, time() + config('session.timeout'), domain: $domainName, httponly: true);
                redirect("//$domainName/" . ltrim($_GET['goto'] ?? '', '/'));
            } else {
                abort(403, 'bad token');
            }
        }

        if (!Checks::isLoggedIn()) {
            redirect(
                config('app.url') .
                    '/login?' .
                    http_build_query([
                        'from' => $_SERVER['HTTP_X_FORWARDED_HOST'] . '/' . ltrim($_SERVER['HTTP_X_FORWARDED_URI'], '/')
                    ])
            );
        }

        $service = DB::queryFirstRow('SELECT `id`, `logout_path` FROM `services` INNER JOIN `domain_names` ON `domain_names`.`service_id` = `services`.`id` WHERE `domain_name` = %s', $domainName);

        // logout
        if ($path == $service['logout_path']) {
            Login::doLogout();
        }

        $aclResult = DB::queryFirstField(
            <<<SQL
                SELECT if_matches
                FROM acl
                    LEFT OUTER JOIN service_service_group ON service_service_group.service_group_id = acl.service_group_id
                    LEFT OUTER JOIN user_user_group ON user_user_group.user_group_id = acl.user_group_id
                WHERE
                    service_invert != ((acl.service_id IS NULL OR acl.service_id = %s) AND (acl.service_group_id IS NULL OR service_service_group.service_id = %s))
                    AND user_invert != ((acl.user_id IS NULL OR acl.user_id = %s) AND (acl.user_group_id IS NULL OR user_user_group.user_id = %s))
                    AND (acl.method_regex IS NULL OR %s REGEXP acl.method_regex)
                    AND (acl.domain_name_regex IS NULL OR %s REGEXP acl.domain_name_regex)
                    AND (acl.path_regex IS NULL OR %s REGEXP acl.path_regex)
                    AND (acl.query_string_regex IS NULL OR %s REGEXP acl.query_string_regex)
                ORDER BY `order` ASC
            SQL,
            $service['id'],
            $service['id'],
            loggedInUser()['id'],
            loggedInUser()['id'],
            $method,
            $domainName,
            $path,
            $queryString,
        );

        if ($aclResult == 'allow') {
            exit();
        } else {
            abort(403);
        }
    }
}
