<?php

namespace Web;

class ForwardAuth {
    static function handle(): never {
        dd([
            $_SERVER,
            $_POST,
            $_GET,
            $_COOKIE
        ]);
        redirect('//authum.localhost/login?return_token=9346193761');
    }
}
