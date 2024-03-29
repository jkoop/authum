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
                $rule['service_id'] = $rule['service'];
            }
            if ($rule['user'] != '') {
                if (getTypeFromId($rule['user']) == 'user') {
                    $rule['user_id'] = $rule['user'];
                } else if (getTypeFromId($rule['user']) == 'group') {
                    $rule['group_id'] = $rule['user'];
                }
            }

            $rule['method_regex'] = substr($rule['method_regex'], 0, 255);
            $rule['path_regex'] = substr($rule['path_regex'], 0, 255);
            $rule['query_string_regex'] = substr($rule['query_string_regex'], 0, 255);
            $rule['comment'] = substr($rule['comment'], 0, 255);
            // dd($rule);

            DB::replace('acl', [
                'order' => $order,
                'service_invert' => $rule['service_invert'],
                'service_id' => $rule['service_id'] ?? null,
                'user_invert' => $rule['user_invert'],
                'user_id' => $rule['user_id'] ?? null,
                'group_id' => $rule['group_id'] ?? null,
                'method_regex_invert' => $rule['method_regex_invert'],
                'method_regex' => $rule['method_regex'] != '' ? $rule['method_regex'] : null,
                'path_regex_invert' => $rule['path_regex_invert'],
                'path_regex' => $rule['path_regex'] != '' ? $rule['path_regex'] : null,
                'query_string_regex_invert' => $rule['query_string_regex_invert'],
                'query_string_regex' => $rule['query_string_regex'] != '' ? $rule['query_string_regex'] : null,
                'if_matches' => $rule['if_matches'],
                'comment' => $rule['comment'],
            ]);
        }

        DB::query('DELETE FROM `acl` WHERE `order` > %i', $order ?? -1);

        DB::query('COMMIT');

        redirect('/acl');
    }
}
