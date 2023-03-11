<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;

class EmailPermission extends Model {
    use HasUlids;

    protected $dateFormat = 'U';

    protected $fillable = [
        'order',
        'regex',
        'if_matches',
    ];

    public function matches(string $string): bool {
        return @preg_match($this->regex, $string);
    }
}
