<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EmailAddress extends Model {
    protected $dateFormat = 'U';
    protected $fillable = [
        'user_id',
        'email_address',
    ];
}
