<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EmailAddress extends Model {
    protected $dateFormat = 'U';
    public $incrementing = false;
    protected $primaryKey = 'email_address';
    protected $fillable = [
        'email_address',
        'user_id',
    ];
}
