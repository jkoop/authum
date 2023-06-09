<?php

namespace Web;

use Checks;
use DB;

class ForwardAuth {
    static function handle(): never {
        try {
            $domainName = explode(':', $_SERVER['HTTP_X_FORWARDED_HOST'])[0];
            $path = ltrim(explode('?', $_SERVER['HTTP_X_FORWARDED_URI'])[0], '/');
        } catch (\Exception $e) {
            abort(422);
        }

        if ($path == '_authum_login') {
            $_GET = [];
            parse_str(explode('?', $_SERVER['HTTP_X_FORWARDED_URI'])[1], $_GET);
            $token = $_GET['token'] ?? '';
            if (DB::queryFirstField('SELECT EXISTS(SELECT * FROM `sessions` WHERE `id` = %s)', $token)) {
                setcookie("authum_session", $token, strtotime('+1 hour'), domain: $domainName);
                redirect("//$domainName/" . ltrim($_GET['goto'] ?? '', '/'));
            } else {
                abort(403, 'bad token');
            }
        }

        if (!Checks::isLoggedIn()) {
            redirect(
                rtrim($_ENV['APP_URL'], '/') .
                    '/login?' .
                    http_build_query([
                        'from' => $_SERVER['HTTP_X_FORWARDED_HOST'] . '/' . ltrim($_SERVER['HTTP_X_FORWARDED_URI'], '/')
                    ])
            );
        }

        // logout
        if ($path == DB::queryFirstField('SELECT `logout_path` FROM `services` INNER JOIN `domain_names` ON `domain_names`.`service_id` = `services`.`id` WHERE `domain_name` = %s', $domainName)) {
            Login::doLogout();
        }

        $aclResult = DB::queryFirstField(
            <<<SQL
                SELECT if_matches
                FROM acl
                    LEFT OUTER JOIN service_service_group ON service_service_group.service_group_id = acl.service_group_id
                    LEFT OUTER JOIN user_user_group ON user_user_group.user_group_id = acl.user_group_id
                WHERE
                    (acl.service_id IS NULL OR acl.service_id = %i) AND (acl.service_group_id IS NULL OR service_service_group.service_id = %i)
                    AND (acl.user_id IS NULL OR acl.user_id = %i) AND (acl.user_group_id IS NULL OR user_user_group.user_id = %i)
                    AND (acl.domain_name_regex IS NULL OR %s REGEXP acl.domain_name_regex)
                    AND (acl.path_regex IS NULL OR %s REGEXP acl.path_regex)
                ORDER BY `order` ASC
            SQL,
            loggedInUser()['id'],
            loggedInUser()['id'],
            loggedInUser()['id'],
            loggedInUser()['id'],
            $domainName,
            $path,
        ) ?? 'fail';

        if ($aclResult == 'fail') {
            abort(403);
        } else {
            exit();
        }
    }
}
