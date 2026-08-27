-- The countdown.
--
-- A notification saying "90 seconds out" is read once and then forgotten, and
-- the whole warning window is a decision about whether to travel. Players need
-- to be able to glance at the remaining time for as long as it matters, so it
-- is on screen rather than in a toast.
--
-- Drawn with natives rather than NUI on purpose: this is four lines of text
-- that must be visible while driving, and a permanently-open NUI frame to
-- render them would take input focus problems for nothing.

local function fmtClock(seconds)
    if seconds < 0 then seconds = 0 end
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function drawText(text, x, y, scale, r, g, b, a)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 205)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(text)
    DrawText(x, y)
end

-- The panel background. Sized to the text rather than a fixed box so a long
-- location name does not overflow it.
local function drawBox(x, y, w, h, r, g, b, a)
    DrawRect(x, y, w, h, r, g, b, a)
end

CreateThread(function()
    while true do
        local wait = 500
        local data = Airdrop.data

        if data and data.state then
            wait = 0

            local nowMs = GetGameTimer()
            local x, y = 0.5, 0.035

            if data.state == 'announced' or data.state == 'inbound' then
                local remaining = math.floor(((data.landsAtMs or nowMs) - nowMs) / 1000)

                -- Turns red in the last fifteen seconds. If you are not moving
                -- by then, you are not getting there first.
                local urgent = remaining <= 15
                local cr, cg, cb = 255, 255, 255
                if urgent then cr, cg, cb = 255, 90, 95 end

                drawBox(x, y + 0.018, 0.20, 0.075, 0, 0, 0, 150)
                drawText('~y~SUPPLY DROP INBOUND', x, y, 0.45, 255, 255, 255, 255)
                drawText(fmtClock(remaining), x, y + 0.022, 0.75, cr, cg, cb, 255)

                if data.label then
                    drawText(data.label, x, y + 0.055, 0.34, 200, 200, 200, 220)
                end

            elseif data.state == 'landed' then
                drawBox(x, y + 0.012, 0.20, 0.055, 0, 0, 0, 150)
                drawText('~r~CRATE ON THE GROUND', x, y, 0.45, 255, 255, 255, 255)
                if data.label then
                    drawText(data.label, x, y + 0.024, 0.34, 200, 200, 200, 220)
                end

            elseif data.state == 'open' then
                local remaining = math.floor(((data.expiresAtMs or nowMs) - nowMs) / 1000)

                drawBox(x, y + 0.012, 0.20, 0.055, 0, 0, 0, 150)
                drawText('~g~CRATE OPEN', x, y, 0.45, 255, 255, 255, 255)
                drawText(('closes in %s'):format(fmtClock(remaining)), x, y + 0.024, 0.34, 200, 200, 200, 220)
            end
        end

        Wait(wait)
    end
end)
