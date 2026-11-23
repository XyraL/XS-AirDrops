Util = {}

Util.FALL_CHUTE = 16.0
Util.FALL_FREE = 45.0

function Util.Truthy(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

function Util.Copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Util.Copy(v) end
    return out
end

function Util.Round(value, places)
    local mult = 10 ^ (places or 0)
    return math.floor((tonumber(value) or 0) * mult + 0.5) / mult
end

function Util.Clamp(value, low, high, fallback)
    local n = tonumber(value)
    if not n or n ~= n then n = fallback ~= nil and fallback or low end
    if n < low then n = low end
    if n > high then n = high end
    return n
end

function Util.Int(value, low, high, fallback)
    return math.floor(Util.Clamp(value, low, high, fallback) + 0.5)
end

function Util.Text(value, max)
    if value == nil or type(value) == 'table' then return '' end
    value = tostring(value):gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if max and #value > max then value = value:sub(1, max) end
    return value
end

function Util.Model(value, max)
    return (Util.Text(value, 96):gsub('[^%w_%-]', '')):sub(1, max or 64)
end

function Util.Item(value)
    return (Util.Text(value, 96):gsub('[^%w_%-%.]', '')):sub(1, 64)
end

function Util.Slug(value, max)
    return (tostring(value or ''):lower():gsub('[^%w_%-]', '')):sub(1, max or 48)
end

function Util.List(value, max, slug)
    local out, seen = {}, {}
    if type(value) ~= 'table' then return out end
    for _, v in ipairs(value) do
        local s = slug and Util.Slug(v, 48) or Util.Text(v, 48)
        if s ~= '' and not seen[s] and #out < (max or 30) then
            seen[s] = true
            out[#out + 1] = s
        end
    end
    return out
end

function Util.Point(value)
    if type(value) ~= 'table' and type(value) ~= 'vector3' and type(value) ~= 'vector4' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end
    return { x = Util.Round(x, 3), y = Util.Round(y, 3), z = Util.Round(z, 3) }
end

function Util.Has(list, value)
    if value == nil then return false end
    for _, v in ipairs(list or {}) do
        if v == value then return true end
    end
    return false
end

function Util.Flat(a, b)
    local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function Util.InHours(hours, hour)
    if type(hours) ~= 'table' then return true end
    local from, to = tonumber(hours.from), tonumber(hours.to)
    if not from or not to or from < 0 or to < 0 or from == to then return true end
    if from < to then return hour >= from and hour < to end
    return hour >= from or hour < to
end

function Util.FlightTime(crate, delivery)
    delivery = delivery or {}
    if delivery.Flyover == false or not crate or not crate.flyover then return 0 end
    local speed = math.max(10.0, tonumber(delivery.PlaneSpeed) or 90.0)
    local travel = (tonumber(delivery.SpawnDistance) or 900.0) / speed
    local fall = (tonumber(crate.altitude) or 320.0) / (crate.parachute and Util.FALL_CHUTE or Util.FALL_FREE)
    return math.floor(travel + fall + 0.5)
end

function Util.Fill(template, values)
    return (tostring(template or ''):gsub('{(%w+)}', function(key)
        local v = values[key]
        if v == nil then return '{' .. key .. '}' end
        return tostring(v)
    end))
end
