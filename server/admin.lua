-- Admin panel: server side.
--
-- Every callback re-checks permission. The client asks once before opening the
-- panel, and that answer is a convenience for the person clicking — it is not
-- the security boundary. The boundary is here, on each call, because anyone can
-- send a callback whether or not a panel exists on their screen.

local function isAdmin(src)
    if Framework.IsAdmin(src) then return true end
    for _, ace in ipairs(Config.AdminCommand.Aces or {}) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    return false
end

-- Wraps a callback so the permission check cannot be forgotten on a new one.
local function admin(name, handler)
    lib.callback.register('cipher-airdrops:server:admin:' .. name, function(source, data)
        if not isAdmin(source) then
            return { ok = false, error = 'You do not have permission for that.' }
        end
        return handler(source, data or {})
    end)
end

lib.callback.register('cipher-airdrops:server:canAdmin', function(source)
    if not isAdmin(source) then return false end
    return true, GetPlayerName(source)
end)

-- ── Live ─────────────────────────────────────────────────────────────────────

admin('getLive', function()
    local state = Airdrops.PublicState()

    return {
        drop = state,
        players = #GetPlayers(),
        minPlayers = Config.Schedule.MinPlayers or 1,
        scheduleEnabled = Config.Schedule.Enabled == true,
        nextIn = Airdrops.NextDropIn(),
    }
end)

admin('startDrop', function(src, data)
    local location = nil

    if data.locationId then
        for _, row in ipairs(Data.Locations()) do
            if row.id == data.locationId then
                location = { id = row.id, label = row.label,
                             coords = vec3(row.x, row.y, row.z),
                             weight = row.weight, radius = row.radius }
                break
            end
        end
        if not location then return { ok = false, error = 'That location no longer exists' } end
    end

    local ok, err = Airdrops.Start(location, GetPlayerName(src), { silent = data.silent == true })
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

admin('cancelDrop', function()
    if not Airdrops.Active() then return { ok = false, error = 'Nothing is running' } end
    Airdrops.Cancel('cancelled')
    return { ok = true }
end)

-- ── Locations ────────────────────────────────────────────────────────────────

admin('getLocations', function()
    local rows = Data.Locations(true)
    -- The panel wants booleans; MySQL hands back 1 and 0.
    for _, row in ipairs(rows) do row.enabled = row.enabled == 1 end
    return { rows = rows }
end)

admin('saveLocation', function(src, data)
    local ok, err = Data.SaveLocation(data, GetPlayerName(src))
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

admin('deleteLocation', function(_, data)
    local ok, err = Data.DeleteLocation(data.id)
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

-- ── Loot ─────────────────────────────────────────────────────────────────────

admin('getLoot', function()
    local tiers = Data.Tiers(true)

    for _, tier in ipairs(tiers) do
        tier.enabled = tier.enabled == 1
        for _, item in ipairs(tier.items or {}) do
            item.enabled = item.enabled == 1
        end
    end

    return { tiers = tiers }
end)

admin('saveTier', function(_, data)
    local ok, err = Data.SaveTier(data)
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

admin('deleteTier', function(_, data)
    local ok, err = Data.DeleteTier(data.id)
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

admin('saveLoot', function(_, data)
    local ok, err = Data.SaveLoot(data)
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

admin('deleteLoot', function(_, data)
    local ok, err = Data.DeleteLoot(data.id)
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

-- ── Settings ─────────────────────────────────────────────────────────────────

admin('getSettings', function()
    return { rows = Settings.List() }
end)

admin('saveSetting', function(src, data)
    local ok, err = Settings.Set(data.key, data.value, GetPlayerName(src))
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

admin('resetSetting', function(_, data)
    local ok, err = Settings.Reset(data.key)
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

-- ── History ──────────────────────────────────────────────────────────────────

admin('getHistory', function()
    return { rows = Data.History(50), stats = Data.Stats() }
end)
