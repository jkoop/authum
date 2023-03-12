<?php

namespace App\Http\Controllers;

use App\Models\EmailPermission;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Redirect;
use Illuminate\Support\Str;

class EmailPermissionsController extends Controller {
    public function list() {
        $emailPermissions = EmailPermission::orderBy('order')->get();
        return view('pages.email-permission.list', compact('emailPermissions'));
    }

    public function update(Request $request) {
        $order = 0;
        $permissions = [];

        foreach ($request->all() as $key => $permission) {
            if (!str_starts_with($key, 'new') && !Str::isUlid($key)) continue;
            if (str_starts_with($key, 'new')) $key = Str::ulid();

            $permissions[] = [
                'id' => $key,
                'order' => $order,
                'regex' => $permission['regex'],
                'comment' => $permission['comment'],
            ];

            $order++;
        }

        EmailPermission::upsert($permissions, ['id'], ['order', 'regex', 'comment']);
        EmailPermission::whereNotIn('id', array_column($permissions, 'id'))->delete();
        return Redirect::to('/email-permissions')->with(['successes' => ["Saved"]]);
    }
}
