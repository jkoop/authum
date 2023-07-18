CREATE TABLE `discord_users` (
    `id` BIGINT UNSIGNED PRIMARY KEY COMMENT "the user's id",
    `username` VARCHAR(255) NOT NULL COMMENT "the user's username, not unique across the platform",
    `discriminator` VARCHAR(255) NOT NULL COMMENT "the user's Discord-tag",
    `global_name` VARCHAR(255) NULL COMMENT "the user's display name, if it is set. For bots, this is the application name",
    `avatar` VARCHAR(255) NULL COMMENT "the user's avatar hash",
    `bot` TINYINT(1) NOT NULL DEFAULT 0 COMMENT "whether the user belongs to an OAuth2 application",
    `system` TINYINT(1) NOT NULL DEFAULT 0 COMMENT "whether the user is an Official Discord System user (part of the urgent message system)",
    `mfa_enabled` TINYINT(1) NOT NULL DEFAULT 0 COMMENT "whether the user has two factor enabled on their account",
    `banner` VARCHAR(255) NULL COMMENT "the user's banner hash",
    `accent_color` INTEGER UNSIGNED NULL COMMENT "the user's banner color encoded as an integer representation of hexadecimal color code",
    `locale` VARCHAR(255) NOT NULL DEFAULT "en-GB" COMMENT "the user's chosen language option",
    `verified` TINYINT(1) NOT NULL DEFAULT 0 COMMENT "whether the email on this account has been verified",
    `email` VARCHAR(255) NULL COMMENT "the user's email",
    `flags` INTEGER UNSIGNED NOT NULL DEFAULT 0 COMMENT "the flags on a user's account",
    `premium_type` INTEGER UNSIGNED NOT NULL DEFAULT 0 COMMENT "the type of Nitro subscription on a user's account",
    `public_flags` INTEGER UNSIGNED NOT NULL DEFAULT 0 COMMENT "the public flags on a user's account",
    `avatar_decoration` VARCHAR(255) NULL COMMENT "the user's avatar decoration"
) COLLATE "utf8mb4_general_ci" COMMENT "https://discord.com/developers/docs/resources/user#user-object";

ALTER TABLE `email_addresses`
ADD `discord_user_id` BIGINT UNSIGNED NULL UNIQUE,
ADD FOREIGN KEY (`discord_user_id`) REFERENCES `discord_users` (`id`) ON DELETE SET NULL;
