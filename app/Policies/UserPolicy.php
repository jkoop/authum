<?php

namespace App\Policies;

use App\Models\User;
use Illuminate\Auth\Access\HandlesAuthorization;

class UserPolicy {
    use HandlesAuthorization;

    public function list(User $user): bool {
        if ($user->is_admin) return true;
        return false;
    }
}
