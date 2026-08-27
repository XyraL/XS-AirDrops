-- Cipher — Airdrops
-- Run this once before starting the resource. Safe to re-run.
--
-- Why there is a database at all, when v1.0 shipped without one: the admin
-- panel lets you build drop locations and loot tables in game, and that is
-- work worth an hour of somebody's evening. Storing it in a file inside the
-- resource folder loses all of it the first time someone updates the script by
-- replacing the folder, which is how nearly everyone updates a script.
--
-- config.lua is still the source of the DEFAULTS. On first start, if these
-- tables are empty, they are seeded from it — so a fresh install behaves
-- exactly as the config says, and the panel takes over from there.

CREATE TABLE IF NOT EXISTS `cipher_airdrop_locations` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `weight` INT NOT NULL DEFAULT 5,
    -- Per-location override of Config.Drop.ZoneRadius. NULL uses the global.
    `radius` FLOAT DEFAULT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_by` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `cipher_airdrop_tiers` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `weight` INT NOT NULL DEFAULT 10,
    -- Shown in the panel so a tier reads at a glance. Hex, e.g. '#e5484d'.
    `colour` VARCHAR(20) DEFAULT NULL,
    -- Ordering decides what "this tier or better" means for the guarantee.
    `rank` INT NOT NULL DEFAULT 0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    KEY `idx_rank` (`rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `cipher_airdrop_loot` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `tier_id` INT NOT NULL,
    `item` VARCHAR(100) NOT NULL,
    `min_count` INT NOT NULL DEFAULT 1,
    `max_count` INT NOT NULL DEFAULT 1,
    `weight` INT NOT NULL DEFAULT 10,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    KEY `idx_tier` (`tier_id`),
    CONSTRAINT `fk_loot_tier` FOREIGN KEY (`tier_id`)
        REFERENCES `cipher_airdrop_tiers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Every drop that has happened. Feeds the panel's history view, and answers
-- "is this actually being played with" — which is the question that decides
-- whether the loot tables need tuning.
CREATE TABLE IF NOT EXISTS `cipher_airdrop_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `called_by` VARCHAR(100) DEFAULT NULL,
    `cracked_by` VARCHAR(50) DEFAULT NULL,
    `cracked_by_name` VARCHAR(100) DEFAULT NULL,
    `contents` JSON DEFAULT NULL,
    `outcome` VARCHAR(30) DEFAULT NULL,
    `started_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `ended_at` TIMESTAMP NULL DEFAULT NULL,
    KEY `idx_started` (`started_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Runtime settings changed from the admin panel.
--
-- Only holds the ones actually changed: a key missing here means "whatever
-- config.lua says". That way editing config.lua still works for anything you
-- have never touched in the panel, and a setting you reset genuinely goes back
-- to the file's value rather than to a copy of it taken months ago.
CREATE TABLE IF NOT EXISTS `cipher_airdrop_settings` (
    `key` VARCHAR(64) PRIMARY KEY,
    `value` TEXT NOT NULL,
    `changed_by` VARCHAR(100) DEFAULT NULL,
    `changed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
