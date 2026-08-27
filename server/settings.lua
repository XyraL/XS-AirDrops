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

local function split(key)
    local section, name = key:match('^([^.]+)%.(.+)$')
    return section, name
end

local function readConfig(key)
    local section, name = split(key)
    if not section or not Config[section] then return nil end
    return Config[section][name]
end

local function writeConfig(key, value)
    local section, name = split(key)
    if not section or not Config[section] then return false end
    Config[section][name] = value
    return true
end

-- ── Coercion ─────────────────────────────────────────────────────────────────
-- Values arrive from the panel as strings and are stored as text, so both ends
-- have to agree on what a boolean looks like.

local function coerce(entry, raw)
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
    return tostring(value)
end

-- ── Load ─────────────────────────────────────────────────────────────────────

function Settings.Load()
    for _, entry in ipairs(Settings.SCHEMA) do
        defaults[entry.key] = readConfig(entry.key)
    end

    local rows = MySQL.query.await('SELECT `key`, `value` FROM cipher_airdrop_settings') or {}
    local applied = 0

    for _, row in ipairs(rows) do
        local entry = byKey[row.key]
        if entry then
            local value = coerce(entry, row.value)
            if value ~= nil and writeConfig(row.key, value) then applied = applied + 1 end
        end
    end

    if applied > 0 then
        print(('^2[cipher-airdrops]^0 applied %d saved setting%s over config.lua')
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
        INSERT INTO cipher_airdrop_settings (`key`, `value`, changed_by)
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

    MySQL.query.await('DELETE FROM cipher_airdrop_settings WHERE `key` = ?', { key })
    writeConfig(key, defaults[key])
    Settings.Push()

    return true
end

-- ── For the panel ────────────────────────────────────────────────────────────

function Settings.List()
    local out = {}

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
            value = current,
            default = defaults[entry.key],
            -- Compared as text so 90 and 90.0 do not read as different.
            modified = tostring(current) ~= tostring(defaults[entry.key]),
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
    'Delivery.Flyover', 'Delivery.CrateModel',
    'Sounds.Enabled', 'Sounds.CountdownTicks',
}

local function clientPayload()
    local out = {}
    for _, key in ipairs(CLIENT_KEYS) do out[key] = readConfig(key) end
    return out
end

function Settings.Push(target)
    TriggerClientEvent('cipher-airdrops:client:settings', target or -1, clientPayload())
end

RegisterNetEvent('cipher-airdrops:server:requestSettings', function()
    Settings.Push(source)
end)
