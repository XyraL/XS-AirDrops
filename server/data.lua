Data = { ready = false, zones = {}, crates = {}, loot = {} }

local MAXID = 2147483647
local PALETTE = { '#9aa0a8', '#4c9aff', '#c084fc', '#f5a524', '#ff5c64', '#2fcf8a' }

Data.ANNOUNCE = {
    inbound = 'Supply drop inbound{near}. It lands in {seconds} seconds.',
    landed = 'The crate has landed{near}.',
    opened = '{name} has opened the crate.',
    emptied = 'The crate has been emptied.',
}

function Data.IsOn(value)
    return value == true or value == 1 or value == '1'
end

local function tbl(v)
    return type(v) == 'table' and v or {}
end

local function colour(v)
    v = tostring(v or '')
    if v:match('^#%x%x%x%x%x%x$') then return v:lower() end
    return '#9aa0a8'
end

local SEE = { default = true, everyone = true, only = true, except = true }

function Data.NormSee(v)
    v = tbl(v)
    return {
        rule = SEE[v.rule] and v.rule or 'default',
        jobs = Util.List(v.jobs, 30, true),
        gangs = Util.List(v.gangs, 30, true),
    }
end

function Data.NormZone(d)
    d = tbl(d)
    local points = {}
    for _, p in ipairs(tbl(d.points)) do
        local q = Util.Point(p)
        if q and #points < 24 then points[#points + 1] = q end
    end
    local hours = tbl(d.hours)
    return {
        see = Data.NormSee(d.see),
        label = Util.Text(d.label, 60),
        enabled = d.enabled ~= false and d.enabled ~= 0,
        points = points,
        radius = Util.Round(Util.Clamp(d.radius, 0, 1000, 0), 1),
        approx = Util.Round(Util.Clamp(d.approx, 0, 3000, 0), 1),
        crate = Util.Int(d.crate, 0, MAXID, 0),
        loot = Util.Int(d.loot, 0, MAXID, 0),
        weight = Util.Int(d.weight, 1, 1000, 5),
        minPlayers = Util.Int(d.minPlayers, 0, 256, 0),
        minPolice = Util.Int(d.minPolice, 0, 64, 0),
        hours = { from = Util.Int(hours.from, -1, 23, -1), to = Util.Int(hours.to, -1, 23, -1) },
        heading = Util.Int(d.heading, -1, 359, -1),
        notes = Util.Text(d.notes, 400),
    }
end

local RULES = { default = true, everyone = true, groups = true }
local POLICE = { default = true, allow = true, deny = true }

local function announceText(value, fallback)
    if value == nil then return fallback end
    return Util.Text(value, 160)
end

function Data.NormCrate(d)
    d = tbl(d)
    local access, police, ann, blip = tbl(d.access), tbl(d.police), tbl(d.announce), tbl(d.blip)
    local model = Util.Model(d.model)
    if model == '' then model = 'prop_mil_crate_01' end
    local plane = Util.Model(d.plane)
    if plane == '' then plane = 'titan' end
    return {
        label = Util.Text(d.label, 60),
        isDefault = d.isDefault == true,
        model = model,
        crackTime = Util.Int(d.crackTime, 3, 600, 25),
        stacksPerSearch = Util.Int(d.stacksPerSearch, 1, 24, 2),
        searchesPerPlayer = Util.Int(d.searchesPerPlayer, 0, 50, 0),
        slots = Util.Int(d.slots, 1, 100, 12),
        maxWeight = Util.Int(d.maxWeight, 1000, 2000000, 80000),
        loot = Util.Int(d.loot, 0, MAXID, 0),
        access = {
            rule = RULES[access.rule] and access.rule or 'default',
            jobs = Util.List(access.jobs, 30, true),
            gangs = Util.List(access.gangs, 30, true),
            police = POLICE[access.police] and access.police or 'default',
        },
        flyover = d.flyover ~= false,
        parachute = d.parachute ~= false,
        flare = d.flare ~= false,
        smoke = d.smoke ~= false,
        plane = plane,
        altitude = Util.Int(d.altitude, 50, 1500, 320),
        police = { alert = police.alert ~= false, delay = Util.Int(police.delay, 0, 900, 45) },
        announce = {
            inbound = announceText(ann.inbound, Data.ANNOUNCE.inbound),
            landed = announceText(ann.landed, Data.ANNOUNCE.landed),
            opened = announceText(ann.opened, Data.ANNOUNCE.opened),
            emptied = announceText(ann.emptied, Data.ANNOUNCE.emptied),
        },
        blip = {
            sprite = Util.Int(blip.sprite, 1, 900, 478),
            colour = Util.Int(blip.colour, 0, 85, 5),
            label = Util.Text(blip.label, 40),
        },
        notes = Util.Text(d.notes, 400),
    }
