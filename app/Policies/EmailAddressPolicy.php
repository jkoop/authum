<?php

namespace App\Policies;

use App\Models\EmailAddress;
use App\Models\User;
use Illuminate\Auth\Access\HandlesAuthorization;

class EmailAddressPolicy {
    use HandlesAuthorization;

    public function delete(User $user, EmailAddress $emailAddress): bool {
        if ($user->emailAddresses->count() < 2) return false;
        return $user->emailAddresses->contains($emailAddress);
    }
}
