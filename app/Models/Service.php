<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

final class Service extends Model {
    protected $dateFormat = 'U';

    public $fillable = [
        'name',
        'logout_path',
    ];

    public function domainNames(): HasMany {
        return $this->hasMany(DomainName::class);
    }
}
