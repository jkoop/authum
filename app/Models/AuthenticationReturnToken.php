<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AuthenticationReturnToken extends Model {
    protected $dateFormat = 'U';
    public $incrementing = false;
    protected $fillable = [
        'id',
        'parent_session_id',
        'forward_to',
    ];
}
