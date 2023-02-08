<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;

final class DomainName extends Model {
    use HasUlids;

    protected $dateFormat = 'U';
    public $incrementing = false;
    protected $primaryKey = 'domain_name';
}
