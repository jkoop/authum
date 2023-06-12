<?php

namespace Web;

use Checks;
use DB;

class Acl {
    static function update(): never {
        Checks::getRegexErrors('(');

        DB::query('START TRANSACTION');

        foreach ($_POST as $order => $rule) {
            if ($rule['service'] != '') {
                if (getTypeFromId($rule['service']) == 'service') {
                    $rule['service_id'] = $rule['service'];
                } else if (getTypeFromId($rule['service']) == 'service_group') {
                    $rule['service_group_id'] = $rule['service'];
                }
            }
            if ($rule['user'] != '') {
                if (getTypeFromId($rule['user']) == 'user') {
                    $rule['user_id'] = $rule['user'];
                } else if (getTypeFromId($rule['user']) == 'user_group') {
                    $rule['user_group_id'] = $rule['user'];
                }
            }

            $rule['method_regex'] = substr($rule['method_regex'], 0, 255);
            $rule['domain_name_regex'] = substr($rule['domain_name_regex'], 0, 255);
            $rule['path_regex'] = substr($rule['path_regex'], 0, 255);
            $rule['query_string_regex'] = substr($rule['query_string_regex'], 0, 255);
            $rule['comment'] = substr($rule['comment'], 0, 255);
            // dd($rule);

            DB::replace('acl', [
                'order' => $order,
                'service_invert' => $rule['service_invert'],
                'service_id' => $rule['service_id'] ?? null,
                'service_group_id' => $rule['service_group_id'] ?? null,
                'user_invert' => $rule['user_invert'],
                'user_id' => $rule['user_id'] ?? null,
                'user_group_id' => $rule['user_group_id'] ?? null,
                'method_regex' => $rule['method_regex'] != '' ? $rule['method_regex'] : null,
                'path_regex' => $rule['path_regex'] != '' ? $rule['path_regex'] : null,
                'query_string_regex' => $rule['query_string_regex'] != '' ? $rule['query_string_regex'] : null,
                'domain_name_regex' => $rule['domain_name_regex'] != '' ? $rule['domain_name_regex'] : null,
                'if_matches' => $rule['if_matches'],
                'comment' => $rule['comment'],
            ]);
        }

        DB::query('DELETE FROM `acl` WHERE `order` > %i', $order ?? -1);

        DB::query('COMMIT');

        redirect('/acl');
    }
}
