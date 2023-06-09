<?php

use Ulid\Ulid;

DB::query(<<<SQL
    ALTER DATABASE %b
    COLLATE "ascii_general_ci"
SQL, DB::$dbName);

DB::get()->multi_query(file_get_contents(__DIR__ . "/01-tables.sql"));
while (DB::get()->next_result()); // flush multi_queries

$userId = Ulid::generate();
$serviceId = Ulid::generate();

DB::query('INSERT INTO `users` VALUES (%s, "Administrator", %s, 1, 1)', $userId, password_hash('password', null));
DB::query('INSERT INTO `email_addresses` VALUES ("admin@example.com", %s)', $userId);
DB::query('INSERT INTO `services` VALUES (%s, "Who Am I", "logout")', $serviceId);
DB::query('INSERT INTO `domain_names` VALUES ("whoami.localhost", %s)', $serviceId);
DB::query('INSERT INTO `email_acl` VALUES (%s, 0, ".*", "pass", "Allow every email address")', Ulid::generate());

$userGroupId = Ulid::generate();
DB::query('INSERT INTO `user_groups` VALUES (%s, "My first group of users")', $userGroupId);
DB::query('INSERT INTO `user_user_group` VALUES (%s, %s)', $userId, $userGroupId);
