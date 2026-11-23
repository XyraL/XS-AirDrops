Builder = {}

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

function Builder.System()
    local target
    for _, name in ipairs({ 'ox_target', 'qb-target' }) do
        if running(name) then target = name break end
    end
    return {
        framework = Framework.name == 'qbox' and 'Qbox' or (Framework.name == 'qbcore' and 'QBCore' or nil),
        inventory = Inv.name,
        shared = Inv.CanPrefillStash(),
        dispatch = Dispatch.name,
        target = target,
        webhook = (Config.Announce.Webhook or '') ~= '',
    }
end

function Builder.Access()
    local A = Config.Admin or {}
    local C = Config.AdminCommand or {}
    return {
        ace = A.acePermission or 'xs.airdrops',
        aces = C.Aces or {},
        groups = A.groups or {},
        licenses = #(A.licenses or {}),
        command = C.Builder or 'airdrops',
        drop = C.Enabled ~= false and (C.Command or 'airdrop') or nil,
    }
end

function Builder.Live()
    return { drops = Drops.AdminList(), schedule = Drops.Status(), stats = Data.Stats() }
end

function Builder.Data(src)
    return {
        me = { name = Framework.GetName(src) or GetPlayerName(src) or '' },
        zones = Data.ZoneList(),
        crates = Data.CrateList(),
        loot = Data.LootList(),
        live = Builder.Live(),
        system = Builder.System(),
        access = Builder.Access(),
        items = Inv.Items(),
        jobs = Framework.Jobs(),
        gangs = Framework.Gangs(),
        settings = Settings.Builder(),
    }
end

local function who(src)
    return GetPlayerName(src) or ('#' .. tostring(src))
end

local Actions = {}

Actions['data'] = function(src)
    return true, Builder.Data(src)
end

Actions['live'] = function()
    return true, Builder.Live()
end

Actions['teleport'] = function()
    return true
end

Actions['zone:save'] = function(src, p)
    local ok, rec = Data.SaveZone(p.id, p.data, who(src))
    if not ok then return false, rec end
    Drops.ZoneChanged(rec)
    return true, rec
end

Actions['zone:delete'] = function(_, p)
    for _, d in pairs(Drops.list) do
        if d.zoneId == tonumber(p.id) then return false, 'A drop is running there. Cancel it first.' end
    end
    return Data.DeleteZone(p.id)
end

Actions['crate:save'] = function(_, p)
    local ok, rec = Data.SaveCrate(p.id, p.data)
    if not ok then return false, rec end
    return true, { record = rec, crates = Data.CrateList() }
end

Actions['crate:delete'] = function(_, p)
    local ok, err = Data.DeleteCrate(p.id)
    if not ok then return false, err end
    return true, { crates = Data.CrateList() }
end

Actions['loot:save'] = function(_, p)
    local ok, rec = Data.SaveLoot(p.id, p.data)
    if not ok then return false, rec end
    return true, rec
end

Actions['loot:delete'] = function(_, p)
    return Data.DeleteLoot(p.id)
end

Actions['loot:test'] = function(_, p)
    local data = Data.NormLoot(p.data)
    local rolls = {}
    for i = 1, math.floor(Util.Clamp(p.count, 1, 5, 1)) do rolls[i] = Loot.Roll(data) end
    return true, rolls
end

Actions['drop:start'] = function(src, p)
    local rec
    if tonumber(p.zone) and tonumber(p.zone) > 0 then
        rec = Data.Zone(p.zone)
        if not rec then return false, 'That zone no longer exists.' end
    else
        local why
        rec, why = Drops.PickZone(true)
        if not rec then return false, why end
    end
    local crate = tonumber(p.crate) and tonumber(p.crate) > 0 and Data.Crate(p.crate) or nil
    local loot = tonumber(p.loot) and tonumber(p.loot) > 0 and Data.LootTable(p.loot) or nil
    local ok, d = Drops.Start({ zone = rec, crate = crate, loot = loot, silent = p.silent == true, point = p.point, by = who(src) })
    if not ok then return false, d end
    return true, { id = d.id, label = d.label, live = Builder.Live() }
end

Actions['drop:cancel'] = function(_, p)
    local ok, err = Drops.Cancel(p.id, 'cancelled')
    if not ok then return false, err end
    return true, Builder.Live()
end

Actions['history'] = function(_, p)
    return true, { rows = Data.History(p.limit or 100, p.outcome), stats = Data.Stats() }
end

Actions['settings:save'] = function(src, p)
    local wasOn = Config.Schedule.Enabled == true
    local ok, values = Settings.Save(p.changes, p.resets, who(src))
    if not ok then return false, values end
    if Config.Schedule.Enabled and not wasOn then Drops.nextAt = 0 end
    Drops.ResyncAll()
    print(('^2[XS-AirDrops]^0 %s saved the settings.'):format(who(src)))
    return true, { values = values, schedule = Drops.Status() }
end

lib.callback.register('XS-AirDrops:server:canBuild', function(src)
    if not Framework.CanBuild(src) then return false end
    return true
end)

lib.callback.register('XS-AirDrops:server:builder', function(src, action, payload)
    if not Framework.CanBuild(src) then return false, 'You do not have permission for that.' end
    if not Data.ready then return false, 'Still starting up. Try again in a moment.' end
    local fn = Actions[action]
    if not fn then return false, 'Unknown action.' end
    local ok, a, b = pcall(fn, src, type(payload) == 'table' and payload or {})
    if not ok then
        print(('^1[XS-AirDrops]^0 builder %s failed: %s'):format(tostring(action), tostring(a)))
        return false, 'That failed on the server. The console has the details.'
    end
    return a, b
end)
