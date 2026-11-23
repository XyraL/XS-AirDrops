Db = { ready = false }

function Db.Json(value)
    return json.encode(value == nil and {} or value)
end

function Db.Decode(text, fallback)
    if type(text) == 'table' then return text end
    if type(text) ~= 'string' or text == '' then return fallback end
    local ok, value = pcall(json.decode, text)
    if ok and value ~= nil then return value end
    return fallback
end

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `xs_airdrop_zones` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `label` VARCHAR(100) NOT NULL,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `data` LONGTEXT NULL,
        `created_by` VARCHAR(100) DEFAULT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_airdrop_crates` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `label` VARCHAR(100) NOT NULL,
        `data` LONGTEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_airdrop_loot_tables` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `label` VARCHAR(100) NOT NULL,
        `data` LONGTEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_airdrop_history` (
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
        KEY `idx_started` (`started_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_airdrop_settings` (
        `key` VARCHAR(64) PRIMARY KEY,
        `value` TEXT NOT NULL,
        `changed_by` VARCHAR(100) DEFAULT NULL,
        `changed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_airdrop_meta` (
        `name` VARCHAR(64) PRIMARY KEY,
        `value` TEXT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local HISTORY_COLUMNS = {
    { 'zone_id', 'INT NULL DEFAULT NULL' },
    { 'crate_label', 'VARCHAR(100) NULL DEFAULT NULL' },
    { 'loot_label', 'VARCHAR(100) NULL DEFAULT NULL' },
    { 'started_unix', 'INT NULL DEFAULT NULL' },
    { 'ended_unix', 'INT NULL DEFAULT NULL' },
}

function Db.Columns(name)
    local out = {}
    local ok, rows = pcall(MySQL.query.await, ('SHOW COLUMNS FROM `%s`'):format(name))
    if not ok or type(rows) ~= 'table' then return out end
    for _, row in ipairs(rows) do
        local field = row.Field or row.field or row.COLUMN_NAME
        if field then out[field] = true end
    end
    return out
end

function Db.Exists(name)
    local ok, n = pcall(MySQL.scalar.await,
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })
    return ok and (tonumber(n) or 0) > 0
end

function Db.Meta(name)
    local row = MySQL.single.await('SELECT `value` FROM `xs_airdrop_meta` WHERE `name` = ?', { name })
    return row and row.value or nil
end

function Db.SetMeta(name, value)
    MySQL.query.await('INSERT INTO `xs_airdrop_meta` (`name`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)',
        { name, tostring(value) })
end

function Db.Init()
    for _, sql in ipairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then
            print(('^1[XS-AirDrops]^0 could not create a table: %s'):format(tostring(err)))
        end
    end

    local have = Db.Columns('xs_airdrop_history')
    local added = false
    for _, col in ipairs(HISTORY_COLUMNS) do
        if next(have) and not have[col[1]] then
            local ok, err = pcall(MySQL.query.await, ('ALTER TABLE `xs_airdrop_history` ADD COLUMN `%s` %s'):format(col[1], col[2]))
            if not ok then print(('^1[XS-AirDrops]^0 could not add %s to the history: %s'):format(col[1], tostring(err))) end
            if col[1] == 'started_unix' then added = true end
        end
    end
    if added then
        pcall(MySQL.query.await, 'UPDATE `xs_airdrop_history` SET `started_unix` = UNIX_TIMESTAMP(`started_at`) WHERE `started_unix` IS NULL')
    end

    Db.ready = true
end
