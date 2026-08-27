-- Airdrop state. The server owns where the crate is, when it landed, who
-- cracked it and what is inside.
--
-- The crate is NOT a networked entity. Under OneSync an entity is owned by
-- whichever client has it in scope, so a networked crate would end up owned by
-- a random player who could then delete it. It never moves or takes damage, so
-- every client draws its own local prop and the truth stays here as a
-- coordinate.

local Drop = nil
local lastLocationIndex = nil
local nextDropAt = 0

-- The surface server/admin.lua drives. Kept deliberately small: read the state,
-- start one, stop one. Everything else about a drop is this file's business.
Airdrops = {}

local function log(fmt, ...)
    if Config.Debug then
        print(('^2[cipher-airdrops]^0 ' .. fmt):format(...))
    end
end

local function playerCount()
    return #GetPlayers()
end

-- ── Access ───────────────────────────────────────────────────────────────────
-- Two separate questions with usually different answers: who is told a drop is
-- happening, and who may take from it. Both are answered here and enforced on
-- the server — the panel filtering a blip out of view would stop nobody.

local function inList(value, list)
    if not value then return false end
    for _, entry in ipairs(list or {}) do
        if entry == value then return true end
    end
    return false
end

local function isPolice(src)
    local job = Framework.GetJob(src)
    return job and inList(job.name, Config.Access.Police.Jobs)
end

local function canSee(src)
    if isPolice(src) and Config.Access.Police.CanSee then return true end

    local rule = Config.Access.See
    if rule.Everyone then return true end

    local job = Framework.GetJob(src)
    if job and inList(job.name, rule.Jobs) then return true end

    local gang = Framework.GetGang(src)
    return gang and inList(gang.name, rule.Gangs) or false
end

local function canCollect(src)
    -- Police are checked first in both directions: an officer who may not loot
    -- is refused even when Collect.Everyone is on, which is the whole point of
    -- making them responders rather than another gang.
    if isPolice(src) then return Config.Access.Police.CanCollect == true end

    local rule = Config.Access.Collect
    if rule.Everyone then return true end

    local job = Framework.GetJob(src)
    if job and inList(job.name, rule.Jobs) then return true end

    local gang = Framework.GetGang(src)
    return gang and inList(gang.name, rule.Gangs) or false
end

local function isAdminSrc(src)
    if Framework.IsAdmin(src) then return true end
    for _, ace in ipairs(Config.AdminCommand.Aces or {}) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    return false
end

