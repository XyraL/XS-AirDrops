local function fmtClock(seconds)
    if seconds < 0 then seconds = 0 end
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function text(str, x, y, scale, colour, align)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(colour[1], colour[2], colour[3], colour[4] or 255)
    SetTextDropshadow(0, 0, 0, 0, 200)
    SetTextDropShadow()
    if align == 'right' then
        SetTextRightJustify(true)
        SetTextWrap(0.0, x)
    end
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(str)
    DrawText(align == 'right' and 0.0 or x, y)
end

local MUTED = { 170, 180, 190 }
local AMBER = { 245, 165, 36 }
local RED   = { 255, 90, 95 }
local GREEN = { 48, 209, 88 }
local WHITE = { 255, 255, 255 }

local function shouldShow(data, dist)
    local limit = Config.Drop.HudDistance
    if not limit or limit <= 0 then return true end
    if not dist then return true end
    return dist <= math.max(limit, data.zoneRadius or 120.0)
end

local function count()
    local n = 0
    for _ in pairs(Airdrop.drops) do n = n + 1 end
    return n
end

CreateThread(function()
    while true do
        local wait = 400
        local e, dist = Airdrop.Nearest()
        local data = e and e.data

        if data and data.state and shouldShow(data, dist) then
            wait = 0
            local nowMs = GetGameTimer()
            local right, y = 0.955, 0.845
            local heading, clock, clockColour, note

            if data.state == 'announced' or data.state == 'inbound' then
                local remaining = math.floor(((data.landsAtMs or nowMs) - nowMs) / 1000)
                heading = 'SUPPLY DROP'
                clock = fmtClock(remaining)
                clockColour = remaining <= 15 and RED or WHITE
                note = 'inbound'
            elseif data.state == 'landed' then
                heading = 'SUPPLY DROP'
                note = 'on the ground'
            elseif data.state == 'open' and data.emptied then
                heading = 'SUPPLY DROP'
                note = 'emptied'
            elseif data.state == 'open' then
                local remaining = math.floor(((data.expiresAtMs or nowMs) - nowMs) / 1000)
                heading = 'SUPPLY DROP'
                clock = fmtClock(remaining)
                clockColour = GREEN
                note = 'open · closes in'
            end

            if heading then
                local others = count() - 1
                if others > 0 then heading = ('%s  +%d'):format(heading, others) end
                DrawRect(right + 0.0075, y + 0.028, 0.0022, 0.075, AMBER[1], AMBER[2], AMBER[3], 220)
                text(heading, right, y, 0.30, AMBER, 'right')
                if clock then
                    text(note, right, y + 0.026, 0.26, MUTED, 'right')
                    text(clock, right, y + 0.046, 0.52, clockColour or WHITE, 'right')
                else
                    text(note, right, y + 0.026, 0.30, RED, 'right')
                end
                if data.label then
                    text(data.label, right, y + (clock and 0.086 or 0.056), 0.24, MUTED, 'right')
                end
                if dist and dist > 60.0 and data.state ~= 'open' then
                    text(('%dm'):format(math.floor(dist)), right, y + (clock and 0.106 or 0.076), 0.24, MUTED, 'right')
                end
            end
        end

        Wait(wait)
    end
end)
