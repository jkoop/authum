<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AuthenticationReturnToken extends Model {
    protected $dateFormat = 'U';
    protected $fillable = [
        'user_id',
        'forward_to',
    ];
}
