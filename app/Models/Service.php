<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

final class Service extends Model {
    use HasFactory;
    use HasUlids;

    protected $dateFormat = 'U';

    public $fillable = [
        'name',
        'logout_path',
    ];

    public function domainNames(): HasMany {
        return $this->hasMany(DomainName::class);
    }

    public function getEntrypointAttribute(): string {
        return 'http://' . $this->domainNames->first()?->domain_name;
    }
}
