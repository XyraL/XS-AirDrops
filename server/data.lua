-- Locations, tiers and loot, held in the database and edited from the panel.
--
-- config.lua stays the source of the DEFAULTS. On first start these tables are
-- seeded from it, so a fresh install behaves exactly as the config file reads
-- and the panel takes over from there. Editing config.lua afterwards does
-- nothing, which is the honest behaviour — two places claiming to own the same
-- setting is how the website ended up advertising the wrong script count three
-- times.
Data = { ready = false }

-- Is a TINYINT(1) column on?
--
-- oxmysql hands TINYINT(1) back as a Lua boolean, not as 1. Comparing to 1
-- therefore fails for every row, which is not a small bug here: Locations() and
-- Tiers() both filter on it, so the scheduler found no places to drop and every
-- crate rolled empty. Accept whatever the driver decides to give us.
function Data.IsOn(value)
    return value == true or value == 1 or value == '1'
end

local cache = { locations = nil, tiers = nil, loot = nil }

function Data.Invalidate()
    cache.locations, cache.tiers, cache.loot = nil, nil, nil
end

-- ── Seeding ──────────────────────────────────────────────────────────────────

local function seedLocations()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM cipher_airdrop_locations')
    if count and count > 0 then return 0 end

    local n = 0
    for _, loc in ipairs(Config.Locations or {}) do
        MySQL.insert.await([[
            INSERT INTO cipher_airdrop_locations (label, x, y, z, weight, created_by)
            VALUES (?, ?, ?, ?, ?, 'config.lua')
        ]], { loc.label, loc.coords.x, loc.coords.y, loc.coords.z, loc.weight or 5 })
        n = n + 1
    end
    return n
end

local function seedLoot()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM cipher_airdrop_tiers')
    if count and count > 0 then return 0, 0 end

    -- Rank comes from the order in config.lua, which is what "this tier or
    -- better" already meant before any of this was in a database.
    local tiers, items = 0, 0
    local palette = { '#9aa0a8', '#4c9aff', '#c084fc', '#f5a524' }

    for rank, tier in ipairs(Config.Loot.Tiers or {}) do
        local tierId = MySQL.insert.await([[
            INSERT INTO cipher_airdrop_tiers (name, weight, colour, rank)
            VALUES (?, ?, ?, ?)
        ]], { tier.name, tier.weight or 10, palette[rank] or '#9aa0a8', rank })
        tiers = tiers + 1

        for _, entry in ipairs(tier.items or {}) do
            MySQL.insert.await([[
                INSERT INTO cipher_airdrop_loot (tier_id, item, min_count, max_count, weight)
                VALUES (?, ?, ?, ?, ?)
            ]], { tierId, entry.item, entry.min or 1, entry.max or entry.min or 1, entry.weight or 10 })
            items = items + 1
        end
    end
    return tiers, items
end

function Data.Init()
    local locs = seedLocations()
    local tiers, items = seedLoot()

    Data.ready = true
    Data.Invalidate()

    if locs > 0 or tiers > 0 then
        print(('^2[cipher-airdrops]^0 seeded from config.lua: %d locations, %d tiers, %d loot entries')
            :format(locs, tiers, items))
    end
end

-- ── Reads ────────────────────────────────────────────────────────────────────

function Data.Locations(includeDisabled)
    if not cache.locations then
        cache.locations = MySQL.query.await(
            'SELECT * FROM cipher_airdrop_locations ORDER BY label ASC') or {}
    end

    if includeDisabled then return cache.locations end

    local out = {}
    for _, loc in ipairs(cache.locations) do
        if Data.IsOn(loc.enabled) then out[#out + 1] = loc end
    end
    return out
end

-- Tiers with their items attached, ordered by rank so "or better" is a simple
-- index comparison exactly as it was when this lived in a Lua table.
function Data.Tiers(includeDisabled)
    if not cache.tiers then
        local tiers = MySQL.query.await('SELECT * FROM cipher_airdrop_tiers ORDER BY rank ASC') or {}
        local loot  = MySQL.query.await('SELECT * FROM cipher_airdrop_loot') or {}

        local byTier = {}
        for _, row in ipairs(loot) do
            byTier[row.tier_id] = byTier[row.tier_id] or {}
            table.insert(byTier[row.tier_id], row)
        end

        for _, tier in ipairs(tiers) do
            tier.items = byTier[tier.id] or {}
        end
        cache.tiers = tiers
    end

    if includeDisabled then return cache.tiers end

    local out = {}
    for _, tier in ipairs(cache.tiers) do
        if Data.IsOn(tier.enabled) then
            local items = {}
            for _, item in ipairs(tier.items) do
                if Data.IsOn(item.enabled) then items[#items + 1] = item end
            end
            if #items > 0 then
                out[#out + 1] = {
                    id = tier.id, name = tier.name, weight = tier.weight,
                    colour = tier.colour, rank = tier.rank, items = items,
                }
            end
        end
    end
    return out
end

-- ── Writes ───────────────────────────────────────────────────────────────────
-- Every one of these invalidates the cache rather than trying to patch it. The
-- panel is used rarely and the tables are tiny; a re-read is cheaper than a
-- cache that can disagree with the database.

function Data.SaveLocation(loc, byName)
    if not loc.label or loc.label == '' then return false, 'A label is required' end
    if not loc.x or not loc.y or not loc.z then return false, 'Coordinates are required' end

    local weight = math.max(1, math.floor(tonumber(loc.weight) or 5))
    local radius = tonumber(loc.radius)

    if loc.id then
        MySQL.update.await([[
            UPDATE cipher_airdrop_locations
            SET label = ?, x = ?, y = ?, z = ?, weight = ?, radius = ?, enabled = ?
            WHERE id = ?
        ]], { loc.label, loc.x, loc.y, loc.z, weight, radius, loc.enabled and 1 or 0, loc.id })
    else
        MySQL.insert.await([[
            INSERT INTO cipher_airdrop_locations (label, x, y, z, weight, radius, enabled, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], { loc.label, loc.x, loc.y, loc.z, weight, radius, loc.enabled == false and 0 or 1, byName })
    end

    Data.Invalidate()
    return true
end

function Data.DeleteLocation(id)
    if not id then return false, 'No location' end

    -- Deleting the last one used to be refused, on the grounds that an empty
    -- table stops drops silently. But clearing the lot and building your own is
    -- exactly what a new server wants to do, and blocking it is worse than the
    -- thing it was protecting against. The panel says plainly when there are
    -- none left instead.
    MySQL.query.await('DELETE FROM cipher_airdrop_locations WHERE id = ?', { id })
    Data.Invalidate()
    return true
end

-- Clears the lot. The panel asks twice before calling this.
function Data.DeleteAllLocations()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM cipher_airdrop_locations') or 0
    MySQL.query.await('DELETE FROM cipher_airdrop_locations')
    Data.Invalidate()
    return true, count
end

function Data.SaveTier(tier)
    if not tier.name or tier.name == '' then return false, 'A tier needs a name' end

    if tier.id then
        MySQL.update.await([[
            UPDATE cipher_airdrop_tiers SET name = ?, weight = ?, colour = ?, rank = ?, enabled = ?
            WHERE id = ?
        ]], { tier.name, math.max(1, math.floor(tonumber(tier.weight) or 10)),
              tier.colour, math.floor(tonumber(tier.rank) or 0), tier.enabled and 1 or 0, tier.id })
    else
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO cipher_airdrop_tiers (name, weight, colour, rank)
                VALUES (?, ?, ?, ?)
            ]], { tier.name, math.max(1, math.floor(tonumber(tier.weight) or 10)),
                  tier.colour or '#9aa0a8', math.floor(tonumber(tier.rank) or 99) })
        end)
        if not ok then return false, 'A tier with that name already exists' end
    end

    Data.Invalidate()
    return true
