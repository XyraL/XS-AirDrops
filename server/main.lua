Drops = { list = {}, nextAt = 0, lastZone = nil, zoneAt = {}, note = nil, ready = false, ticks = 0, away = {} }

local function log(fmt, ...)
    if Config.Debug then
        print(('^2[XS-AirDrops]^0 ' .. fmt):format(...))
    end
end

local function now()
    return os.time()
end

local function hourNow()
    return tonumber(os.date('%H')) or 0
end

local function isPolice(src)
    local job = Framework.GetJob(src)
    return job ~= nil and Util.Has(Config.Access.Police.Jobs, job.name)
end

local function inGroups(src, jobs, gangs)
    local job = Framework.GetJob(src)
    if job and Util.Has(jobs, job.name) then return true end
    local gang = Framework.GetGang(src)
    return gang ~= nil and Util.Has(gangs, gang.name)
end

local function seeRule(d)
    local own = d and d.see
    if type(own) == 'table' and own.rule and own.rule ~= 'default' then return own.rule, own.jobs, own.gangs end
    local rule = Config.Access.See or {}
    return rule.Mode or 'everyone', rule.Jobs, rule.Gangs
end

function Drops.Allows(d, job, gang, police)
    local mode, jobs, gangs = seeRule(d)
    local listed = Util.Has(jobs, job) or Util.Has(gangs, gang)
    if mode == 'except' then return not listed end
    if mode ~= 'only' then return true end
    if police and Config.Access.Police.CanSee then return true end
    return listed
end

function Drops.CanCollect(src, crate)
    local access = (crate or {}).access or {}
    if isPolice(src) then
        if access.police == 'allow' then return true end
        if access.police == 'deny' then return false end
        return Config.Access.Police.CanCollect == true
    end
    if access.rule == 'everyone' then return true end
    if access.rule == 'groups' then return inGroups(src, access.jobs, access.gangs) end
    local rule = Config.Access.Collect
    if rule.Everyone then return true end
    return inGroups(src, rule.Jobs, rule.Gangs)
end

local function canView(d, src)
    if not src or Drops.away[src] or not Framework.GetPlayer(src) then return false end
    if d.silent then return Framework.CanBuild(src) end
    local job, gang = Framework.GetJob(src), Framework.GetGang(src)
    return Drops.Allows(d, job and job.name, gang and gang.name, isPolice(src))
end

