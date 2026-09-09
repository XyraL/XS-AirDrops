-- Runtime settings.
--
-- The panel edits the numbers you actually want to nudge while watching a drop
-- play out — how long the warning is, how long cracking takes, how big the zone
-- is. Editing config.lua for those means a file change and a restart, which is
-- the wrong shape of tool for "that felt about ten seconds too long".
--
-- How it fits together: config.lua is still the default for everything. Only
-- settings you have actually changed are stored, and on boot those are applied
-- ON TOP of the Config table in memory. Every existing `Config.Drop.CrackTime`
-- read therefore keeps working untouched — there is no Settings.Get() threaded
-- through the codebase, because that would have meant editing every call site
-- and getting one wrong.
Settings = {}

-- What the panel is allowed to change, and what counts as a sane value.
--
-- This table is the single definition: it drives the panel's fields, the
-- validation, and the reset-to-default. Adding a setting is one entry here.
Settings.SCHEMA = {
    -- ── Schedule ──
    { key = 'Schedule.Enabled',        group = 'Schedule', type = 'bool',
      label = 'Automatic drops',
      help  = 'Off means drops only happen when someone calls one.' },

    { key = 'Schedule.MinInterval',    group = 'Schedule', type = 'number', min = 5, max = 480, unit = 'min',
      label = 'Minimum gap',
      help  = 'The gap is randomised between these two, so players cannot set a timer by it.' },

    { key = 'Schedule.MaxInterval',    group = 'Schedule', type = 'number', min = 5, max = 480, unit = 'min',
      label = 'Maximum gap' },

    { key = 'Schedule.MinPlayers',     group = 'Schedule', type = 'number', min = 0, max = 256,
      label = 'Players needed',
      help  = 'A crate that lands for one person to free-loot is worse than no crate.' },

    -- ── Timings ──
    { key = 'Drop.WarningTime',        group = 'Timings', type = 'number', min = 15, max = 900, unit = 's',
      label = 'Warning window',
      help  = 'Time between the announcement and the plane arriving. This is the window players travel in — too short and only whoever was already nearby can contest it.' },

    { key = 'Drop.CrackTime',          group = 'Timings', type = 'number', min = 3, max = 180, unit = 's',
      label = 'Crack time',
      help  = 'How long you stand exposed at the crate. This is the number that decides whether a drop is contested or just a race.' },

    { key = 'Drop.OpenDuration',       group = 'Timings', type = 'number', min = 30, max = 3600, unit = 's',
      label = 'Stays open for',
      help  = 'How long an opened crate can be looted before it despawns.' },

    { key = 'Drop.AbandonedAfter',     group = 'Timings', type = 'number', min = 60, max = 7200, unit = 's',
      label = 'Give up after',
      help  = 'How long an uncracked crate waits. This clock only runs out on an empty zone — if anyone is there when it expires, the crate is held instead.' },

    { key = 'Drop.EmptyLinger',        group = 'Timings', type = 'number', min = 0, max = 900, unit = 's',
      label = 'Empty crate stays for',
      help  = 'An emptied crate lingers this long instead of vanishing the moment the last item leaves. Anyone still on their way sees they were too late, and a fight over it does not lose the thing it was about.' },

    { key = 'Drop.PresenceGrace',      group = 'Timings', type = 'number', min = 0, max = 900, unit = 's',
      label = 'Hold it for',
      help  = 'Extra time given when the crate would have expired but somebody is in the zone or mid-crack. Applied again each time, so it outlives anyone actually using it.' },

    { key = 'Drop.MaxLifetime',        group = 'Timings', type = 'number', min = 0, max = 86400, unit = 's',
      label = 'Gone regardless after',
      help  = 'The stop on holding. Measured from landing. 0 means no cap, and one player standing in the zone can keep a crate alive all night.' },

    -- ── Area ──
    { key = 'Drop.ZoneRadius',         group = 'Area', type = 'number', min = 20, max = 600, unit = 'm',
      label = 'Contested radius',
      help  = 'The red circle drawn once the crate lands. Locations can override this individually.' },

    { key = 'Drop.ApproxBlipRadius',   group = 'Area', type = 'number', min = 0, max = 1500, unit = 'm',
      label = 'Search radius',
      help  = 'How vague the first blip is. Zero gives the exact spot away at announcement.' },

    { key = 'Drop.HudDistance',        group = 'Area', type = 'number', min = 0, max = 3000, unit = 'm',
      label = 'Show the on-screen status within',
      help  = 'How close you must be before the drop status appears on screen. A banner for something across the map is clutter. Inside the zone always shows it. 0 keeps it on screen the whole time.' },

    { key = 'Drop.CrackDistance',      group = 'Area', type = 'number', min = 1, max = 15, unit = 'm',
      label = 'Reach',
      help  = 'How close you must be to crack or loot. The server re-checks this, so a teleport does not help.' },

    -- ── Loot ──
    { key = 'Loot.MinStacks',          group = 'Loot', type = 'number', min = 1, max = 24,
      label = 'Fewest stacks' },

    { key = 'Loot.MaxStacks',          group = 'Loot', type = 'number', min = 1, max = 24,
      label = 'Most stacks' },

    { key = 'Loot.StacksPerSearch',    group = 'Loot', type = 'number', min = 1, max = 12,
      label = 'Stacks per search',
      help  = 'Only used on inventories that cannot be handed a pre-filled crate — everything except ox_inventory.' },

    { key = 'Loot.GuaranteeAtLeast',   group = 'Loot', type = 'text',
      label = 'Guarantee at least',
      help  = 'A tier name. One roll is forced up to that tier or better, so a crate is never entirely bandages after a five-minute fight. Blank to disable.' },

    { key = 'Loot.Slots',              group = 'Loot', type = 'number', min = 1, max = 60,
      label = 'Crate slots',
      help  = 'How many inventory slots the crate has. ox_inventory only.' },

    { key = 'Loot.MaxWeight',          group = 'Loot', type = 'number', min = 1000, max = 2000000,
      label = 'Crate capacity',
      help  = 'Total weight the crate holds, in grams. ox_inventory only.' },

    -- ── Access ──
    { key = 'Access.See.Everyone',     group = 'Access', type = 'bool',
      label = 'Everyone sees drops',
      help  = 'Off restricts announcements and the blip to the jobs and gangs below. Police are handled separately.' },

    { key = 'Access.See.Jobs',         group = 'Access', type = 'list',
      label = 'Jobs that can see',
      help  = 'Comma separated. Only used when the switch above is off.' },

    { key = 'Access.See.Gangs',        group = 'Access', type = 'list',
      label = 'Gangs that can see' },

    { key = 'Access.Collect.Everyone', group = 'Access', type = 'bool',
      label = 'Everyone can collect',
      help  = 'Off means only the jobs and gangs below can crack and loot a crate.' },

    { key = 'Access.Collect.Jobs',     group = 'Access', type = 'list',
      label = 'Jobs that can collect' },

    { key = 'Access.Collect.Gangs',    group = 'Access', type = 'list',
      label = 'Gangs that can collect' },

    { key = 'Access.Police.Jobs',      group = 'Access', type = 'list',
      label = 'Police jobs',
      help  = 'Which jobs count as police for the two rules below.' },

    { key = 'Access.Police.CanSee',    group = 'Access', type = 'bool',
      label = 'Police always see drops',
      help  = 'On means officers are told about every drop even when everything else is restricted.' },

    { key = 'Access.Police.CanCollect', group = 'Access', type = 'bool',
      label = 'Police can loot',
      help  = 'Off turns police into responders rather than another gang: they see the drop and turn up, but cannot take from it.' },

    { key = 'Access.DeniedMessage',    group = 'Access', type = 'text',
      label = 'Refusal message',
      help  = 'Shown to someone who tries to open a crate they are not allowed to. Saying nothing reads as the script being broken.' },

    -- ── Police ──
    { key = 'Police.Alert',            group = 'Police', type = 'bool',
      label = 'Alert police' },

    { key = 'Police.Delay',            group = 'Police', type = 'number', min = 0, max = 900, unit = 's',
      label = 'Alert delay',
      help  = 'Time after landing before police are told. The delay is what lets whoever raced for the crate get there first.' },

    -- ── Presentation ──
    { key = 'Announce.ToEveryone',     group = 'Presentation', type = 'bool',
      label = 'Text announcements',
      help  = 'Off leaves the blip and countdown but removes the notifications.' },

    { key = 'Announce.NameLocation',   group = 'Presentation', type = 'bool',
      label = 'Name the area',
      help  = 'Off makes drops much harder to find and heavily favours whoever happens to be nearby.' },

    { key = 'Delivery.CrateModel',     group = 'Presentation', type = 'text',
      label = 'Crate prop',
      help  = 'Model name for the crate. Falls back to prop_mil_crate_01 if it will not load, rather than spawning nothing.' },

    { key = 'Delivery.Flyover',        group = 'Presentation', type = 'bool',
      label = 'Plane flyover',
      help  = 'Off makes the crate simply appear. Far less interesting, but costs nothing to render.' },

    { key = 'Sounds.Enabled',          group = 'Presentation', type = 'bool',
      label = 'Sound cues' },

    { key = 'Police.Code',             group = 'Police', type = 'text',
      label = 'Dispatch code',
      help  = 'The code attached to the police alert, e.g. 10-90.' },

    { key = 'Police.Title',            group = 'Police', type = 'text',
      label = 'Dispatch title' },

    { key = 'Police.Jobs',             group = 'Police', type = 'list',
      label = 'Jobs alerted',
      help  = 'Which jobs receive the dispatch call when a crate lands.' },

    -- ── Notifications ──
    { key = 'NotifyStyle.title',       group = 'Notifications', type = 'text',
      label = 'Notification title' },

    { key = 'NotifyStyle.icon',        group = 'Notifications', type = 'text',
      label = 'Icon',
      help  = 'Font Awesome name, e.g. parachute-box. Depends on your notify resource.' },

    { key = 'NotifyStyle.position',    group = 'Notifications', type = 'text',
      label = 'Position',
      help  = 'top, top-right, bottom, bottom-right and so on. Depends on your notify resource.' },

    { key = 'NotifyStyle.duration',    group = 'Notifications', type = 'number', min = 1000, max = 30000,
      label = 'On screen for',
      unit = 'ms' },

    -- ── Aircraft ──
    { key = 'Delivery.PlaneModel',     group = 'Aircraft', type = 'text',
      label = 'Plane model' },

    { key = 'Delivery.Altitude',       group = 'Aircraft', type = 'number', min = 50, max = 1500, unit = 'm',
      label = 'Flight altitude',
      help  = 'Higher looks better from the ground and takes longer to arrive on screen.' },

    { key = 'Delivery.PlaneSpeed',     group = 'Aircraft', type = 'number', min = 10, max = 300,
      label = 'Plane speed' },

    { key = 'Delivery.SpawnDistance',  group = 'Aircraft', type = 'number', min = 200, max = 3000, unit = 'm',
      label = 'Spawns this far out',
      help  = 'How far from the drop the plane appears and disappears.' },

    -- ── Map ──
    { key = 'Blip.Sprite',             group = 'Map', type = 'number', min = 1, max = 900,
      label = 'Blip icon',
      help  = 'FiveM blip sprite id. 478 is a crate.' },

    { key = 'Blip.Colour',             group = 'Map', type = 'number', min = 0, max = 85,
      label = 'Blip colour',
      help  = 'FiveM blip colour id. 1 red, 5 yellow, 2 green.' },

    { key = 'Blip.Scale',              group = 'Map', type = 'number', min = 0.1, max = 3,
      label = 'Blip size' },

    { key = 'Blip.ShowRadius',         group = 'Map', type = 'bool',
      label = 'Draw the zone circle',
      help  = 'Off leaves a pin with no area around it, which makes a drop much harder to find.' },

    { key = 'Blip.RadiusColour',       group = 'Map', type = 'number', min = 0, max = 85,
      label = 'Zone colour',
      help  = 'The contested area once the crate is down. Red by default.' },

    { key = 'Blip.RadiusAlpha',        group = 'Map', type = 'number', min = 10, max = 255,
      label = 'Zone opacity' },

    { key = 'Blip.ApproxColour',       group = 'Map', type = 'number', min = 0, max = 85,
      label = 'Search area colour',
      help  = 'The wider circle shown while the drop is still inbound. Deliberately a different colour from the live zone.' },

    { key = 'Blip.ApproxAlpha',        group = 'Map', type = 'number', min = 10, max = 255,
      label = 'Search area opacity' },

    { key = 'Sounds.CountdownTicks',   group = 'Presentation', type = 'bool',
      label = 'Countdown ticks',
      help  = 'The last ten seconds tick audibly. The cue people tire of first, so it is separately switchable.' },
}

