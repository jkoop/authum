<?php

namespace App\Rules;

use App\Models\EmailPermission;
use Illuminate\Contracts\Validation\Rule;
use Illuminate\Database\Eloquent\Collection;

class EmailAllowed implements Rule {
    private Collection $emailPermissions;

    /**
     * Create a new rule instance.
     *
     * @return void
     */
    public function __construct() {
        $this->emailPermissions = EmailPermission::orderBy('order')->get();
    }

    /**
     * Determine if the validation rule passes.
     *
     * @param  string  $attribute
     * @param  mixed  $value
     * @return bool
     */
    public function passes($attribute, $value) {
        foreach ($this->emailPermissions as $permission) {
            if ($permission->matches($value)) {
                return $permission->if_matches == 'pass';
            }
        }
        return false;
    }

    /**
     * Get the validation error message.
     *
     * @return string
     */
    public function message() {
        return 'The :attribute matches the blacklist.';
    }
}
