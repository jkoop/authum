-- >> drop unneeded tables and columns

DROP TABLE `email_acl`;
DROP TABLE `email_verify_tokens`;
DROP TABLE `password_reset_tokens`;

ALTER TABLE `acl`
DROP FOREIGN KEY `acl_ibfk_2`,
DROP `service_group_id`;

DROP TABLE `service_service_group`;
DROP TABLE `service_groups`;

-- << drop unneeded tables and columns

-- >> update user id to new format

ALTER TABLE `users` DROP CONSTRAINT `user_id_format`;

ALTER TABLE `acl`
DROP FOREIGN KEY `acl_ibfk_3`,
ADD FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `email_addresses`
DROP FOREIGN KEY `email_addresses_ibfk_1`,
ADD FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `sessions`
DROP FOREIGN KEY `sessions_ibfk_1`,
ADD FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `user_user_group`
DROP FOREIGN KEY `user_user_group_ibfk_1`,
ADD FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

UPDATE `users` SET `id` = UPPER(SUBSTRING(MD5(UPPER(`id`)), 1, 20));

ALTER TABLE `users` ADD CONSTRAINT `user_id_format` CHECK (`id` REGEXP "^[a-z0-9_-]*$");

ALTER TABLE `acl` DROP FOREIGN KEY `acl_ibfk_5`;
ALTER TABLE `email_addresses` DROP FOREIGN KEY `email_addresses_ibfk_3`;
ALTER TABLE `sessions` DROP FOREIGN KEY `sessions_ibfk_2`;
ALTER TABLE `user_user_group` DROP FOREIGN KEY `user_user_group_ibfk_3`;

ALTER TABLE `users` MODIFY `id` CHAR(20) COLLATE 'ascii_general_ci' NOT NULL;

ALTER TABLE `acl`
MODIFY `user_id` CHAR(20) COLLATE 'ascii_general_ci' NULL,
ADD FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `email_addresses`
MODIFY `user_id` CHAR(20) COLLATE 'ascii_general_ci' NOT NULL,
ADD FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `sessions`
MODIFY `user_id` CHAR(20) COLLATE 'ascii_general_ci' NOT NULL,
ADD FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `user_user_group`
MODIFY `user_id` CHAR(20) COLLATE 'ascii_general_ci' NOT NULL,
ADD FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- << update user id to new format

-- >> set user details to its discord user's details, if available

UPDATE `users`
INNER JOIN `email_addresses` ON `user_id` = `id`
INNER JOIN `discord_users` ON `discord_users`.`id` = `discord_user_id`
SET `users`.`id` = `discord_user_id`,
    `users`.`name` = COALESCE(`global_name`, CONCAT(`username`, "#", `discriminator`))
WHERE `discord_user_id` IS NOT NULL;

-- << set user details to its discord user's details, if available

-- >> drop more tables

DROP TABLE `email_addresses`;
DROP TABLE `discord_users`;

ALTER TABLE `services` ADD `domain_name` VARCHAR(255) UNIQUE;

UPDATE `services`
INNER JOIN `domain_names` ON `service_id` = `id`
SET `services`.`domain_name` = `domain_names`.`domain_name`;

DROP TABLE `domain_names`;

ALTER TABLE `services` MODIFY `domain_name` VARCHAR(255) NOT NULL UNIQUE;

-- << drop more tables

ALTER TABLE `user_user_group` DROP FOREIGN KEY `user_user_group_ibfk_2`;

ALTER TABLE `acl` DROP FOREIGN KEY `acl_ibfk_4`;

ALTER TABLE `user_groups` RENAME TO `groups`;

ALTER TABLE `groups`
DROP CONSTRAINT `user_group_id_format`,
ADD CONSTRAINT `group_id_format` CHECK (`id` regexp '^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$');

ALTER TABLE `user_user_group`
RENAME TO `group_user`,
CHANGE `user_group_id` `group_id` CHAR(26) COLLATE 'ascii_general_ci' NOT NULL AFTER `user_id`,
ADD FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

ALTER TABLE `acl`
CHANGE `user_group_id` `group_id` CHAR(26) COLLATE 'ascii_general_ci' NULL AFTER `user_id`,
ADD FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

-- >> rename user_group to group