local byKey = {}
for _, entry in ipairs(Settings.SCHEMA) do byKey[entry.key] = entry end

-- The values config.lua shipped with, captured before anything is applied over
-- the top. This is what "reset to default" restores — the file's value, not a
-- snapshot of whatever the setting happened to be at some point.
local defaults = {}

-- ── Reading and writing dotted keys on Config ────────────────────────────────

-- Walks a dotted key to the table holding it, and the final field name.
-- Handles any depth: Drop.CrackTime, and Access.See.Jobs alike.
local function resolve(key)
    local parts = {}
    for part in key:gmatch('[^.]+') do parts[#parts + 1] = part end
    if #parts < 2 then return nil, nil end

    local node = Config
    for i = 1, #parts - 1 do
        node = node[parts[i]]
        if type(node) ~= 'table' then return nil, nil end
    end

    return node, parts[#parts]
end

local function readConfig(key)
    local node, name = resolve(key)
    if not node then return nil end
    return node[name]
end

local function writeConfig(key, value)
    local node, name = resolve(key)
    if not node then return false end
    node[name] = value
    return true
end

-- ── Coercion ─────────────────────────────────────────────────────────────────
-- Values arrive from the panel as strings and are stored as text, so both ends
-- have to agree on what a boolean looks like.

local function coerce(entry, raw)
    -- Comma-separated in, Lua array out. Empty means an empty list, which is a
    -- meaningful value here — "no jobs may collect" is a real setting.
    if entry.type == 'list' then
        local out = {}
        for item in tostring(raw or ''):gmatch('[^,]+') do
            local trimmed = item:match('^%s*(.-)%s*$')
            if trimmed ~= '' then out[#out + 1] = trimmed end
        end
        return out
    end

    if entry.type == 'bool' then
        if type(raw) == 'boolean' then return raw end
        return raw == 'true' or raw == '1' or raw == 1
    end

    if entry.type == 'number' then
        local n = tonumber(raw)
        if not n then return nil, 'Not a number' end
        if entry.min and n < entry.min then return nil, ('Minimum is %s'):format(entry.min) end
        if entry.max and n > entry.max then return nil, ('Maximum is %s'):format(entry.max) end
        return n
    end

    local text = tostring(raw or ''):sub(1, 120)
    return text
end

local function serialise(entry, value)
    if entry.type == 'bool' then return value and 'true' or 'false' end
    if entry.type == 'list' then return table.concat(value or {}, ', ') end
    return tostring(value)
end

-- ── Load ─────────────────────────────────────────────────────────────────────

function Settings.Load()
    for _, entry in ipairs(Settings.SCHEMA) do
        local value = readConfig(entry.key)

        -- Lists are copied, not referenced. Reset writes the default straight
        -- back into Config, and handing over the same table would make the
        -- "default" whatever it was last changed to.
        if type(value) == 'table' then
            local copy = {}
            for i, item in ipairs(value) do copy[i] = item end
            value = copy
        end

        defaults[entry.key] = value
    end

    local rows = MySQL.query.await('SELECT `key`, `value` FROM xs_airdrop_settings') or {}
    local applied = 0

    for _, row in ipairs(rows) do
        local entry = byKey[row.key]
        if entry then
            local value = coerce(entry, row.value)
            if value ~= nil and writeConfig(row.key, value) then applied = applied + 1 end
        end
    end

    if applied > 0 then
        print(('^2[XS-AirDrops]^0 applied %d saved setting%s over config.lua')
            :format(applied, applied == 1 and '' or 's'))
    end
end

-- ── Change ───────────────────────────────────────────────────────────────────

-- Cross-field rules. Individual bounds live in the schema; these are the pairs
-- that only make sense relative to each other.
local function crossCheck(key, value)
    local minInterval = key == 'Schedule.MinInterval' and value or Config.Schedule.MinInterval
    local maxInterval = key == 'Schedule.MaxInterval' and value or Config.Schedule.MaxInterval
    if minInterval > maxInterval then
        return false, 'The minimum gap cannot be longer than the maximum'
    end

    local minStacks = key == 'Loot.MinStacks' and value or Config.Loot.MinStacks
    local maxStacks = key == 'Loot.MaxStacks' and value or Config.Loot.MaxStacks
    if minStacks > maxStacks then
        return false, 'Fewest stacks cannot be more than most stacks'
    end

    if key == 'Loot.GuaranteeAtLeast' and value ~= '' then
        local found = false
        for _, tier in ipairs(Data.Tiers()) do
            if tier.name == value then found = true break end
        end
        if not found then
            return false, ('There is no enabled tier called "%s"'):format(value)
        end
    end

    return true
end

function Settings.Set(key, raw, byName)
    local entry = byKey[key]
    if not entry then return false, 'Unknown setting' end

    local value, err = coerce(entry, raw)
    if value == nil then return false, err or 'Invalid value' end

    local ok, why = crossCheck(key, value)
    if not ok then return false, why end

    MySQL.insert.await([[
        INSERT INTO xs_airdrop_settings (`key`, `value`, changed_by)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `value` = VALUES(`value`), changed_by = VALUES(changed_by)
    ]], { key, serialise(entry, value), byName })

    writeConfig(key, value)
    Settings.Push()

    return true
end

function Settings.Reset(key)
    local entry = byKey[key]
    if not entry then return false, 'Unknown setting' end

    MySQL.query.await('DELETE FROM xs_airdrop_settings WHERE `key` = ?', { key })
    writeConfig(key, defaults[key])
    Settings.Push()

    return true
end

-- ── For the panel ────────────────────────────────────────────────────────────

function Settings.List()
    local out = {}

    local function display(entry, value)
        if entry.type == 'list' then return table.concat(value or {}, ', ') end
        return value
    end

    local function same(entry, a, b)
        if entry.type == 'list' then
            return table.concat(a or {}, ',') == table.concat(b or {}, ',')
        end
        return tostring(a) == tostring(b)
    end

    for _, entry in ipairs(Settings.SCHEMA) do
        local current = readConfig(entry.key)
        out[#out + 1] = {
            key = entry.key,
            group = entry.group,
            type = entry.type,
            label = entry.label,
            help = entry.help,
            unit = entry.unit,
            min = entry.min,
            max = entry.max,
            value = display(entry, current),
            default = display(entry, defaults[entry.key]),
            -- Compared as text so 90 and 90.0 do not read as different, and
            -- element-wise for lists, whose identity would never match.
            modified = not same(entry, current, defaults[entry.key]),
        }
    end

    return out
end

-- ── Client sync ──────────────────────────────────────────────────────────────
-- Several of these are read on the client — crack time and reach, whether the
-- plane flies, whether sounds play. Config is a shared script, so the client
-- starts with the file's values and would otherwise never learn about a change
-- until the next resource restart.

local CLIENT_KEYS = {
    'Drop.CrackTime', 'Drop.CrackDistance', 'Drop.ZoneRadius', 'Drop.ApproxBlipRadius',
    'Drop.HudDistance',

    'Delivery.Flyover', 'Delivery.CrateModel', 'Delivery.PlaneModel',
    'Delivery.Altitude', 'Delivery.PlaneSpeed', 'Delivery.SpawnDistance',

    'Blip.Sprite', 'Blip.Colour', 'Blip.Scale', 'Blip.ShowRadius',
    'Blip.RadiusColour', 'Blip.RadiusAlpha', 'Blip.ApproxColour', 'Blip.ApproxAlpha',

    'NotifyStyle.title', 'NotifyStyle.icon', 'NotifyStyle.position', 'NotifyStyle.duration',

    'Sounds.Enabled', 'Sounds.CountdownTicks',
}

local function clientPayload()
    local out = {}
    for _, key in ipairs(CLIENT_KEYS) do out[key] = readConfig(key) end
    return out
end

function Settings.Push(target)
    TriggerClientEvent('XS-AirDrops:client:settings', target or -1, clientPayload())
end

RegisterNetEvent('XS-AirDrops:server:requestSettings', function()
    Settings.Push(source)
end)
