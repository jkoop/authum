<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Session extends Model {
    protected $dateFormat = 'U';
    public $timestamps = false;

    protected $fillable = [
        'user_id',
    ];

    public $casts = [
        'last_activity' => 'datetime',
    ];

    public function user(): BelongsTo {
        return $this->belongsTo(User::class);
    }
}
