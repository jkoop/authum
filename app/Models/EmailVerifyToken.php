<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmailVerifyToken extends Model {
    protected $dateFormat = 'U';
    public $incrementing = false;
    public $timestamps = false;
    protected $fillable = [
        'id',
        'email_address',
        'user_id',
        'expires_at',
    ];
    protected $casts = [
        'expires_at' => 'datetime',
    ];

    public function user(): BelongsTo {
        return $this->belongsTo(User::class);
    }
}
