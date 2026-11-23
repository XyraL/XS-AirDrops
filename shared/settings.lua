Settings = { fields = {}, byKey = {} }

local POSITIONS = { 'top', 'top-right', 'top-left', 'bottom', 'bottom-right', 'bottom-left', 'center-right', 'center-left' }
local SEE = { 'everyone', 'only', 'except' }
local OPEN = { 'key', 'target' }

Settings.Sections = {
    { id = 'schedule', icon = 'clock', label = 'Schedule', help = 'When drops happen on their own.', fields = {
        { 'Schedule.Enabled', 'bool', default = true, label = 'Automatic drops', help = 'Off means drops only happen when staff call one.' },
        { 'Schedule.MinInterval', 'int', min = 5, max = 480, unit = 'min', default = 45, needs = 'Schedule.Enabled', label = 'Shortest gap', help = 'The gap is random between these two, so nobody can set a timer by it.' },
        { 'Schedule.MaxInterval', 'int', min = 5, max = 480, unit = 'min', default = 90, needs = 'Schedule.Enabled', label = 'Longest gap' },
        { 'Schedule.MinPlayers', 'int', min = 0, max = 256, default = 8, needs = 'Schedule.Enabled', label = 'Players online', help = 'No drop with fewer people on. A crate for one person to free-loot is worse than none.' },
        { 'Schedule.Hours.from', 'hour', default = -1, needs = 'Schedule.Enabled', label = 'Active from', help = 'Server time, not game time. Any time on both means all day.' },
        { 'Schedule.Hours.to', 'hour', default = -1, needs = 'Schedule.Enabled', label = 'Active until' },
        { 'Schedule.MaxActive', 'int', min = 1, max = 10, default = 1, label = 'Drops at once', help = 'How many can run at the same time. Staff drops count too.' },
        { 'Schedule.ZoneCooldown', 'int', min = 0, max = 1440, unit = 'min', default = 0, label = 'Zone cooldown', help = 'A zone rests this long before it can be picked again. 0 = only never twice in a row.' },
        { 'Drop.WarningTime', 'int', min = 15, max = 900, unit = 's', default = 90, label = 'Warning time', help = 'From the announcement to the crate landing. This is when people decide to go, gear up and travel.' },
    } },
    { id = 'timings', icon = 'gauge', label = 'Timings', help = 'How long a crate sticks around.', fields = {
        { 'Drop.OpenDuration', 'int', min = 30, max = 3600, unit = 's', default = 300, label = 'Stays open for', help = 'How long an opened crate can be looted before it goes.' },
        { 'Drop.AbandonedAfter', 'int', min = 60, max = 7200, unit = 's', default = 900, label = 'Give up after', help = 'How long an unopened crate waits. Only runs out when nobody is in the zone.' },
        { 'Drop.EmptyLinger', 'int', min = 0, max = 900, unit = 's', default = 60, label = 'Empty crate stays for', help = 'So late arrivals can see they missed it.' },
        { 'Drop.PresenceGrace', 'int', min = 0, max = 900, unit = 's', default = 120, label = 'Hold it for', help = 'Extra time each time it would expire with someone still in the zone.' },
        { 'Drop.MaxLifetime', 'int', min = 0, max = 86400, unit = 's', default = 3600, label = 'Gone no matter what after', help = 'Counted from landing. 0 = no cap.' },
    } },
    { id = 'area', icon = 'crosshair', label = 'Area', help = 'Circles on the map and the on-screen timer.', fields = {
        { 'Drop.ZoneRadius', 'num', min = 20, max = 600, step = 5, unit = 'm', default = 120.0, label = 'Contest radius', help = 'The red circle once the crate lands. Zones can set their own.' },
        { 'Drop.ApproxBlipRadius', 'num', min = 0, max = 1500, step = 10, unit = 'm', default = 250.0, label = 'Search radius', help = 'The wide yellow circle while it is inbound. Zones can set their own.' },
        { 'Drop.HudDistance', 'num', min = 0, max = 3000, step = 10, unit = 'm', default = 400.0, label = 'Show the timer within', help = 'The on-screen status only shows this close. 0 = always.' },
    } },
    { id = 'opening', icon = 'unlock', label = 'Opening', help = 'How players open and search a crate. Who may open it is under Who takes part.', fields = {
        { 'Drop.OpenWith', 'select', options = OPEN, labels = { key = 'Press E at the crate', target = 'Target script' }, default = 'key', label = 'Open the crate with', help = 'Target needs ox_target or qb-target running. Without one, players get the E prompt.' },
        { 'Drop.CrackDistance', 'num', min = 1, max = 15, step = 0.5, unit = 'm', default = 5.0, label = 'Reach', help = 'How close you must be to open or search the crate. The server checks it too.' },
    } },
    { id = 'access', icon = 'shield', label = 'Who takes part', help = 'Who sees drops and the default rule for who can open them.', fields = {
        { 'Access.See.Mode', 'select', options = SEE, labels = { everyone = 'Everyone', only = 'Only those listed', except = 'Everyone except those listed' }, default = 'everyone', label = 'Who sees drops', help = 'The blip, the circles, the messages and the crate itself. Zones can set their own. Players left out are never sent where a drop is.' },
        { 'Access.See.Jobs', 'list', slug = true, default = {}, needs = 'Access.See.Mode!=everyone', label = 'Jobs on the list', help = 'Who the rule above lets in, or leaves out.' },
        { 'Access.See.Gangs', 'list', slug = true, default = {}, needs = 'Access.See.Mode!=everyone', label = 'Gangs on the list' },
        { 'Access.Collect.Everyone', 'bool', default = true, label = 'Everyone can open', help = 'The default rule. Crate types can set their own.' },
        { 'Access.Collect.Jobs', 'list', slug = true, default = {}, needs = '!Access.Collect.Everyone', label = 'Jobs that can open' },
        { 'Access.Collect.Gangs', 'list', slug = true, default = {}, needs = '!Access.Collect.Everyone', label = 'Gangs that can open' },
        { 'Access.Police.Jobs', 'list', slug = true, default = { 'police', 'sheriff', 'sasp' }, label = 'Police jobs', help = 'Which jobs count as police for the two rules below.' },
        { 'Access.Police.CanSee', 'bool', default = true, label = 'Police always see drops', help = 'Officers are told about every drop, even when only some jobs and gangs see it. Everyone except still hides it from a police job on its list.' },
        { 'Access.Police.CanCollect', 'bool', default = true, label = 'Police can loot', help = 'Off makes police responders instead of another gang. Crate types can override it.' },
        { 'Access.DeniedMessage', 'text', max = 120, default = 'You have no idea how to open this.', label = 'Refusal message', help = 'Shown to someone not allowed to open a crate.' },
    } },
    { id = 'police', icon = 'badge', label = 'Police alert', help = 'Each crate type decides whether police get called, and how late.', fields = {
        { 'Police.Jobs', 'list', slug = true, default = { 'police', 'sheriff', 'sasp' }, label = 'Jobs alerted', help = 'Also used for the minimum police a zone can ask for.' },
        { 'Police.Code', 'text', max = 16, default = '10-66', label = 'Dispatch code' },
        { 'Police.Title', 'text', max = 60, default = 'Unregistered Cargo Drop', label = 'Dispatch title' },
    } },
    { id = 'announce', icon = 'bell', label = 'Announcements', help = 'The text itself is set per crate type.', fields = {
        { 'Announce.ToEveryone', 'bool', default = true, label = 'Text announcements', help = 'Off keeps the blip and timer but drops the notifications.' },
        { 'Announce.NameLocation', 'bool', default = true, label = 'Name the zone', help = 'Off makes drops much harder to find.' },
    } },
    { id = 'delivery', icon = 'plane', label = 'Flyover', help = 'The plane and the falling crate. Model and height are set per crate type.', fields = {
        { 'Delivery.Flyover', 'bool', default = true, label = 'Plane flyovers', help = 'Off for every crate type at once. The crate just appears on landing.' },
        { 'Delivery.PlaneSpeed', 'num', min = 10, max = 300, step = 5, unit = 'm/s', default = 90.0, needs = 'Delivery.Flyover', label = 'Plane speed' },
        { 'Delivery.SpawnDistance', 'num', min = 200, max = 3000, step = 50, unit = 'm', default = 900.0, needs = 'Delivery.Flyover', label = 'Plane appears this far out' },
    } },
    { id = 'map', icon = 'mapblip', label = 'Map', help = 'The pin itself is set per crate type.', fields = {
        { 'Blip.Scale', 'num', min = 0.4, max = 3, step = 0.1, default = 1.1, label = 'Pin size' },
        { 'Blip.ShowRadius', 'bool', default = true, label = 'Draw the circles', help = 'Off leaves just the pin, which makes drops much harder to find.' },
        { 'Blip.RadiusColour', 'colour', default = 1, needs = 'Blip.ShowRadius', label = 'Contest circle colour', help = 'Once the crate is down. Red by default.' },
        { 'Blip.RadiusAlpha', 'int', min = 10, max = 255, default = 90, needs = 'Blip.ShowRadius', label = 'Contest circle opacity' },
        { 'Blip.ApproxColour', 'colour', default = 5, needs = 'Blip.ShowRadius', label = 'Search circle colour', help = 'While it is inbound. Yellow by default.' },
        { 'Blip.ApproxAlpha', 'int', min = 10, max = 255, default = 60, needs = 'Blip.ShowRadius', label = 'Search circle opacity' },
    } },
    { id = 'sounds', icon = 'volume', label = 'Sound', fields = {
        { 'Sounds.Enabled', 'bool', default = true, label = 'Sound cues' },
        { 'Sounds.CountdownTicks', 'bool', default = true, needs = 'Sounds.Enabled', label = 'Countdown ticks', help = 'The last ten seconds tick out loud.' },
    } },
    { id = 'notify', icon = 'info', label = 'Notifications', fields = {
        { 'NotifyStyle.title', 'text', max = 40, empty = true, default = 'Airdrop', label = 'Title' },
        { 'NotifyStyle.icon', 'text', max = 40, empty = true, default = 'parachute-box', label = 'Icon', help = 'Font Awesome name. Depends on your notify script.' },
        { 'NotifyStyle.position', 'select', options = POSITIONS, default = 'top', label = 'Position' },
        { 'NotifyStyle.duration', 'int', min = 1000, max = 30000, step = 500, unit = 'ms', default = 7000, label = 'On screen for' },
    } },
    { id = 'builder', icon = 'tools', label = 'Builder', help = 'The freecam used to place landing points.', fields = {
        { 'Builder.showExisting', 'bool', default = true, label = 'Show other points while placing' },
        { 'Builder.showSeconds', 'int', min = 3, max = 60, unit = 's', default = 10, label = 'Show all points for' },
        { 'Builder.cameraSpeed.normal', 'num', min = 1, max = 60, step = 0.5, unit = 'm/s', default = 8.0, label = 'Camera speed' },
        { 'Builder.cameraSpeed.fast', 'num', min = 1, max = 150, step = 1, unit = 'm/s', default = 40.0, label = 'Camera speed with Shift' },
        { 'Builder.cameraSpeed.slow', 'num', min = 0.2, max = 10, step = 0.1, unit = 'm/s', default = 1.5, label = 'Camera speed with Alt' },
    } },
}

