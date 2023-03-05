<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

final class DomainName extends Model {
    protected $dateFormat = 'U';
    public $incrementing = false;
    protected $primaryKey = 'domain_name';

    public $fillable = [
        'domain_name',
        'service_id',
    ];

    public function getSortValueAttribute(): string {
        $a = explode('.', $this->domain_name);
        $a = array_reverse($a);
        return implode('.', $a);
    }
}
