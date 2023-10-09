ALTER TABLE `group_user`
ADD UNIQUE `group_id_user_id` (`group_id`, `user_id`),
DROP INDEX `group_id`;
