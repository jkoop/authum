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

    public function getSortValueAttribute(): string {
        $address = explode('@', $this->email_address);
        $address = array_reverse($address);
        $address = array_map(function ($thing) {
            $thing = explode('.', $thing);
            $thing = array_reverse($thing);
            return implode('.', $thing);
        }, $address);
        return implode('@', $address);
    }
}
