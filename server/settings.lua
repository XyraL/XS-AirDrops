Settings.defaults = {}
Settings.overrides = {}

local function snapshot()
    if Settings.snapped then return end
    for _, def in ipairs(Settings.fields) do Settings.defaults[def.key] = Util.Copy(Settings.Read(def.key)) end
    Settings.snapped = true
end

local function applyAll()
    for _, def in ipairs(Settings.fields) do
        local value = Settings.overrides[def.key]
        if value == nil then value = Settings.defaults[def.key] end
        Settings.Write(def.key, Util.Copy(value))
    end
end

function Settings.Decode(kind, raw)
    if raw == nil then return nil end
    local ok, value = pcall(json.decode, raw)
    if ok and value ~= nil then
        if (kind == 'bool' and type(value) == 'boolean')
            or ((kind == 'int' or kind == 'num' or kind == 'hour' or kind == 'colour') and type(value) == 'number')
            or (kind == 'list' and type(value) == 'table')
            or ((kind == 'text' or kind == 'select') and type(value) == 'string') then
            return value
        end
    end
    local text = tostring(raw)
    if kind == 'bool' then return text == 'true' or text == '1' end
    if kind == 'int' or kind == 'num' or kind == 'hour' or kind == 'colour' then return tonumber(text) end
    if kind == 'list' then
        local out = {}
        for item in text:gmatch('[^,]+') do
            local trimmed = item:match('^%s*(.-)%s*$')
            if trimmed ~= '' then out[#out + 1] = trimmed end
        end
        return out
    end
    return text
end

function Settings.Values()
    local out = {}
    for _, def in ipairs(Settings.fields) do out[def.key] = Settings.Read(def.key) end
    return out
end

function Settings.Push(target)
    TriggerClientEvent('XS-AirDrops:client:settings', target or -1, Settings.Values())
end

local function moveOldSee(rows)
    local old, hasMode
    for i = #rows, 1, -1 do
        if rows[i].key == 'Access.See.Everyone' then old = table.remove(rows, i) end
    end
    if not old then return rows end
    for _, row in ipairs(rows) do
        if row.key == 'Access.See.Mode' then hasMode = true end
    end
    if not hasMode and Settings.Decode('bool', old.value) == false then
        local value = json.encode('only')
        MySQL.query.await([[
            INSERT INTO `xs_airdrop_settings` (`key`, `value`, `changed_by`) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)
        ]], { 'Access.See.Mode', value, old.changed_by or '' })
        rows[#rows + 1] = { key = 'Access.See.Mode', value = value }
    end
    MySQL.query.await('DELETE FROM `xs_airdrop_settings` WHERE `key` = ?', { 'Access.See.Everyone' })
    return rows
end

function Settings.Load()
    snapshot()
    Settings.overrides = {}
    local applied = 0
    local rows = moveOldSee(MySQL.query.await('SELECT `key`, `value`, `changed_by` FROM `xs_airdrop_settings`') or {})
    for _, row in ipairs(rows) do
        local def = Settings.byKey[row.key]
        if def then
            local clean = Settings.Clean(def, Settings.Decode(def.type, row.value))
            if clean ~= nil and not Settings.Same(clean, Settings.defaults[row.key]) then
                Settings.overrides[row.key] = clean
                applied = applied + 1
            end
        end
    end
    applyAll()
    if applied > 0 then
        print(('^2[XS-AirDrops]^0 %d saved setting%s applied over config.lua'):format(applied, applied == 1 and '' or 's'))
    end
    Settings.Push()
end

local function check(values)
    local minI = values['Schedule.MinInterval']
    local maxI = values['Schedule.MaxInterval']
    if minI and maxI and minI > maxI then
        return false, 'The shortest gap cannot be longer than the longest gap.'
    end
    return true
end

function Settings.Save(changes, resets, by)
    local wanted = {}
    for k, v in pairs(Settings.overrides) do wanted[k] = v end
    for key, value in pairs(type(changes) == 'table' and changes or {}) do
        local def = Settings.byKey[key]
        if def then
            local clean = Settings.Clean(def, value)
            if clean == nil then return false, ('"%s" is not a valid value.'):format(def.label or key) end
            if Settings.Same(clean, Settings.defaults[key]) then wanted[key] = nil else wanted[key] = clean end
        end
    end
    for _, key in ipairs(type(resets) == 'table' and resets or {}) do
        if Settings.byKey[key] then wanted[key] = nil end
    end

    local merged = {}
    for _, def in ipairs(Settings.fields) do
        local v = wanted[def.key]
        if v == nil then v = Settings.defaults[def.key] end
        merged[def.key] = v
    end
    local ok, why = check(merged)
    if not ok then return false, why end

    for _, def in ipairs(Settings.fields) do
        local key = def.key
        local had = Settings.overrides[key]
        local now = wanted[key]
        if now == nil and had ~= nil then
            MySQL.query.await('DELETE FROM `xs_airdrop_settings` WHERE `key` = ?', { key })
        elseif now ~= nil and (had == nil or not Settings.Same(now, had)) then
            MySQL.query.await([[
                INSERT INTO `xs_airdrop_settings` (`key`, `value`, `changed_by`) VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE `value` = VALUES(`value`), `changed_by` = VALUES(`changed_by`)
            ]], { key, json.encode(now), by or '' })
        end
    end

    Settings.overrides = wanted
    applyAll()
    Settings.Push()
    return true, Settings.Values()
end

function Settings.Builder()
    return { sections = Settings.Public(), values = Settings.Values(), defaults = Settings.defaults }
end

RegisterNetEvent('XS-AirDrops:server:requestSettings', function()
    Settings.Push(source)
end)