end

function Data.NormLoot(d)
    d = tbl(d)
    local tiers, names = {}, {}
    for _, t in ipairs(tbl(d.tiers)) do
        if type(t) == 'table' and #tiers < 12 then
            local name = Util.Text(t.name, 32)
            if name == '' then name = 'tier ' .. (#tiers + 1) end
            local base, n = name, 2
            while names[name:lower()] do
                name = base .. ' ' .. n
                n = n + 1
            end
            names[name:lower()] = true
            local items = {}
            for _, it in ipairs(tbl(t.items)) do
                if type(it) == 'table' and #items < 60 then
                    local item = Util.Item(it.item)
                    if item ~= '' then
                        local min = Util.Int(it.min, 1, 10000, 1)
                        local max = Util.Int(it.max, min, 10000, min)
                        items[#items + 1] = { item = item, min = min, max = max, weight = Util.Int(it.weight, 1, 1000, 10), enabled = it.enabled ~= false }
                    end
                end
            end
            tiers[#tiers + 1] = { name = name, weight = Util.Int(t.weight, 1, 1000, 10), colour = colour(t.colour), enabled = t.enabled ~= false, items = items }
        end
    end
    local minStacks = Util.Int(d.minStacks, 1, 24, 4)
    local maxStacks = Util.Int(d.maxStacks, minStacks, 24, math.max(minStacks, 7))
    local guarantee = Util.Text(d.guarantee, 32)
    if guarantee ~= '' and not names[guarantee:lower()] then guarantee = '' end
    for _, t in ipairs(tiers) do
        if guarantee ~= '' and t.name:lower() == guarantee:lower() then guarantee = t.name end
    end
    return {
        label = Util.Text(d.label, 60),
        minStacks = minStacks,
        maxStacks = maxStacks,
        guarantee = guarantee,
        tiers = tiers,
        notes = Util.Text(d.notes, 400),
    }
end

local function sorted(map)
    local out = {}
    for _, rec in pairs(map) do out[#out + 1] = rec end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Data.ZoneList() return sorted(Data.zones) end
function Data.CrateList() return sorted(Data.crates) end
function Data.LootList() return sorted(Data.loot) end

function Data.Zone(id) return Data.zones[tonumber(id) or -1] end
function Data.Crate(id) return Data.crates[tonumber(id) or -1] end
function Data.LootTable(id) return Data.loot[tonumber(id) or -1] end

function Data.DefaultCrate()
    local first
    for _, rec in ipairs(Data.CrateList()) do
        if rec.data.isDefault then return rec end
        first = first or rec
    end
    return first
end

function Data.FirstLoot()
    return Data.LootList()[1]
end

function Data.CrateFor(zone)
    local id = zone and zone.crate or 0
    return (id ~= 0 and Data.crates[id]) or Data.DefaultCrate()
end

function Data.LootFor(zone, crate)
    local id = zone and zone.loot or 0
    if id ~= 0 and Data.loot[id] then return Data.loot[id] end
    local cid = crate and crate.data and crate.data.loot or 0
    if cid ~= 0 and Data.loot[cid] then return Data.loot[cid] end
    return Data.FirstLoot()
end

local function load(name, norm, map)
    for k in pairs(map) do map[k] = nil end
    for _, row in ipairs(MySQL.query.await(('SELECT * FROM `%s`'):format(name)) or {}) do
        local id = tonumber(row.id)
        if id then
            local data = Db.Decode(row.data, {})
            if type(data) ~= 'table' then data = {} end
            if (data.label or '') == '' then data.label = row.label end
            if name == 'xs_airdrop_zones' and row.enabled ~= nil and data.enabled == nil then data.enabled = Data.IsOn(row.enabled) end
            map[id] = { id = id, data = norm(data), by = row.created_by }
        end
    end
end

local legacyRows

local function legacy(key, kind, fallback)
    if not legacyRows then
        legacyRows = {}
        for _, row in ipairs(MySQL.query.await('SELECT `key`, `value` FROM `xs_airdrop_settings`') or {}) do
            legacyRows[row.key] = row.value
        end
    end
    local raw = legacyRows[key]
    if raw ~= nil then
        local value = Settings.Decode(kind, raw)
        if value ~= nil then return value end
    end
    local node = Config
    for part in key:gmatch('[^%.]+') do
        if type(node) ~= 'table' then node = nil break end
        node = node[part]
    end
    if node ~= nil then return node end
    return fallback
end

local function oldTiers()
    if not Db.Exists('xs_airdrop_tiers') then return nil end
    local tiers = MySQL.query.await('SELECT * FROM `xs_airdrop_tiers`') or {}
    if #tiers == 0 then return nil end
    table.sort(tiers, function(a, b)
        local ra, rb = tonumber(a.rank) or 0, tonumber(b.rank) or 0
        if ra == rb then return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end
        return ra < rb
    end)
    local byTier = {}
    if Db.Exists('xs_airdrop_loot') then
        for _, row in ipairs(MySQL.query.await('SELECT * FROM `xs_airdrop_loot`') or {}) do
            local tid = tonumber(row.tier_id)
            if tid then
                byTier[tid] = byTier[tid] or {}
                table.insert(byTier[tid], row)
            end
        end
    end
    local out = {}
    for i, t in ipairs(tiers) do
        local items = {}
        local rows = byTier[tonumber(t.id)] or {}
        table.sort(rows, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
        for _, row in ipairs(rows) do
            items[#items + 1] = { item = row.item, min = row.min_count, max = row.max_count, weight = row.weight, enabled = Data.IsOn(row.enabled) }
        end
        out[#out + 1] = { name = t.name, weight = t.weight, colour = t.colour or PALETTE[i], enabled = Data.IsOn(t.enabled), items = items }
    end
    return out
end

local function configTiers()
    local out = {}
    for i, t in ipairs(tbl((Config.Loot or {}).Tiers)) do
        local items = {}
        for _, it in ipairs(tbl(t.items)) do
            items[#items + 1] = { item = it.item, min = it.min, max = it.max or it.min, weight = it.weight or 10, enabled = true }
        end
        out[#out + 1] = { name = t.name, weight = t.weight or 10, colour = PALETTE[i], enabled = true, items = items }
    end
    return out
end

local function insertLoot(data)
    return MySQL.insert.await('INSERT INTO `xs_airdrop_loot_tables` (`label`, `data`) VALUES (?, ?)', { data.label, Db.Json(data) })
end

local function insertCrate(data)
    return MySQL.insert.await('INSERT INTO `xs_airdrop_crates` (`label`, `data`) VALUES (?, ?)', { data.label, Db.Json(data) })
end

local function insertZone(data, by)
    return MySQL.insert.await('INSERT INTO `xs_airdrop_zones` (`label`, `enabled`, `data`, `created_by`) VALUES (?, ?, ?, ?)',
        { data.label, data.enabled and 1 or 0, Db.Json(data), by or '' })
end

local function migrate()
    local report = {}

    if not Db.Meta('seeded_loot') then
        local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `xs_airdrop_loot_tables`')) or 0
        if count == 0 then
            local fromOld = oldTiers()
            local guarantee = legacy('Loot.GuaranteeAtLeast', 'text', '')
            local data = Data.NormLoot({
                label = 'Standard loot',
                minStacks = legacy('Loot.MinStacks', 'int', 4),
                maxStacks = legacy('Loot.MaxStacks', 'int', 7),
                guarantee = type(guarantee) == 'string' and guarantee or '',
                tiers = fromOld or configTiers(),
            })
            insertLoot(data)
            local items = 0
            for _, t in ipairs(data.tiers) do items = items + #t.items end
            report[#report + 1] = ('%d loot tiers (%d items) %s'):format(#data.tiers, items, fromOld and 'moved into "Standard loot"' or 'seeded from config.lua')
        end
        Db.SetMeta('seeded_loot', '1')
    end

    if not Db.Meta('seeded_crates') then
        local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `xs_airdrop_crates`')) or 0
        if count == 0 then
            local lootId = 0
            local first = MySQL.single.await('SELECT `id` FROM `xs_airdrop_loot_tables` ORDER BY `id` ASC LIMIT 1')
            if first then lootId = tonumber(first.id) or 0 end
            insertCrate(Data.NormCrate({
                label = 'Standard crate',
                isDefault = true,
                model = legacy('Delivery.CrateModel', 'text', 'prop_mil_crate_01'),
                crackTime = legacy('Drop.CrackTime', 'int', 25),
                stacksPerSearch = legacy('Loot.StacksPerSearch', 'int', 2),
                slots = legacy('Loot.Slots', 'int', 12),
                maxWeight = legacy('Loot.MaxWeight', 'int', 80000),
                loot = lootId,
                flyover = true,
                plane = legacy('Delivery.PlaneModel', 'text', 'titan'),
                altitude = legacy('Delivery.Altitude', 'num', 320),
                police = { alert = legacy('Police.Alert', 'bool', true), delay = legacy('Police.Delay', 'int', 45) },
                blip = { sprite = legacy('Blip.Sprite', 'int', 478), colour = legacy('Blip.Colour', 'int', 5), label = 'Supply Drop' },
            }))
            report[#report + 1] = 'a "Standard crate" made from your old settings'
        end
        Db.SetMeta('seeded_crates', '1')
    end

    if not Db.Meta('seeded_zones') then
        local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `xs_airdrop_zones`')) or 0
        if count == 0 then
            local n = 0
            if Db.Exists('xs_airdrop_locations') then
                local rows = MySQL.query.await('SELECT * FROM `xs_airdrop_locations`') or {}
                table.sort(rows, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
                for _, row in ipairs(rows) do
                    insertZone(Data.NormZone({
                        label = row.label,
                        enabled = Data.IsOn(row.enabled),
                        points = { { x = row.x, y = row.y, z = row.z } },
                        radius = tonumber(row.radius) or 0,
                        weight = row.weight,
                    }), row.created_by)
                    n = n + 1
                end
                if n > 0 then report[#report + 1] = ('%d locations moved into drop zones'):format(n) end
            end
            if n == 0 then
                for _, loc in ipairs(tbl(Config.Locations)) do
                    local c = loc.coords or loc
                    insertZone(Data.NormZone({
                        label = loc.label,
                        points = { { x = c.x, y = c.y, z = c.z } },
                        radius = loc.radius or 0,
                        weight = loc.weight,
                    }), 'config.lua')
                    n = n + 1
                end
                if n > 0 then report[#report + 1] = ('%d drop zones seeded from config.lua'):format(n) end
            end
        end
        Db.SetMeta('seeded_zones', '1')
    end

    legacyRows = nil
    return report
end

function Data.Reload()
    load('xs_airdrop_zones', Data.NormZone, Data.zones)
    load('xs_airdrop_crates', Data.NormCrate, Data.crates)
    load('xs_airdrop_loot_tables', Data.NormLoot, Data.loot)
end

function Data.Init()
    local report = migrate()
    Data.Reload()
    Data.ready = true
    if #report > 0 then
        print('^2[XS-AirDrops]^0 first start of the builder: ' .. table.concat(report, ', ') .. '.')
    end
    return report
end

function Data.SaveZone(id, data, by)
    local clean = Data.NormZone(data)
    if clean.label == '' then return false, 'Give the zone a name first.' end
    id = tonumber(id)
    if id and Data.zones[id] then
        MySQL.update.await('UPDATE `xs_airdrop_zones` SET `label` = ?, `enabled` = ?, `data` = ? WHERE `id` = ?',
            { clean.label, clean.enabled and 1 or 0, Db.Json(clean), id })
        Data.zones[id].data = clean
        return true, Data.zones[id]
    end
    local newId = insertZone(clean, by)
    if not newId then return false, 'The database did not save it.' end
    Data.zones[newId] = { id = newId, data = clean, by = by }
    return true, Data.zones[newId]
end

function Data.DeleteZone(id)
    id = tonumber(id)
    if not id or not Data.zones[id] then return false, 'That zone is gone already.' end
    MySQL.query.await('DELETE FROM `xs_airdrop_zones` WHERE `id` = ?', { id })
    Data.zones[id] = nil
    return true
end

function Data.SaveCrate(id, data)
    local clean = Data.NormCrate(data)
    if clean.label == '' then return false, 'Give the crate type a name first.' end
    id = tonumber(id)
    if clean.isDefault then
        for otherId, rec in pairs(Data.crates) do
            if otherId ~= id and rec.data.isDefault then
                rec.data.isDefault = false
                MySQL.update.await('UPDATE `xs_airdrop_crates` SET `data` = ? WHERE `id` = ?', { Db.Json(rec.data), otherId })
            end
        end
    end
    if id and Data.crates[id] then
        MySQL.update.await('UPDATE `xs_airdrop_crates` SET `label` = ?, `data` = ? WHERE `id` = ?', { clean.label, Db.Json(clean), id })
        Data.crates[id].data = clean
        return true, Data.crates[id]
    end
    local newId = insertCrate(clean)
    if not newId then return false, 'The database did not save it.' end
    Data.crates[newId] = { id = newId, data = clean }
    return true, Data.crates[newId]
end

function Data.DeleteCrate(id)
    id = tonumber(id)
    local rec = id and Data.crates[id]
    if not rec then return false, 'That crate type is gone already.' end
    if #Data.CrateList() <= 1 then return false, 'Keep at least one crate type.' end
    MySQL.query.await('DELETE FROM `xs_airdrop_crates` WHERE `id` = ?', { id })
    Data.crates[id] = nil
    if rec.data.isDefault then
        local nextOne = Data.CrateList()[1]
        nextOne.data.isDefault = true
        MySQL.update.await('UPDATE `xs_airdrop_crates` SET `data` = ? WHERE `id` = ?', { Db.Json(nextOne.data), nextOne.id })
    end
    return true
end

function Data.SaveLoot(id, data)
    local clean = Data.NormLoot(data)
    if clean.label == '' then return false, 'Give the loot table a name first.' end
    id = tonumber(id)
    if id and Data.loot[id] then
        MySQL.update.await('UPDATE `xs_airdrop_loot_tables` SET `label` = ?, `data` = ? WHERE `id` = ?', { clean.label, Db.Json(clean), id })
        Data.loot[id].data = clean
        return true, Data.loot[id]
    end
    local newId = insertLoot(clean)
    if not newId then return false, 'The database did not save it.' end
    Data.loot[newId] = { id = newId, data = clean }
    return true, Data.loot[newId]
end

function Data.DeleteLoot(id)
    id = tonumber(id)
    if not id or not Data.loot[id] then return false, 'That loot table is gone already.' end
    if #Data.LootList() <= 1 then return false, 'Keep at least one loot table.' end
    MySQL.query.await('DELETE FROM `xs_airdrop_loot_tables` WHERE `id` = ?', { id })
    Data.loot[id] = nil
    return true
end

function Data.RecordStart(drop, calledBy)
    return MySQL.insert.await([[
        INSERT INTO `xs_airdrop_history` (`label`, `x`, `y`, `z`, `called_by`, `zone_id`, `crate_label`, `loot_label`, `started_unix`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { drop.label, drop.coords.x, drop.coords.y, drop.coords.z, calledBy or '', drop.zoneId or 0,
          drop.crateLabel or '', drop.lootLabel or '', os.time() })
end

function Data.RecordCrack(historyId, citizenid, name, contents)
    if not historyId then return end
    MySQL.update.await('UPDATE `xs_airdrop_history` SET `cracked_by` = ?, `cracked_by_name` = ?, `contents` = ? WHERE `id` = ?',
        { citizenid or '', name or '', json.encode(contents or {}), historyId })
end

function Data.RecordEnd(historyId, outcome)
    if not historyId then return end
    MySQL.update.await('UPDATE `xs_airdrop_history` SET `outcome` = ?, `ended_at` = CURRENT_TIMESTAMP, `ended_unix` = ? WHERE `id` = ?',
        { outcome, os.time(), historyId })
end

function Data.History(limit, outcome)
    limit = math.floor(Util.Clamp(limit, 1, 500, 100))
    local rows
    if outcome and outcome ~= '' and outcome ~= 'all' then
        rows = MySQL.query.await(('SELECT * FROM `xs_airdrop_history` WHERE `outcome` = ? ORDER BY `id` DESC LIMIT %d'):format(limit), { outcome })
    else
        rows = MySQL.query.await(('SELECT * FROM `xs_airdrop_history` ORDER BY `id` DESC LIMIT %d'):format(limit))
    end
    local now = os.time()
    local out = {}
    for _, r in ipairs(rows or {}) do
        local contents = Db.Decode(r.contents, {})
        local started = tonumber(r.started_unix)
        local ended = tonumber(r.ended_unix)
        out[#out + 1] = {
            id = r.id, label = r.label, zone = tonumber(r.zone_id) or 0, crate = r.crate_label or '', loot = r.loot_label or '',
            calledBy = r.called_by or '', crackedBy = r.cracked_by_name or '', cid = r.cracked_by or '',
            outcome = r.outcome or (ended and 'ended' or 'running'), contents = type(contents) == 'table' and contents or {},
            age = started and math.max(0, now - started) or nil,
            lasted = (started and ended) and math.max(0, ended - started) or nil,
            x = r.x, y = r.y, z = r.z,
        }
    end
    return out
end

local function midnight()
    local t = os.date('*t')
    return os.time({ year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0 })
end

function Data.Stats()
    local function n(sql, args)
        local ok, v = pcall(MySQL.scalar.await, sql, args)
        return ok and (tonumber(v) or 0) or 0
    end
    local today = midnight()
    return {
        total = n('SELECT COUNT(*) FROM `xs_airdrop_history`'),
        cracked = n('SELECT COUNT(*) FROM `xs_airdrop_history` WHERE `cracked_by` IS NOT NULL'),
        abandoned = n('SELECT COUNT(*) FROM `xs_airdrop_history` WHERE `outcome` = ?', { 'abandoned' }),
        today = n('SELECT COUNT(*) FROM `xs_airdrop_history` WHERE `started_unix` >= ?', { today }),
        crackedToday = n('SELECT COUNT(*) FROM `xs_airdrop_history` WHERE `started_unix` >= ? AND `cracked_by` IS NOT NULL', { today }),
    }
end
