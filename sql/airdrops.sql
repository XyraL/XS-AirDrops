-- XS-AirDrops
-- Optional. The script makes these tables itself on first start.
-- Old xs_airdrop_locations, xs_airdrop_tiers and xs_airdrop_loot tables are
-- read once and moved into drop zones, a crate type and a loot table.

CREATE TABLE IF NOT EXISTS `xs_airdrop_zones` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `data` LONGTEXT NULL,
    `created_by` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_airdrop_crates` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `data` LONGTEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_airdrop_loot_tables` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `data` LONGTEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_airdrop_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `called_by` VARCHAR(100) DEFAULT NULL,
    `cracked_by` VARCHAR(50) DEFAULT NULL,
    `cracked_by_name` VARCHAR(100) DEFAULT NULL,
    `contents` LONGTEXT NULL,
    `outcome` VARCHAR(30) DEFAULT NULL,
    `started_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `ended_at` TIMESTAMP NULL DEFAULT NULL,
    `zone_id` INT NULL DEFAULT NULL,
    `crate_label` VARCHAR(100) NULL DEFAULT NULL,
    `loot_label` VARCHAR(100) NULL DEFAULT NULL,
    `started_unix` INT NULL DEFAULT NULL,
    `ended_unix` INT NULL DEFAULT NULL,
    KEY `idx_started` (`started_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_airdrop_settings` (
    `key` VARCHAR(64) PRIMARY KEY,
    `value` TEXT NOT NULL,
    `changed_by` VARCHAR(100) DEFAULT NULL,
    `changed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_airdrop_meta` (
    `name` VARCHAR(64) PRIMARY KEY,
    `value` TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
