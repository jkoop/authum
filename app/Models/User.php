<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;

class User extends Authenticatable {
    use HasUlids;

    protected $dateFormat = 'U';

    protected $fillable = [
        'name',
        'password',
        'is_admin',
        'is_enabled',
    ];

    protected $hidden = [
        'password',
    ];

    public $casts = [
        'is_admin' => 'bool',
        'is_enabled' => 'bool',
    ];

    public function emailAddresses(): HasMany {
        return $this->hasMany(EmailAddress::class);
    }
}
