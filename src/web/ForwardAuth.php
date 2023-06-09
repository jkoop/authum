<?php

namespace Web;

use DB;

class ForwardAuth {
    static function handle(): never {
        if (loggedInUser() === null) abort(401);

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
            explode(':', $_SERVER['HTTP_X_FORWARDED_HOST'])[0],
            explode('?', $_SERVER['HTTP_X_FORWARDED_URI'])[0],
        ) ?? 'fail';

        if ($aclResult == 'fail') {
            abort(403, '(logged in as ' . loggedInUser()['name'] . ')');
        } else {
            exit();
        }
    }
}
