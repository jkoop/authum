ALTER TABLE `acl`
    DROP `domain_name_regex`,
    ADD `method_regex_invert` TINYINT(1) NOT NULL AFTER `user_group_id`,
    ADD `path_regex_invert` TINYINT(1) NOT NULL AFTER `method_regex`,
    ADD `query_string_regex_invert` TINYINT(1) NOT NULL AFTER `path_regex`;