local function policeWhoMaySee(d)
    local jobs = (Config.Police or {}).Jobs or {}
    if #jobs == 0 then jobs = { 'police' } end
    local out = {}
    for _, job in ipairs(jobs) do
        if Drops.Allows(d, job, nil, Util.Has(Config.Access.Police.Jobs, job)) then out[#out + 1] = job end
    end
    return out, #out < #jobs
end

function Drops.Count()
    local n = 0
    for _ in pairs(Drops.list) do n = n + 1 end
    return n
end

local function publicState(d)
    local t = now()
    local c = d.crate
    return {
        id = d.id,
        state = d.state,
        silent = d.silent or nil,
        label = Config.Announce.NameLocation and d.label or nil,
        zoneRadius = d.radius,
        approxRadius = d.approx,
        approx = d.state == 'announced' or d.state == 'inbound',
        coords = { x = d.coords.x, y = d.coords.y, z = d.coords.z },
        landsIn = math.max(0, d.landsAt - t),
        expiresIn = d.expiresAt and math.max(0, d.expiresAt - t) or nil,
        heading = d.heading,
        crackedBy = d.crackedByName,
        emptied = d.emptied or nil,
        crate = {
            label = c.label, model = c.model, crackTime = c.crackTime, flyover = c.flyover, parachute = c.parachute,
            flare = c.flare, smoke = c.smoke, plane = c.plane, altitude = c.altitude,
            sprite = c.blip.sprite, colour = c.blip.colour, blip = c.blip.label,
        },
    }
end

local function refreshPanels()
    TriggerClientEvent('XS-AirDrops:client:refreshPanel', -1)
end

local function broadcast(d)
    local state = publicState(d)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then
            TriggerClientEvent('XS-AirDrops:client:sync', src, d.id, canView(d, src) and state or nil)
        end
    end
    refreshPanels()
end

local function fill(d, values)
    values = values or {}
    local named = Config.Announce.NameLocation
    values.zone = named and d.label or 'somewhere nearby'
    values.near = named and (' near ' .. d.label) or ''
    values.crate = d.crate.label
    return values
end

local function announce(d, key, values)
    if not Config.Announce.ToEveryone then return end
    local text = (d.crate.announce or {})[key]
    if not text or text == '' then return end
    local message = Util.Fill(text, fill(d, values))
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and canView(d, src) then
            TriggerClientEvent('XS-AirDrops:client:announce', src, message)
        end
    end
end

local function webhook(d, title, description)
    if d.silent then return end
    local url = Config.Announce.Webhook
    if not url or url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        embeds = { {
            title = title,
            description = description,
            color = 14708784,
            footer = { text = 'XS-AirDrops' },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

local function interval()
    local sc = Config.Schedule
    local low = math.floor(tonumber(sc.MinInterval) or 45)
    local high = math.max(low, math.floor(tonumber(sc.MaxInterval) or 90))
    return math.random(low, high) * 60
end

local function endDrop(d, reason)
    if not d or not Drops.list[d.id] then return end
    log('drop %s ended (%s)', d.id, reason)
    if d.stashId then Inv.ClearStash(d.stashId) end
    Data.RecordEnd(d.historyId, reason)
    Drops.list[d.id] = nil
    TriggerClientEvent('XS-AirDrops:client:sync', -1, d.id, nil)
    refreshPanels()
    if not d.silent and Config.Schedule.Enabled then
        local others = false
        for _, other in pairs(Drops.list) do
            if not other.silent then others = true end
        end
        if not others then Drops.nextAt = now() + interval() end
    end
end

local function capped(d, at)
    local cap = Config.Drop.MaxLifetime or 0
    local since = d.landedAt or d.startedAt
    if cap <= 0 or not since then return at end
    return math.min(at, since + cap)
end

local function land(d)
    local t = now()
    d.state = 'landed'
    d.landedAt = t
    d.expiresAt = capped(d, t + (Config.Drop.AbandonedAfter or 900))
    if d.crate.police.alert and not d.silent then
        d.policeAt = t + (d.crate.police.delay or 45)
    end
    broadcast(d)
    announce(d, 'landed')
    log('drop %s landed at %s', d.id, d.label)
end

local function alertPolice(d)
    d.policeSent = true
    local jobs, partial = policeWhoMaySee(d)
    if #jobs == 0 then
        log('drop %s is hidden from police, so they are not called', d.id)
        return
    end
    d.alertedBy = Dispatch.Alert({
        id = d.id,
        jobs = jobs,
        partial = partial or nil,
        coords = { x = d.coords.x, y = d.coords.y, z = d.coords.z },
        code = Config.Police.Code,
        title = Config.Police.Title,
        description = 'Aircraft seen dropping cargo. Several parties likely heading there.',
        sprite = d.crate.blip.sprite,
        colour = d.crate.blip.colour,
    }, function(src) return canView(d, src) end)
end

function Drops.Start(opts)
    opts = opts or {}
    local zoneRec = opts.zone
    if not zoneRec or not zoneRec.data then return false, 'Pick a drop zone.' end
    local zone = zoneRec.data
    if #zone.points == 0 then return false, ('"%s" has no landing points yet.'):format(zone.label) end

    local max = math.max(1, tonumber(Config.Schedule.MaxActive) or 1)
    if Drops.Count() >= max then
        return false, ('%d drop%s already running. Cancel one, or raise "Drops at once" in Schedule.')
            :format(Drops.Count(), Drops.Count() == 1 and ' is' or 's are')
    end
    for _, other in pairs(Drops.list) do
        if other.zoneId == zoneRec.id then return false, ('"%s" already has a drop running.'):format(zone.label) end
    end

    local crateRec = opts.crate or Data.CrateFor(zone)
    if not crateRec then return false, 'There is no crate type to drop.' end
    local lootRec = opts.loot or Data.LootFor(zone, crateRec)
    if not lootRec then return false, 'There is no loot table to fill it.' end

    local index = tonumber(opts.point)
    if not index or not zone.points[index] then index = math.random(#zone.points) end
    local p = zone.points[index]

    local crate = Util.Copy(crateRec.data)
    local flight = Util.FlightTime(crate, Config.Delivery)
    local warning = math.max(math.floor(tonumber(Config.Drop.WarningTime) or 90), flight + 5)
    local t = now()

    local d = {
        id = ('%d-%d'):format(t, math.random(1000, 9999)),
        zoneId = zoneRec.id,
        label = zone.label,
        point = index,
        coords = vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0),
        radius = (zone.radius > 0 and zone.radius or (Config.Drop.ZoneRadius or 120.0)) + 0.0,
        approx = (zone.approx > 0 and zone.approx or (Config.Drop.ApproxBlipRadius or 250.0)) + 0.0,
        crate = crate,
        crateId = crateRec.id,
        crateLabel = crate.label,
        loot = Util.Copy(lootRec.data),
        lootId = lootRec.id,
        lootLabel = lootRec.data.label,
        heading = zone.heading >= 0 and zone.heading or math.random(0, 359),
        flight = flight,
        state = 'announced',
        startedAt = t,
        landsAt = t + warning,
        expiresAt = t + warning + 180,
        cracks = {},
        searches = {},
        silent = opts.silent == true,
        calledBy = opts.by,
        see = Util.Copy(zone.see),
    }
    while Drops.list[d.id] do d.id = ('%d-%d'):format(t, math.random(1000, 9999)) end

    Drops.list[d.id] = d
    if not d.silent then
        Drops.lastZone = zoneRec.id
        Drops.zoneAt[zoneRec.id] = t
        d.historyId = Data.RecordStart(d, opts.by)
    end

    broadcast(d)
    announce(d, 'inbound', { seconds = warning })
    webhook(d, 'Supply drop inbound', ('**%s** · %s%s'):format(d.label, d.crateLabel, opts.by and ('\nCalled by ' .. opts.by) or ''))
    log('drop %s announced for %s%s', d.id, d.label, opts.by and (' by ' .. opts.by) or '')
    return true, d
end

function Drops.Cancel(id, reason)
    local d = Drops.list[id]
    if not d then return false, 'That drop is over already.' end
    endDrop(d, reason or 'cancelled')
    return true
end

local function anyoneInZone(d)
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(id))
        if ped and ped ~= 0 and #(GetEntityCoords(ped) - d.coords) <= d.radius then return true end
    end
    return false
end

local function anyoneCracking(d)
    local cutoff = now() - ((d.crate.crackTime or 25) + 5)
    for _, startedAt in pairs(d.cracks) do
        if startedAt >= cutoff then return true end
    end
    return false
end

local function nearCrate(d, src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local reach = (Config.Drop.CrackDistance or 5.0) + 3.0
    return Util.Flat(pos, d.coords) <= reach and math.abs(pos.z - d.coords.z) <= 25.0
end

local function markEmptied(d)
    if d.emptied then return end
    d.emptied = true
    d.expiresAt = capped(d, now() + (Config.Drop.EmptyLinger or 60))
    announce(d, 'emptied')
    broadcast(d)
    log('drop %s emptied', d.id)
end

local function expire(d)
    local t = now()
    local since = d.landedAt or d.startedAt
    local cap = Config.Drop.MaxLifetime or 0
    local pastCap = cap > 0 and (t - since) >= cap
    local grace = Config.Drop.PresenceGrace or 120
    local onGround = d.state == 'landed' or d.state == 'open'
    if onGround and grace > 0 and not pastCap and not d.emptied and (anyoneInZone(d) or anyoneCracking(d)) then
        d.expiresAt = capped(d, t + grace)
        d.heldOpen = true
        broadcast(d)
        log('drop %s held, someone is still there', d.id)
        return
    end
    endDrop(d, d.emptied and 'emptied' or (d.state == 'open' and 'looted out' or 'abandoned'))
end

function Drops.Tick()
    local t = now()
    Drops.ticks = Drops.ticks + 1
    for id, d in pairs(Drops.list) do
        if d.state == 'announced' and t >= d.landsAt - d.flight then
            d.state = 'inbound'
            broadcast(d)
        end
        if d.state == 'inbound' and t >= d.landsAt then land(d) end
        if d.policeAt and not d.policeSent and t >= d.policeAt and (d.state == 'landed' or d.state == 'open') then
            alertPolice(d)
        end
        if Drops.ticks % 4 == 0 and d.state == 'open' and not d.emptied and d.stashId and Inv.CanPrefillStash() then
            if Inv.StashIsEmpty(d.stashId) == true then markEmptied(d) end
        end
        if Drops.list[id] and d.expiresAt and t >= d.expiresAt then expire(d) end
    end
end

function Drops.Eligible(rec, ctx)
    local z = rec.data
    if not z.enabled then return false, 'switched off' end
    if #z.points == 0 then return false, 'no landing points' end
    for _, d in pairs(Drops.list) do
        if d.zoneId == rec.id then return false, 'already has a drop' end
    end
    if not Data.CrateFor(z) then return false, 'no crate type' end
    if ctx.manual then return true end
    if ctx.players < z.minPlayers then return false, ('needs %d players'):format(z.minPlayers) end
    if ctx.police < z.minPolice then return false, ('needs %d police'):format(z.minPolice) end
    if not Util.InHours(z.hours, ctx.hour) then return false, 'outside its hours' end
    local rest = (tonumber(Config.Schedule.ZoneCooldown) or 0) * 60
    local last = Drops.zoneAt[rec.id]
    if rest > 0 and last and ctx.now - last < rest then return false, 'resting' end
    return true
end

function Drops.Context(manual)
    return {
        manual = manual == true,
        now = now(),
        hour = hourNow(),
        players = #GetPlayers(),
        police = #Framework.PoliceSources(true),
    }
end

function Drops.PickZone(manual)
    local ctx = Drops.Context(manual)
    local pool = {}
    for _, rec in ipairs(Data.ZoneList()) do
        if Drops.Eligible(rec, ctx) then pool[#pool + 1] = rec end
    end
    if #pool == 0 then return nil, 'No zone can take a drop right now.' end
    if #pool > 1 and Drops.lastZone then
        for i = #pool, 1, -1 do
            if pool[i].id == Drops.lastZone then table.remove(pool, i) end
        end
    end
    local sum = 0
    for _, rec in ipairs(pool) do sum = sum + rec.data.weight end
    local roll, running = math.random() * sum, 0
    for _, rec in ipairs(pool) do
        running = running + rec.data.weight
        if roll <= running then return rec end
    end
    return pool[#pool]
end

function Drops.ScheduleTick()
    local sc = Config.Schedule
    if not sc.Enabled then
        Drops.note = 'off'
        return
    end
    local t = now()
    if Drops.nextAt == 0 then
        Drops.nextAt = t + interval()
        return
    end
    if t < Drops.nextAt then return end
    if Drops.Count() >= math.max(1, tonumber(sc.MaxActive) or 1) then
        Drops.note = 'full'
        return
    end
    if #GetPlayers() < (tonumber(sc.MinPlayers) or 0) then
        Drops.nextAt = t + 300
        Drops.note = 'players'
        log('too few players (%d/%d), trying again in 5 minutes', #GetPlayers(), sc.MinPlayers)
        return
    end
    if not Util.InHours(sc.Hours, hourNow()) then
        Drops.nextAt = t + 600
        Drops.note = 'hours'
        return
    end
    local rec, why = Drops.PickZone(false)
    if not rec then
        Drops.nextAt = t + 300
        Drops.note = 'zones'
        log('%s Trying again in 5 minutes.', why)
        return
    end
    local ok, err = Drops.Start({ zone = rec, by = 'Schedule' })
    if ok then
        Drops.note = nil
        Drops.nextAt = t + interval()
    else
        Drops.nextAt = t + 300
        Drops.note = 'failed'
        log('scheduled drop refused: %s', tostring(err))
    end
end

function Drops.Status()
    local sc = Config.Schedule
    return {
        enabled = sc.Enabled == true,
        nextIn = sc.Enabled and Drops.nextAt > 0 and math.max(0, Drops.nextAt - now()) or nil,
        note = Drops.note,
        players = #GetPlayers(),
        police = #Framework.PoliceSources(true),
        running = Drops.Count(),
        max = math.max(1, tonumber(sc.MaxActive) or 1),
        hour = hourNow(),
    }
end

function Drops.AdminList()
    local out = {}
    local t = now()
    for _, d in pairs(Drops.list) do
        out[#out + 1] = {
            id = d.id, state = d.state, label = d.label, zoneId = d.zoneId, point = d.point,
            crate = d.crateLabel, crateId = d.crateId, loot = d.lootLabel, lootId = d.lootId,
            silent = d.silent, calledBy = d.calledBy or '', crackedBy = d.crackedByName, emptied = d.emptied,
            heldOpen = d.heldOpen, coords = { x = d.coords.x, y = d.coords.y, z = d.coords.z },
            landsIn = math.max(0, d.landsAt - t), expiresIn = d.expiresAt and math.max(0, d.expiresAt - t) or nil,
            age = t - d.startedAt, policeIn = (d.policeAt and not d.policeSent) and math.max(0, d.policeAt - t) or nil,
            policeSent = d.policeSent == true, radius = d.radius,
        }
    end
    table.sort(out, function(a, b) return a.age > b.age end)
    return out
end

local function dropFor(src, id)
    local d = Drops.list[id]
    if not d or not canView(d, src) then return nil end
    return d
end

RegisterNetEvent('XS-AirDrops:server:beginCrack', function(id)
    local src = source
    local d = dropFor(src, id)
    if not d or d.state ~= 'landed' then
        Framework.Notify(src, 'There is no crate to open.', 'error')
        return
    end
    if not nearCrate(d, src) then
        Framework.Notify(src, 'You are not close enough to the crate.', 'error')
        return
    end
    if not Drops.CanCollect(src, d.crate) then
        Framework.Notify(src, Config.Access.DeniedMessage, 'error')
        return
    end
    d.cracks[src] = now()
    log('%s started cracking %s', GetPlayerName(src), d.id)
end)

RegisterNetEvent('XS-AirDrops:server:finishCrack', function(id)
    local src = source
    local d = dropFor(src, id)
    if not d or d.state ~= 'landed' then return end
    if not Drops.CanCollect(src, d.crate) then return end

    local startedAt = d.cracks[src]
    if not startedAt then
        Framework.Notify(src, 'That did not count. Start again at the crate.', 'error')
        return
    end

    local elapsed = now() - startedAt
    if elapsed < (d.crate.crackTime or 25) - 1 then
        log('%s finished too fast (%ds), ignored', GetPlayerName(src), elapsed)
        return
    end
    if not nearCrate(d, src) then
        Framework.Notify(src, 'You moved too far from the crate.', 'error')
        return
    end

    local t = now()
    d.state = 'open'
    d.cracks = {}
    d.crackedBy = src
    d.crackedByName = Framework.GetName(src) or GetPlayerName(src)
    d.expiresAt = capped(d, t + (Config.Drop.OpenDuration or 300))
    d.stashId = ('xsairdrop_%s'):format((d.id:gsub('[^%w]', '')))

    local rolled = Loot.Roll(d.loot)
    Inv.RegisterStash(d.stashId, d.crate.label ~= '' and d.crate.label or 'Supply Crate', d.crate.slots, d.crate.maxWeight, d.coords)

    if Inv.CanPrefillStash() then
        for _, entry in ipairs(rolled) do
            Inv.AddToStash(d.stashId, entry.item, entry.count)
        end
        d.pending = nil
    else
        d.pending = Util.Copy(rolled)
    end
    d.rolled = rolled

    Data.RecordCrack(d.historyId, Framework.GetCitizenId(src), d.crackedByName, rolled)
    broadcast(d)
    announce(d, 'opened', { name = d.crackedByName })
    webhook(d, 'Crate opened', ('**%s** opened the crate at **%s**'):format(d.crackedByName, d.label))
    log('drop %s cracked by %s, %d stacks', d.id, d.crackedByName, #rolled)
end)

RegisterNetEvent('XS-AirDrops:server:loot', function(id)
    local src = source
    local d = dropFor(src, id)
    if not d or d.state ~= 'open' then return end
    if not nearCrate(d, src) then
        Framework.Notify(src, 'You are not close enough to the crate.', 'error')
        return
    end
    if not Drops.CanCollect(src, d.crate) then
        Framework.Notify(src, Config.Access.DeniedMessage, 'error')
        return
    end

    if Inv.CanPrefillStash() then
        TriggerClientEvent('XS-AirDrops:client:openStash', src, d.stashId, { slots = d.crate.slots, maxWeight = d.crate.maxWeight })
        return
    end

    if not d.pending or #d.pending == 0 then
        Framework.Notify(src, 'The crate is empty.', 'error')
        return
    end

    local who = Framework.GetCitizenId(src) or tostring(src)
    local cap = d.crate.searchesPerPlayer or 0
    if cap > 0 and (d.searches[who] or 0) >= cap then
        Framework.Notify(src, 'You have taken your share of this crate.', 'error')
        return
    end

    local given = 0
    for _ = 1, d.crate.stacksPerSearch or 2 do
        local entry = table.remove(d.pending, 1)
        if not entry then break end
        if Inv.CanCarry(src, entry.item, entry.count) and Inv.AddItem(src, entry.item, entry.count) then
            given = given + 1
        else
            table.insert(d.pending, 1, entry)
            Framework.Notify(src, 'You cannot carry any more.', 'error')
            break
        end
    end

    if given > 0 then
        d.searches[who] = (d.searches[who] or 0) + 1
        Framework.Notify(src, ('You pull %d item stack%s from the crate.'):format(given, given == 1 and '' or 's'), 'success')
    end
    if #d.pending == 0 then markEmptied(d) end
end)

RegisterNetEvent('XS-AirDrops:server:openStash', function(stashId)
    local src = source
    local d
    for _, other in pairs(Drops.list) do
        if other.stashId == stashId then d = other end
    end
    if not d or d.state ~= 'open' or not dropFor(src, d.id) then return end
    if not nearCrate(d, src) then return end
    if not Drops.CanCollect(src, d.crate) then return end
    if Inv.name == 'qb-inventory' then
        exports['qb-inventory']:OpenInventory(src, stashId, { label = d.crate.label, maxweight = d.crate.maxWeight, slots = d.crate.slots })
    elseif Inv.name == 'ps-inventory' then
        TriggerClientEvent('ps-inventory:client:openStash', src, stashId)
    end
end)

RegisterNetEvent('XS-AirDrops:server:requestSync', function()
    local src = source
    local list = {}
    for _, d in pairs(Drops.list) do
        if canView(d, src) then list[#list + 1] = publicState(d) end
    end
    TriggerClientEvent('XS-AirDrops:client:syncAll', src, list)
end)

local function leave(src)
    for _, d in pairs(Drops.list) do d.cracks[src] = nil end
end

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if not src then return end
    leave(src)
    Drops.away[src] = nil
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    src = tonumber(src) or tonumber(source)
    if not src or src <= 0 then return end
    leave(src)
    Drops.away[src] = true
    TriggerClientEvent('XS-AirDrops:client:syncAll', src, {})
end)

local function resync(src)
    if not src or src <= 0 then return end
    for _, d in pairs(Drops.list) do
        TriggerClientEvent('XS-AirDrops:client:sync', src, d.id, canView(d, src) and publicState(d) or nil)
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = type(player) == 'table' and player.PlayerData and tonumber(player.PlayerData.source)
    if not src then return end
    Drops.away[src] = nil
    resync(src)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(src)
    resync(tonumber(src) or tonumber(source))
end)

AddEventHandler('QBCore:Server:OnGangUpdate', function(src)
    resync(tonumber(src) or tonumber(source))
end)

function Drops.ResyncAll()
    for _, d in pairs(Drops.list) do broadcast(d) end
end

function Drops.ZoneChanged(rec)
    if not rec or not rec.data then return end
    for _, d in pairs(Drops.list) do
        if d.zoneId == rec.id then
            d.see = Util.Copy(rec.data.see)
            broadcast(d)
        end
    end
end

function Drops.FindZone(text)
    if not text or text == '' then return nil end
    local wanted = text:lower()
    local id = tonumber((text:gsub('^#', '')))
    for _, rec in ipairs(Data.ZoneList()) do
        if (id and rec.id == id) or rec.data.label:lower():find(wanted, 1, true) then return rec end
    end
    return nil
end

local function reply(src, msg, kind)
    if src > 0 then Framework.Notify(src, msg, kind or 'inform') else print('[XS-AirDrops] ' .. msg) end
end

CreateThread(function()
    while not Data.ready do Wait(250) end
    if not Config.AdminCommand.Enabled then return end
    RegisterCommand(Config.AdminCommand.Command or 'airdrop', function(src, args)
        if src > 0 and not Framework.CanBuild(src) then
            reply(src, 'You do not have permission to call a drop.', 'error')
            return
        end
        local wanted = args[1] and table.concat(args, ' ') or nil
        local rec, why
        if wanted then
            rec = Drops.FindZone(wanted)
            if not rec then return reply(src, ('No drop zone matching "%s".'):format(wanted), 'error') end
        else
            rec, why = Drops.PickZone(true)
            if not rec then return reply(src, why, 'error') end
        end
        local ok, err = Drops.Start({ zone = rec, by = src > 0 and GetPlayerName(src) or 'Console' })
        if not ok then return reply(src, err, 'error') end
        reply(src, ('Drop called at %s.'):format(rec.data.label), 'success')
    end, false)
end)

CreateThread(function()
    Wait(500)
    Db.Init()
    Settings.Load()
    Data.Init()
    for _, rec in ipairs(Data.LootList()) do
        for _, p in ipairs(Loot.Problems(rec.data)) do
            print(('^3[XS-AirDrops]^0 loot table "%s": %s'):format(rec.data.label, p.text))
        end
    end
    local zones = 0
    for _, rec in ipairs(Data.ZoneList()) do
        if rec.data.enabled and #rec.data.points > 0 then zones = zones + 1 end
    end
    print(('^2[XS-AirDrops]^0 v%s loaded · framework=%s · inventory=%s · dispatch=%s · %d drop zones ready'):format(
        GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?',
        Framework.name or 'NONE', Inv.name or 'NONE', Dispatch.name or 'notify', zones))
    Drops.ready = true
    if Config.Schedule.Enabled then Drops.nextAt = now() + interval() end

    local lastSchedule = 0
    while true do
        Wait(1000)
        local ok, err = pcall(Drops.Tick)
        if not ok then print(('^1[XS-AirDrops]^0 drop tick failed: %s'):format(tostring(err))) end
        if now() - lastSchedule >= 15 then
            lastSchedule = now()
            ok, err = pcall(Drops.ScheduleTick)
            if not ok then print(('^1[XS-AirDrops]^0 schedule failed: %s'):format(tostring(err))) end
        end
    end
end)

exports('IsDropActive', function() return Drops.Count() > 0 end)

exports('GetDrop', function()
    for _, d in pairs(Drops.list) do
        if not d.silent then return publicState(d) end
    end
    return nil
end)

exports('GetDrops', function()
    local out = {}
    for _, d in pairs(Drops.list) do
        if not d.silent then out[#out + 1] = publicState(d) end
    end
    return out
end)

exports('StartDrop', function(zone, opts)
    opts = type(opts) == 'table' and opts or {}
    local rec
    if zone then rec = Drops.FindZone(tostring(zone)) else rec = Drops.PickZone(true) end
    if not rec then return false, 'No drop zone found' end
    local ok, res = Drops.Start({ zone = rec, by = opts.by or 'Export', silent = opts.silent == true })
    if not ok then return false, res end
    return true, res.id
end)