-- Everyone currently allowed to know about a drop.
--
-- A silent drop narrows this to admins only. That is the whole mechanism: the
-- blip, the announcements, the countdown and the police alert all read from
-- this list, so restricting it here makes the drop invisible everywhere at once
-- rather than needing a check in each of them.
local function viewers()
    local silent = Drop and Drop.silent
    local out = {}

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then
            local allowed = silent and isAdminSrc(src) or (not silent and canSee(src))
            if allowed then out[#out + 1] = src end
        end
    end
    return out
end

-- ── Location choice ──────────────────────────────────────────────────────────

-- Locations live in the database and are edited from the admin panel;
-- config.lua only seeded them on first run. Rows carry x/y/z rather than a
-- vec3, so they are normalised here once instead of at every call site.
local function asLocation(row)
    if not row then return nil end
    return {
        id = row.id,
        label = row.label,
        coords = vec3(row.x, row.y, row.z),
        weight = row.weight,
        radius = row.radius,
    }
end

local function pickLocation(forcedLabel)
    local locations = Data.Locations()
    if #locations == 0 then return nil end

    if forcedLabel then
        for i, loc in ipairs(locations) do
            if loc.label:lower():find(forcedLabel:lower(), 1, true) then
                lastLocationIndex = i
                return asLocation(loc)
            end
        end
        return nil
    end

    -- Never the same place twice running, whatever the weights say. Repeats
    -- are what make an event feel scripted.
    local pool, sum = {}, 0
    for i, loc in ipairs(locations) do
        if i ~= lastLocationIndex or #locations == 1 then
            pool[#pool + 1] = { index = i, loc = loc, weight = loc.weight or 1 }
            sum = sum + (loc.weight or 1)
        end
    end

    local roll, running = math.random() * sum, 0
    for _, entry in ipairs(pool) do
        running = running + entry.weight
        if roll <= running then
            lastLocationIndex = entry.index
            return asLocation(entry.loc)
        end
    end

    local fallback = pool[#pool]
    if fallback then
        lastLocationIndex = fallback.index
        return asLocation(fallback.loc)
    end
    return nil
end

-- The marker never moves. It sits on the real spot from announcement to
-- despawn and only the circle changes size: wide while inbound, tight once the
-- crate is down. Moving it meant driving somewhere and watching the zone
-- relocate on landing.
local function approximate(coords)
    return coords
end

-- ── Broadcasting ─────────────────────────────────────────────────────────────

-- What a client is allowed to know, by state. The exact coordinate is withheld
-- until the crate is actually on the ground.
local function publicState()
    if not Drop then return nil end

    local payload = {
        id = Drop.id,
        state = Drop.state,
        silent = Drop.silent or nil,
        label = Config.Announce.NameLocation and Drop.label or nil,
        -- A location may override the global radius, so a cramped yard can
        -- be tighter than an open field without changing both.
        zoneRadius = Drop.radius or Config.Drop.ZoneRadius,
        -- Durations, not timestamps. The client would otherwise have to
        -- compare os.time() here against GetCloudTimeAsInt() there, and those
        -- only agree when the server clock happens to be UTC. Seconds-from-now
        -- needs no clock agreement at all.
        landsIn = Drop.landsAt and math.max(0, Drop.landsAt - os.time()) or nil,
        expiresIn = Drop.expiresAt and math.max(0, Drop.expiresAt - os.time()) or nil,
    }

    if Drop.state == 'announced' or Drop.state == 'inbound' then
        payload.coords = Drop.approxCoords
        payload.approx = true
        payload.approxRadius = Config.Drop.ApproxBlipRadius
    else
        payload.coords = Drop.coords
        payload.approx = false
        payload.crackedBy = Drop.crackedByName
        payload.emptied = Drop.emptied or nil
    end

    return payload
end

-- Only to players allowed to know. Everyone else is told it ended, so changing
-- job mid-event drops the blip instead of leaving a stale one.
-- Nudges any open admin panel to re-read. Sent to everyone; the client ignores
-- it unless a panel is open. Must stay above broadcast(), which calls it.
local function refreshPanels()
    TriggerClientEvent('cipher-airdrops:client:refreshPanel', -1)
end

local function broadcast()
    local state = publicState()
    local allowed = {}

    refreshPanels()

    for _, src in ipairs(viewers()) do
        allowed[src] = true
        TriggerClientEvent('cipher-airdrops:client:sync', src, state)
    end

    if state then
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            if src and not allowed[src] then
                TriggerClientEvent('cipher-airdrops:client:sync', src, nil)
            end
        end
    end
end

local function announce(message)
    if not Config.Announce.ToEveryone then return end
    for _, src in ipairs(viewers()) do
        TriggerClientEvent('cipher-airdrops:client:announce', src, message)
    end
end

local function webhook(title, description)
    if Drop and Drop.silent then return end

    local url = Config.Announce.Webhook
    if not url or url == '' then return end

    PerformHttpRequest(url, function() end, 'POST', json.encode({
        embeds = { {
            title = title,
            description = description,
            color = 5814783,
            footer = { text = 'cipher-airdrops' },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

local function endDrop(reason)
    if not Drop then return end
    log('drop %s ended (%s)', Drop.id, reason)

    -- Whatever is still in the crate goes with it. The alternative is a stash
    -- per drop left in the database forever, still holding the loot nobody
    -- collected — and a despawning crate should take its contents with it
    -- anyway.
    if Drop.stashId then
        Inv.ClearStash(Drop.stashId)
    end

    Data.RecordEnd(Drop.historyId, reason)

    TriggerClientEvent('cipher-airdrops:client:sync', -1, nil)
    Drop = nil

    -- Schedule the next one from the moment this finished, not from when it
    -- started, so a long contested drop does not immediately trigger another.
    local sc = Config.Schedule
    if sc.Enabled then
        nextDropAt = os.time() + math.random(sc.MinInterval or 45, sc.MaxInterval or 90) * 60
    end
end

local function land()
    if not Drop or Drop.state ~= 'inbound' then return end

    Drop.state = 'landed'
    Drop.landedAt = os.time()
    Drop.expiresAt = os.time() + (Config.Drop.AbandonedAfter or 900)

    broadcast()
    announce(('The crate has landed%s.'):format(
        Config.Announce.NameLocation and (' near ' .. Drop.label) or ''))

    log('drop %s landed at %s', Drop.id, Drop.label)

    -- Police are told late on purpose. Whoever raced for the crate should get
    -- there first; law enforcement arriving into an existing fight is a better
    -- scene than law enforcement waiting at the coordinates.
    if Config.Police.Alert and not Drop.silent then
        SetTimeout((Config.Police.Delay or 45) * 1000, function()
            if Drop and (Drop.state == 'landed' or Drop.state == 'open') then
                TriggerClientEvent('cipher-airdrops:client:policeAlert', -1, {
                    coords = Drop.coords,
                    code = Config.Police.Code,
                    title = Config.Police.Title,
                    jobs = Config.Police.Jobs,
                })
            end
        end)
    end
end

local function startDrop(location, calledBy, opts)
    if Drop then return false, 'A drop is already active' end
    opts = opts or {}

    location = location or pickLocation()
    if not location then return false, 'No usable location in Config.Locations' end

    Drop = {
        id = ('%d-%d'):format(os.time(), math.random(1000, 9999)),
        label = location.label,
        coords = location.coords,
        approxCoords = approximate(location.coords),
        radius = location.radius,
        state = 'announced',
        landsAt = os.time() + (Config.Drop.WarningTime or 90),
        cracks = {},

        -- A test drop: real crate, real loot, real cracking — but only admins
        -- can see it, and it is kept out of the history and the webhook so a
        -- test does not pollute the numbers you tune against.
        silent = opts.silent == true,

        historyId = nil,

        -- A backstop, replaced with the real expiry once it lands. Without it,
        -- a drop that somehow never lands stays active forever and blocks
        -- every future drop, since only one runs at a time. Cheap insurance
        -- against a timer that did not fire.
        expiresAt = os.time() + (Config.Drop.WarningTime or 90) + 120,
    }

    if not Drop.silent then
        Drop.historyId = Data.RecordStart(Drop, calledBy)
    end

    broadcast()

    announce(('Supply drop inbound%s — %d seconds out.'):format(
        Config.Announce.NameLocation and (', ' .. Drop.label) or '',
        Config.Drop.WarningTime or 90))

    webhook('Supply drop inbound', ('**%s**%s'):format(
        Drop.label, calledBy and ('\nCalled by ' .. calledBy) or ''))

    log('drop %s announced for %s%s', Drop.id, Drop.label, calledBy and (' by ' .. calledBy) or '')

    SetTimeout((Config.Drop.WarningTime or 90) * 1000, function()
        if not Drop or Drop.state ~= 'announced' then return end
        Drop.state = 'inbound'
        broadcast()

        -- The flyover is cosmetic and runs on each client. The crate becomes
        -- real here regardless, so a client that cannot render the plane is
        -- not left out of the event.
        SetTimeout(Config.Delivery.Flyover and 12000 or 500, land)
    end)

    return true
end

-- ── Cracking ─────────────────────────────────────────────────────────────────
-- Anyone may start. First to finish opens it, and the server checks both ends:
-- you must have been near the crate when you started, still be near it when you
-- claim to have finished, and enough time must actually have passed.

-- Is anyone inside the contested zone? The expiry clock only runs out on an
-- empty one.
local function anyoneInZone()
    if not Drop or not Drop.coords then return false end

    local radius = Drop.radius or Config.Drop.ZoneRadius or 120.0

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ped = src and GetPlayerPed(src)

        if ped and ped ~= 0 then
            if #(GetEntityCoords(ped) - Drop.coords) <= radius then return true end
        end
    end
    return false
end

-- Someone part-way through the crack animation.
local function anyoneCracking()
    if not Drop or not Drop.cracks then return false end

    local cutoff = os.time() - ((Config.Drop.CrackTime or 25) + 5)
    for _, startedAt in pairs(Drop.cracks) do
        if startedAt >= cutoff then return true end
    end
    return false
end

local function nearCrate(src)
    if not Drop then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local pos = GetEntityCoords(ped)
    local reach = (Config.Drop.CrackDistance or 5.0) + 3.0

    -- Horizontal distance, height checked separately and loosely. The crate is
    -- placed on the ground under the stored point, which may itself have been
    -- captured on top of an embankment — a 3D check fails on that height
    -- difference alone. The crate never moves horizontally, so that is the axis
    -- worth being strict about.
    local flat = #(vector3(pos.x, pos.y, 0.0) - vector3(Drop.coords.x, Drop.coords.y, 0.0))
    local drop = math.abs(pos.z - Drop.coords.z)

    return flat <= reach and drop <= 25.0
end

RegisterNetEvent('cipher-airdrops:server:beginCrack', function()
    local src = source

    if not Drop or Drop.state ~= 'landed' then
        Framework.Notify(src, 'There is no crate to open.', 'error')
        return
    end

    -- The client measures to the crate prop and the server measures to the
    -- stored coordinate, so these can disagree by a metre or two. Saying so
    -- beats a progress bar that completes and does nothing.
    if not nearCrate(src) then
        Framework.Notify(src, 'You are not close enough to the crate.', 'error')
        return
    end

    if not canCollect(src) then
        Framework.Notify(src, Config.Access.DeniedMessage, 'error')
        return
    end

    Drop.cracks[src] = os.time()
    log('%s started cracking %s', GetPlayerName(src), Drop.id)
end)

RegisterNetEvent('cipher-airdrops:server:finishCrack', function()
    local src = source
    if not Drop or Drop.state ~= 'landed' then return end
    if not canCollect(src) then return end

    -- No record of them starting. Usually means beginCrack was refused, and
    -- that refusal already explained itself.
    local startedAt = Drop.cracks[src]
    if not startedAt then
        Framework.Notify(src, 'That did not count — start again at the crate.', 'error')
        return
    end

    -- A second of grace for latency, and no more. Without this check a client
    -- can simply send finishCrack immediately after beginCrack.
    local elapsed = os.time() - startedAt
    if elapsed < (Config.Drop.CrackTime or 25) - 1 then
        log('%s finished too fast (%ds) — ignored', GetPlayerName(src), elapsed)
        return
    end

    if not nearCrate(src) then return end

    Drop.state = 'open'
    Drop.crackedBy = src
    Drop.crackedByName = GetPlayerName(src)
    Drop.expiresAt = os.time() + (Config.Drop.OpenDuration or 300)
    Drop.stashId = 'airdrop_' .. Drop.id

    local rolled = Loot.Roll()
    Inv.RegisterStash(Drop.stashId, 'Supply Crate', Config.Loot.Slots, Config.Loot.MaxWeight)

    if Inv.CanPrefillStash() then
        for _, entry in ipairs(rolled) do
            Inv.AddToStash(Drop.stashId, entry.item, entry.count)
        end
        Drop.loot = nil
    else
        -- Backends that build a stash lazily get their contents when the first
        -- player opens it. Held here rather than dropped on the floor.
        Drop.loot = rolled
    end

    Data.RecordCrack(Drop.historyId, Framework.GetCitizenId(src), Drop.crackedByName, rolled)

    broadcast()
    announce(('%s has opened the crate.'):format(Drop.crackedByName))
    webhook('Crate opened', ('**%s** opened the crate at **%s**'):format(Drop.crackedByName, Drop.label))

    log('drop %s cracked by %s, %d stacks', Drop.id, Drop.crackedByName, #rolled)
end)

-- Looting is a separate check from cracking: the crate stays open to everyone
-- once cracked, so proximity is verified again here.
--
-- Two paths, because the inventories genuinely differ.
--
-- ox_inventory can be handed a filled container, so the crate is a real shared
-- stash: several people rummage in the same box and the inventory sorts out who
-- grabbed what. That is the version this script is designed around.
--
-- The other five backends only create a stash when a player opens one, and none
-- expose a reliable way to put items into a stash nobody has opened yet. Rather
-- than ship them an empty crate, the loot is handed out a few stacks at a time
-- to whoever is searching. It keeps the scramble — being first still matters,
-- and being second still gets you something.
-- ox_inventory hands the crate over as a real stash, so the server never sees
-- items leave. Polled only while one is open. Other backends already know,
-- because the server hands the loot out itself.
CreateThread(function()
    while true do
        Wait(4000)

        if Drop and Drop.state == 'open' and not Drop.emptied and Drop.stashId then
            -- nil means the backend cannot tell us, which is not the same as
            -- "not empty" and must not trigger anything.
            if Inv.StashIsEmpty(Drop.stashId) == true then markEmptied() end
        end
    end
end)

-- Cleaned out. Does NOT end the drop — the empty crate stays for
-- Config.Drop.EmptyLinger so late arrivals can see they missed it.
function markEmptied()
    if not Drop or Drop.emptied then return end

    Drop.emptied = true
    Drop.expiresAt = os.time() + (Config.Drop.EmptyLinger or 60)

    announce('The crate has been emptied.')
    broadcast()
    log('drop %s emptied — lingering %ds', Drop.id, Config.Drop.EmptyLinger or 60)
end

RegisterNetEvent('cipher-airdrops:server:loot', function()
    local src = source
    if not Drop or Drop.state ~= 'open' then return end
    if not nearCrate(src) then return end

    if not canCollect(src) then
        Framework.Notify(src, Config.Access.DeniedMessage, 'error')
        return
    end

    if Inv.CanPrefillStash() then
        TriggerClientEvent('cipher-airdrops:client:openStash', src, Drop.stashId, {
            slots = Config.Loot.Slots,
            maxWeight = Config.Loot.MaxWeight,
        })
        return
    end

    if not Drop.loot or #Drop.loot == 0 then
        Framework.Notify(src, 'The crate is empty.', 'error')
        return
    end

    local take = Config.Loot.StacksPerSearch or 2
    local given = 0

    for _ = 1, take do
        local entry = table.remove(Drop.loot, 1)
        if not entry then break end

        if Inv.CanCarry(src, entry.item, entry.count) and Inv.AddItem(src, entry.item, entry.count) then
            given = given + 1
        else
            -- Put it back at the front. A full player must not delete loot for
            -- everyone else by walking up to the crate.
            table.insert(Drop.loot, 1, entry)
            Framework.Notify(src, 'You cannot carry any more.', 'error')
            break
        end
    end

    if given > 0 then
        Framework.Notify(src, ('You pull %d item stack%s from the crate.'):format(
            given, given == 1 and '' or 's'), 'success')
    end

    if #Drop.loot == 0 then markEmptied() end
end)

-- qb-inventory and ps-inventory open stashes from the server.
RegisterNetEvent('cipher-airdrops:server:openStash', function(id)
    local src = source
    if not Drop or Drop.stashId ~= id or Drop.state ~= 'open' then return end
    if not nearCrate(src) then return end

    if Inv.name == 'qb-inventory' then
        exports['qb-inventory']:OpenInventory(src, id, {
            label = 'Supply Crate',
            maxweight = Config.Loot.MaxWeight,
            slots = Config.Loot.Slots,
        })
    elseif Inv.name == 'ps-inventory' then
        TriggerClientEvent('ps-inventory:client:openStash', src, id)
    end
end)

-- ── Scheduling ───────────────────────────────────────────────────────────────

-- Server local time, not in-game time. A server owner setting an hour window
-- means "when my players are awake", which is a wall-clock question.
local function withinHours()
    local h = Config.Schedule.Hours
    if not h or not h.from or not h.to then return true end

    local hour = tonumber(os.date('%H'))
    if h.from <= h.to then
        return hour >= h.from and hour < h.to
    end
    -- Window crossing midnight, e.g. 18 → 4.
    return hour >= h.from or hour < h.to
end

CreateThread(function()
    -- Wait for the database, or the first interval is picked from config.lua
    -- and any saved override is ignored until the next drop.
    while not Data.ready do Wait(250) end

    local sc = Config.Schedule
    if not sc.Enabled then return end

    nextDropAt = os.time() + math.random(sc.MinInterval or 45, sc.MaxInterval or 90) * 60

    while true do
        Wait(30000)

        if not Drop and os.time() >= nextDropAt then
            if playerCount() < (sc.MinPlayers or 1) then
                -- Try again shortly rather than skipping the slot entirely,
                -- or a server that fills up late never gets a drop at all.
                nextDropAt = os.time() + 300
                log('too few players (%d/%d), retrying in 5m', playerCount(), sc.MinPlayers)
            elseif not withinHours() then
                nextDropAt = os.time() + 600
            else
                startDrop()
            end
        end
    end
end)

-- ── Admin command ────────────────────────────────────────────────────────────

if Config.AdminCommand.Enabled then
    RegisterCommand(Config.AdminCommand.Command, function(src, args)
        -- Console always allowed.
        if src > 0 then
            local allowed = Framework.IsAdmin(src)
            for _, ace in ipairs(Config.AdminCommand.Aces or {}) do
                if IsPlayerAceAllowed(src, ace) then allowed = true break end
            end
            if not allowed then
                Framework.Notify(src, 'You do not have permission to call a drop.', 'error')
                return
            end
        end

        local wanted = args[1] and table.concat(args, ' ') or nil
        local location = wanted and pickLocation(wanted) or nil

        if wanted and not location then
            local msg = ('No location matching "%s".'):format(wanted)
            if src > 0 then Framework.Notify(src, msg, 'error') else print(msg) end
            return
        end

        local ok, err = startDrop(location, src > 0 and GetPlayerName(src) or 'Console')
        if not ok then
            if src > 0 then Framework.Notify(src, err, 'error') else print(err) end
        end
    end, false)
end

-- ── Housekeeping ─────────────────────────────────────────────────────────────

-- Expiry. Cleanup for crates nobody came for, not a countdown that deletes the
-- event under the people playing it: if anyone is there it holds for another
-- PresenceGrace, up to MaxLifetime.
CreateThread(function()
    while true do
        Wait(5000)

        if Drop and Drop.expiresAt and os.time() >= Drop.expiresAt then
            local since = Drop.landedAt or Drop.startedAt or os.time()
            local cap = Config.Drop.MaxLifetime or 0
            local pastCap = cap > 0 and (os.time() - since) >= cap

            -- Nothing left to protect once it is empty, so the linger is a hard
            -- timer. Holding an empty box open because someone is stood beside
            -- it just delays the tidy-up.
            if not pastCap and not Drop.emptied
                and (anyoneInZone() or anyoneCracking()) then
                Drop.expiresAt = os.time() + (Config.Drop.PresenceGrace or 120)
                Drop.heldOpen = true

                -- Clients are told, so the countdown reflects the new deadline
                -- rather than sitting at zero.
                broadcast()
                log('drop %s held — someone is still there', Drop.id)
            else
                if pastCap then log('drop %s hit MaxLifetime', Drop.id) end
                endDrop(Drop.emptied and 'emptied'
                    or (Drop.state == 'open' and 'looted out' or 'abandoned'))
            end
        end
    end
end)

-- A player who joins mid-event should see it.
RegisterNetEvent('cipher-airdrops:server:requestSync', function()
    TriggerClientEvent('cipher-airdrops:client:sync', source, publicState())
end)

AddEventHandler('playerDropped', function()
    if Drop and Drop.cracks then Drop.cracks[source] = nil end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and Drop then
        TriggerClientEvent('cipher-airdrops:client:sync', -1, nil)
    end
end)

CreateThread(function()
    Wait(1000)
    Data.Init()

    -- After Data.Init, because a saved GuaranteeAtLeast is validated against the
    -- tier list, and before the scheduler runs, because it reads the interval.
    Settings.Load()

    Loot.Validate()
    print(('^2[cipher-airdrops]^0 v%s loaded · framework=%s · inventory=%s · %d locations'):format(
        GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?',
        Framework.name or 'NONE', Inv.name or 'NONE', #Data.Locations()))
end)

-- ── API for server/admin.lua and other resources ─────────────────────────────

function Airdrops.Active()
    return Drop ~= nil
end

function Airdrops.PublicState()
    return publicState()
end

function Airdrops.Start(location, calledBy, opts)
    return startDrop(location, calledBy, opts)
end

function Airdrops.Cancel(reason)
    endDrop(reason or 'cancelled')
end

-- Seconds until the scheduler fires, or nil when it is switched off.
function Airdrops.NextDropIn()
    if not Config.Schedule.Enabled then return nil end
    return math.max(0, nextDropAt - os.time())
end

exports('IsDropActive', Airdrops.Active)
exports('GetDrop', function() return Drop and publicState() or nil end)
exports('StartDrop', function(label) return startDrop(label and pickLocation(label) or nil, 'Export') end)
