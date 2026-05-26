CREATE TABLE IF NOT EXISTS `kysely_migration` (
  `name` varchar(255) not null,
  `timestamp` varchar(255) not null,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `kysely_migration_lock` (
  `id` varchar(255) not null,
  `is_locked` int default 0 not null,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSUsersTable` (
  `id` varchar(255) not null,
  `url` text,
  `name` text not null,
  `email` varchar(255),
  `avatar` text,
  `username` varchar(255) not null,
  `password` text,
  `updatedAt` text not null,
  `createdAt` text not null DEFAULT (CURRENT_TIMESTAMP),
  `emailVerified` int default 0 not null,
  `notifications` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSOAuthAccounts` (
  `providerUserId` varchar(255) not null,
  `provider` varchar(255) not null,
  `userId` varchar(255) not null,
  FOREIGN KEY (`userId`) REFERENCES `StudioCMSUsersTable`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSSessionTable` (
  `id` varchar(255) not null,
  `userId` varchar(255) not null,
  `expiresAt` text not null,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`userId`) REFERENCES `StudioCMSUsersTable`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSPermissions` (
  `user` varchar(255) not null,
  `rank` varchar(255) not null,
  FOREIGN KEY (`user`) REFERENCES `StudioCMSUsersTable`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSAPIKeys` (
  `id` varchar(255) not null,
  `userId` varchar(255) not null,
  `key` text not null,
  `creationDate` text not null,
  `description` text,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`userId`) REFERENCES `StudioCMSUsersTable`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSUserResetTokens` (
  `id` varchar(255) not null,
  `userId` varchar(255) not null,
  `token` text not null,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`userId`) REFERENCES `StudioCMSUsersTable`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSPageFolderStructure` (
  `id` varchar(255) not null,
  `name` text not null,
  `parent` varchar(255),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSPageData` (
  `id` varchar(255) not null,
  `package` varchar(255) not null,
  `title` text not null,
  `description` text not null,
  `showOnNav` int default 0 not null,
  `publishedAt` text,
  `updatedAt` text not null,
  `slug` varchar(255) not null,
  `contentLang` varchar(10) not null,
  `heroImage` text,
  `categories` text default '[]' not null,
  `tags` text default '[]' not null,
  `authorId` varchar(255) not null,
  `contributorIds` text default '[]' not null,
  `showAuthor` int default 0 not null,
  `showContributors` int default 0 not null,
  `parentFolder` varchar(255),
  `draft` int default 0 not null,
  `augments` text default '[]' not null,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSDiffTracking` (
  `id` varchar(255) not null,
  `pageId` varchar(255) not null,
  `userId` varchar(255) not null,
  `timestamp` text not null,
  `pageMetaData` text not null,
  `pageContentStart` text not null,
  `diff` text,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`pageId`) REFERENCES `StudioCMSPageData`(`id`),
  FOREIGN KEY (`userId`) REFERENCES `StudioCMSUsersTable`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSPageDataTags` (
  `id` int auto_increment not null,
  `description` text not null,
  `name` varchar(255) not null,
  `slug` varchar(255) not null,
  `meta` text not null,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSPageDataCategories` (
  `id` int auto_increment not null,
  `parent` int,
  `description` text not null,
  `name` varchar(255) not null,
  `slug` varchar(255) not null,
  `meta` text not null,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSPageContent` (
  `id` varchar(255) not null,
  `contentId` varchar(255) not null,
  `contentLang` varchar(10) not null,
  `content` text not null,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`contentId`) REFERENCES `StudioCMSPageData`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSEmailVerificationTokens` (
  `id` varchar(255) not null,
  `userId` varchar(255) not null,
  `token` text not null,
  `expiresAt` text not null,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`userId`) REFERENCES `StudioCMSUsersTable`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSPluginData` (
  `id` varchar(255) not null,
  `data` text not null,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSDynamicConfigSettings` (
  `id` varchar(255) not null,
  `data` text not null,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `_kysely_schema_v1` (
  `id` int auto_increment not null,
  `definition` text not null,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `StudioCMSStorageManagerUrlMappings` (
  `identifier` varchar(255) not null,
  `url` text not null,
  `isPermanent` int default 0 not null,
  `expiresAt` int,
  `createdAt` int not null,
  `updatedAt` int not null,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX IF NOT EXISTS `idx_permissions_user` ON `StudioCMSPermissions`(`user`);
CREATE INDEX IF NOT EXISTS `idx_pagedata_slug` ON `StudioCMSPageData`(`slug`);
CREATE INDEX IF NOT EXISTS `idx_pagedata_author` ON `StudioCMSPageData`(`authorId`);
CREATE INDEX IF NOT EXISTS `idx_session_user` ON `StudioCMSSessionTable`(`userId`);
