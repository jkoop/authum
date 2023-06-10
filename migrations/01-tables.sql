CREATE TABLE `users` (
    `id` CHAR(26) PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL,
    `password` VARCHAR(255) COLLATE "ascii_bin",
    `is_admin` ENUM("0", "1") NOT NULL,
    `is_enabled` ENUM("0", "1") NOT NULL,
    CONSTRAINT user_id_format CHECK (id regexp "^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$")
);

CREATE TABLE `email_addresses` (
    `email_address` VARCHAR(255) PRIMARY KEY,
    `user_id` CHAR(26) NOT NULL,
    INDEX (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE `services` (
    `id` CHAR(26) PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL UNIQUE,
    `logout_path` VARCHAR(255) NOT NULL DEFAULT "logout",
    CONSTRAINT service_id_format CHECK (id regexp "^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$"),
    CONSTRAINT service_logout_path_must_not_begin_with_a_slash CHECK (`logout_path` NOT LIKE "/%")
);

CREATE TABLE `domain_names` (
    `domain_name` VARCHAR(255) PRIMARY KEY,
    `service_id` CHAR(26) NOT NULL,
    INDEX (service_id),
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE
);

CREATE TABLE `password_reset_tokens` (
    `id` CHAR(42) PRIMARY KEY,
    `user_id` CHAR(26),
    `expires_at` BIGINT UNSIGNED,
    INDEX (user_id),
    CONSTRAINT password_reset_token_id_format CHECK (id regexp "^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{42}$"),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE `sessions` (
    `id` CHAR(42) PRIMARY KEY,
    `user_id` CHAR(26),
    `created_at` BIGINT UNSIGNED NOT NULL,
    `last_used_at` BIGINT UNSIGNED NOT NULL,
    INDEX (user_id),
    CONSTRAINT session_id_format CHECK (id regexp "^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{42}$"),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE `email_verify_tokens` (
    `id` CHAR(42) PRIMARY KEY,
    `email_address` VARCHAR(255) NOT NULL,
    `user_id` CHAR(26) NOT NULL,
    `expires_at` BIGINT UNSIGNED NOT NULL,
    INDEX (user_id),
    CONSTRAINT email_verify_token_id_format CHECK (id regexp "^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{42}$"),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE `email_acl` (
    `order` INTEGER UNSIGNED PRIMARY KEY,
    `regex` VARCHAR(255) NOT NULL,
    `if_matches` ENUM("allow", "deny") NOT NULL,
    `comment` VARCHAR(255) NOT NULL,
    CONSTRAINT email_acl_id_format CHECK (id regexp "^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$")
) ENGINE MyISAM;

CREATE TABLE `service_groups` (
    `id` CHAR(26) PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL UNIQUE,
    CONSTRAINT service_group_id_format CHECK (id regexp "^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$")
);

CREATE TABLE `service_service_group` (
    `service_id` CHAR(26) NOT NULL,
    `service_group_id` CHAR(26) NOT NULL,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
    FOREIGN KEY (service_group_id) REFERENCES service_groups(id) ON DELETE CASCADE
);

CREATE TABLE `user_groups` (
    `id` CHAR(26) PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL UNIQUE,
    CONSTRAINT user_group_id_format CHECK (id regexp "^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$")
);

CREATE TABLE `user_user_group` (
    `user_id` CHAR(26) NOT NULL,
    `user_group_id` CHAR(26) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (user_group_id) REFERENCES user_groups(id) ON DELETE CASCADE
);

CREATE TABLE `acl` (
    `order` INTEGER UNSIGNED PRIMARY KEY,
    `service_invert` ENUM("0", "1") NOT NULL,
    `service_id` CHAR(26),
    `service_group_id` CHAR(26),
    `user_invert` ENUM("0", "1") NOT NULL,
    `user_id` CHAR(26),
    `user_group_id` CHAR(26),
    `method_regex` VARCHAR(255),
    `path_regex` VARCHAR(255),
    `domain_name_regex` VARCHAR(255),
    `if_matches` ENUM("allow", "deny") NOT NULL,
    `comment` VARCHAR(255) NOT NULL,
    CONSTRAINT acl_id_format CHECK (id regexp "^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$"),
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
    FOREIGN KEY (service_group_id) REFERENCES service_groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (user_group_id) REFERENCES user_groups(id) ON DELETE CASCADE
);
