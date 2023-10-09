ALTER TABLE `users`
ADD `comment` varchar(255) COLLATE 'ascii_bin' NOT NULL AFTER `password`;
