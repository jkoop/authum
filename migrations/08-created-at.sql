ALTER TABLE `groups` ADD `created_at` BIGINT UNSIGNED NOT NULL DEFAULT UNIX_TIMESTAMP();
ALTER TABLE `group_user` ADD `created_at` BIGINT UNSIGNED NOT NULL DEFAULT UNIX_TIMESTAMP();
ALTER TABLE `services` ADD `created_at` BIGINT UNSIGNED NOT NULL DEFAULT UNIX_TIMESTAMP();
ALTER TABLE `users` ADD `created_at` BIGINT UNSIGNED NOT NULL DEFAULT UNIX_TIMESTAMP();
