-- The on-screen drop status.
--
-- Deliberately small and out of the way. It sits under the minimap side of the
-- screen rather than across the top middle, where it fought with the compass
-- and looked like a debug readout.
--
-- It only appears when you are actually near the drop. A permanent banner for
-- an event happening on the other side of the map is clutter — the blip already
-- tells you it exists, and the countdown only matters once you are committed to
-- going. Config.Drop.HudDistance decides "near", or set it to 0 to always show.

local function fmtClock(seconds)
    if seconds < 0 then seconds = 0 end
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

-- Right-aligned, so the block grows leftwards from a fixed edge instead of
-- shifting about as the text changes width.
local function text(str, x, y, scale, colour, align)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(colour[1], colour[2], colour[3], colour[4] or 255)
    SetTextDropshadow(0, 0, 0, 0, 200)
    SetTextDropShadow()

    if align == 'right' then
        SetTextRightJustify(true)
        SetTextWrap(0.0, x)
    elseif align == 'centre' then
        SetTextCentre(true)
    end

    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(str)
    DrawText(align == 'right' and 0.0 or x, y)
end

local WHITE = { 255, 255, 255 }
local MUTED = { 170, 180, 190 }
local AMBER = { 245, 165, 36 }
local RED   = { 255, 90, 95 }
local GREEN = { 48, 209, 88 }

-- How far away the drop is, or nil when there is nothing to measure.
local function distanceToDrop(data)
    if not data or not data.coords then return nil end
    local pos = GetEntityCoords(PlayerPedId())
    return #(pos - vector3(data.coords.x, data.coords.y, data.coords.z))
end

local function shouldShow(data, dist)
    if not data or not data.state then return false end

    local limit = Config.Drop.HudDistance
    if not limit or limit <= 0 then return true end   -- 0 = always on

    -- Fall back to showing it if the distance cannot be worked out, rather than
    -- hiding a live drop because of a missing coordinate.
    if not dist then return true end

    -- The zone itself, plus the limit. Being inside the contested area always
    -- counts as near, however the limit is configured.
    return dist <= math.max(limit, (data.zoneRadius or 120.0))
end

CreateThread(function()
    while true do
        local wait = 400
        local data = Airdrop.data
        local dist = distanceToDrop(data)

        if shouldShow(data, dist) then
            wait = 0

            local nowMs = GetGameTimer()

            -- Anchored to the right edge, above the ammo/health area.
            local right, y = 0.955, 0.845
            local line = 0.032

            local heading, clock, clockColour, note

            if data.state == 'announced' or data.state == 'inbound' then
                local remaining = math.floor(((data.landsAtMs or nowMs) - nowMs) / 1000)
                heading = 'SUPPLY DROP'
                clock = fmtClock(remaining)
                clockColour = remaining <= 15 and RED or WHITE
                note = 'inbound'

            elseif data.state == 'landed' then
                heading = 'SUPPLY DROP'
                clock = nil
                note = 'on the ground'

            elseif data.state == 'open' and data.emptied then
                heading = 'SUPPLY DROP'
                clock = nil
                note = 'emptied'

            elseif data.state == 'open' then
                local remaining = math.floor(((data.expiresAtMs or nowMs) - nowMs) / 1000)
                heading = 'SUPPLY DROP'
                clock = fmtClock(remaining)
                clockColour = GREEN
                note = 'open · closes in'
            end

            if heading then
                -- A thin accent rule rather than a filled box. The old panel was
                -- a grey slab that covered the compass.
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

                -- Only worth showing while you are still closing on it.
                if dist and dist > 60.0 and data.state ~= 'open' then
                    text(('%dm'):format(math.floor(dist)), right,
                        y + (clock and 0.106 or 0.076), 0.24, MUTED, 'right')
                end
            end
        end

        Wait(wait)
    end
end)