end

function Data.DeleteTier(id)
    if not id then return false, 'No tier' end
    -- Loot rows go with it: the foreign key cascades.
    MySQL.query.await('DELETE FROM cipher_airdrop_tiers WHERE id = ?', { id })
    Data.Invalidate()
    return true
end

function Data.SaveLoot(entry)
    if not entry.item or entry.item == '' then return false, 'An item name is required' end
    if not entry.tier_id then return false, 'Pick a tier' end

    local min = math.max(1, math.floor(tonumber(entry.min_count) or 1))
    local max = math.max(min, math.floor(tonumber(entry.max_count) or min))
    local weight = math.max(1, math.floor(tonumber(entry.weight) or 10))

    if entry.id then
        MySQL.update.await([[
            UPDATE cipher_airdrop_loot
            SET tier_id = ?, item = ?, min_count = ?, max_count = ?, weight = ?, enabled = ?
            WHERE id = ?
        ]], { entry.tier_id, entry.item, min, max, weight, entry.enabled and 1 or 0, entry.id })
    else
        MySQL.insert.await([[
            INSERT INTO cipher_airdrop_loot (tier_id, item, min_count, max_count, weight)
            VALUES (?, ?, ?, ?, ?)
        ]], { entry.tier_id, entry.item, min, max, weight })
    end

    Data.Invalidate()
    return true
end

function Data.DeleteLoot(id)
    if not id then return false, 'No item' end
    MySQL.query.await('DELETE FROM cipher_airdrop_loot WHERE id = ?', { id })
    Data.Invalidate()
    return true
end

-- ── History ──────────────────────────────────────────────────────────────────

function Data.RecordStart(drop, calledBy)
    return MySQL.insert.await([[
        INSERT INTO cipher_airdrop_history (label, x, y, z, called_by)
        VALUES (?, ?, ?, ?, ?)
    ]], { drop.label, drop.coords.x, drop.coords.y, drop.coords.z, calledBy })
end

function Data.RecordCrack(historyId, citizenid, name, contents)
    if not historyId then return end
    MySQL.update.await([[
        UPDATE cipher_airdrop_history
        SET cracked_by = ?, cracked_by_name = ?, contents = ?
        WHERE id = ?
    ]], { citizenid, name, json.encode(contents or {}), historyId })
end

function Data.RecordEnd(historyId, outcome)
    if not historyId then return end
    MySQL.update.await([[
        UPDATE cipher_airdrop_history SET outcome = ?, ended_at = CURRENT_TIMESTAMP WHERE id = ?
    ]], { outcome, historyId })
end

function Data.History(limit)
    -- Age is computed by the database rather than left for the panel to work
    -- out from the timestamp. A MySQL TIMESTAMP comes back in the server's
    -- local time, and the player reading the panel may be in any timezone at
    -- all — so a client-side subtraction is wrong by the offset between them.
    return MySQL.query.await([[
        SELECT *, TIMESTAMPDIFF(SECOND, started_at, NOW()) AS age_seconds
        FROM cipher_airdrop_history
        ORDER BY started_at DESC LIMIT ?
    ]], { limit or 50 }) or {}
end

function Data.Stats()
    local row = MySQL.single.await([[
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN cracked_by IS NOT NULL THEN 1 ELSE 0 END) AS cracked,
            SUM(CASE WHEN outcome = 'abandoned' THEN 1 ELSE 0 END) AS abandoned
        FROM cipher_airdrop_history
    ]])
    return row or { total = 0, cracked = 0, abandoned = 0 }
end
