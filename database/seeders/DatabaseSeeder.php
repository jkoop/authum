<?php

namespace Database\Seeders;

use App\Models\EmailAddress;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder {
    public function run(): void {
        $user = User::create([
            'name' => 'Administrator',
            'username' => 'admin',
            'password' => Hash::make('password'),
            'is_admin' => true,
        ]);

        EmailAddress::create([
            'user_id' => $user->id,
            'email_address' => 'admin@example.com',
        ]);
    }
}