for _, section in ipairs(Settings.Sections) do
    local list = {}
    for _, raw in ipairs(section.fields) do
        local def = { key = raw[1], type = raw[2], section = section.id }
        for k, v in pairs(raw) do
            if type(k) == 'string' then def[k] = v end
        end
        list[#list + 1] = def
        Settings.fields[#Settings.fields + 1] = def
        Settings.byKey[def.key] = def
    end
    section.fields = list
end

local function path(key)
    local parts = {}
    for part in key:gmatch('[^%.]+') do parts[#parts + 1] = part end
    return parts
end

function Settings.Read(key)
    local node = Config
    for _, part in ipairs(path(key)) do
        if type(node) ~= 'table' then return nil end
        node = node[part]
    end
    return node
end

function Settings.Write(key, value)
    local parts = path(key)
    local node = Config
    for i = 1, #parts - 1 do
        if type(node[parts[i]]) ~= 'table' then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

function Settings.Same(a, b)
    if type(a) == 'number' and type(b) == 'number' then return math.abs(a - b) < 1e-9 end
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    if #a ~= #b then return false end
    for k, v in pairs(a) do
        if not Settings.Same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function within(def, n)
    if def.min and n < def.min then n = def.min end
    if def.max and n > def.max then n = def.max end
    return n
end

function Settings.Clean(def, value)
    local kind = def.type
    if kind == 'bool' then
        if type(value) == 'boolean' then return value end
        if value == 1 or value == '1' or value == 'true' then return true end
        if value == 0 or value == '0' or value == 'false' then return false end
        return nil
    elseif kind == 'int' then
        local n = tonumber(value)
        if not n or n ~= n then return nil end
        return within(def, math.floor(n + 0.5))
    elseif kind == 'hour' then
        local n = tonumber(value)
        if not n or n ~= n then return nil end
        n = math.floor(n + 0.5)
        if n < -1 then n = -1 end
        if n > 23 then n = 23 end
        return n
    elseif kind == 'colour' then
        local n = tonumber(value)
        if not n or n ~= n then return nil end
        n = math.floor(n + 0.5)
        if n < 0 then n = 0 end
        if n > 85 then n = 85 end
        return n
    elseif kind == 'num' then
        local n = tonumber(value)
        if not n or n ~= n then return nil end
        local step = def.step or 0.1
        n = math.floor(n / step + 0.5) * step
        n = math.floor(n * 1000 + 0.5) / 1000
        return within(def, n) + 0.0
    elseif kind == 'text' then
        if value == nil or type(value) == 'table' or type(value) == 'boolean' then return nil end
        local s = Util.Text(value, def.max or 64)
        if def.slug then s = Util.Slug(s, def.max or 64) end
        if s == '' and not def.empty then return nil end
        return s
    elseif kind == 'select' then
        for _, option in ipairs(def.options or {}) do
            if option == value then return value end
        end
        return nil
    elseif kind == 'list' then
        if type(value) ~= 'table' then return nil end
        return Util.List(value, def.max or 30, def.slug)
    end
    return nil
end

local oldSee = Config and type(Config.Access) == 'table' and Config.Access.See
if type(oldSee) == 'table' and oldSee.Mode == nil and oldSee.Everyone == false then oldSee.Mode = 'only' end

for _, def in ipairs(Settings.fields) do
    if Config and Settings.Read(def.key) == nil and def.default ~= nil then
        Settings.Write(def.key, Util.Copy(def.default))
    end
end

function Settings.Apply(values)
    if type(values) ~= 'table' then return end
    for key, value in pairs(values) do
        local def = Settings.byKey[key]
        if def then
            local clean = Settings.Clean(def, value)
            if clean ~= nil then Settings.Write(key, clean) end
        end
    end
end

function Settings.Public()
    local sections = {}
    for _, section in ipairs(Settings.Sections) do
        local fields = {}
        for _, def in ipairs(section.fields) do
            local out = {}
            for k, v in pairs(def) do
                if k ~= 'default' then out[k] = v end
            end
            fields[#fields + 1] = out
        end
        sections[#sections + 1] = { id = section.id, icon = section.icon, label = section.label, help = section.help, fields = fields }
    end
    return sections
end
