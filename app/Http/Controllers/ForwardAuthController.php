<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ForwardAuthController extends Controller {
    public function handle(Request $request) {
        abort(400);
        return response("ok");

        if (Auth::check()) {
            return true;
        } else {
            return redirect(config('app.url') . '/login?' . http_build_query([
                'from' =>
                $request->header('x-forwarded-proto') . '://' .
                    $request->header('x-forwarded-host') . ':' .
                    $request->header('x-forwarded-port') . '/' .
                    $request->header('x-forwarded-uri'), // includes query string
            ]));
        }
    }
}
