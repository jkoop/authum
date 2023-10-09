<?php

use Ulid\Ulid;

DB::query(<<<SQL
    ALTER DATABASE %b
    COLLATE "ascii_general_ci"
SQL, DB::$dbName);

DB::get()->multi_query(file_get_contents(__DIR__ . "/01-tables.sql"));
while (DB::get()->next_result()); // flush multi_queries

$serviceId = Ulid::generate();

DB::query('INSERT INTO `users` VALUES ("admin", "Administrator", %s, 1, 1)', password_hash('password', null));
DB::query('INSERT INTO `email_addresses` VALUES ("admin@example.com", "admin")');
DB::query('INSERT INTO `services` VALUES (%s, "Who Am I", "logout")', $serviceId);
DB::query('INSERT INTO `domain_names` VALUES ("whoami.localhost", %s)', $serviceId);
DB::query('INSERT INTO `email_acl` VALUES (0, ".*", "allow", "Allow every email address")');

$userGroupId = Ulid::generate();
DB::query('INSERT INTO `user_groups` VALUES (%s, "My first group of users")', $userGroupId);
DB::query('INSERT INTO `user_user_group` VALUES ("admin", %s)', $userGroupId);
