<?php

namespace Database\Seeders;

use App\Models\DomainName;
use App\Models\EmailAddress;
use App\Models\EmailPermission;
use App\Models\Service;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder {
    public function run(): void {
        $user = User::create([
            'name' => 'Administrator',
            'password' => Hash::make('password'),
            'is_admin' => true,
            'is_enabled' => true,
        ]);

        EmailAddress::create([
            'user_id' => $user->id,
            'email_address' => 'admin@example.com',
        ]);

        $service = Service::create([
            'name' => 'Who Am I',
        ]);

        DomainName::create([
            'service_id' => $service->id,
            'domain_name' => 'whoami.localhost',
        ]);

        EmailPermission::create([
            'order' => 0,
            'regex' => '/.*/i',
            'if_matches' => 'pass',
        ]);
    }
}
