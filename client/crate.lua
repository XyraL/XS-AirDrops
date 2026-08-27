-- Cracking and looting the crate.
--
-- The client shows a prompt, plays the animation and runs the progress bar. It
-- tells the server when it started and when it thinks it finished; the server
-- decides whether either of those is true. Nothing here is trusted.

local busy = false

local function nearCrate()
    local data = Airdrop.data
    if not data or not data.coords then return false, nil end

    local pos = GetEntityCoords(PlayerPedId())
    local reach = Config.Drop.CrackDistance or 5.0

    -- Once the crate exists, measure to it. That is the thing on screen and the
    -- thing the player is walking up to.
    if Airdrop.propCoords then
        local dist = #(pos - Airdrop.propCoords)
        return dist <= reach, dist
    end

    -- No prop yet. Fall back to the stored point, but measure it the same way
    -- the server does — flat, with a loose height allowance. A location
    -- captured on top of an embankment sits well above the ground the crate
    -- will rest on, and a 3D check would call that "too far" on height alone.
    local flat = #(vector3(pos.x, pos.y, 0.0) - vector3(data.coords.x, data.coords.y, 0.0))
    local drop = math.abs(pos.z - data.coords.z)

    return (flat <= reach and drop <= 25.0), flat
end

local function crackCrate()
    if busy then return end
    busy = true

    TriggerServerEvent('cipher-airdrops:server:beginCrack')

    local seconds = Config.Drop.CrackTime or 25

    local ok = lib.progressBar({
        duration = seconds * 1000,
        label = 'Forcing the crate',
        useWhileDead = false,
        canCancel = true,
        -- Movement cancels it. Standing still in the open for the whole timer
        -- is the risk that makes the crate contested rather than a race.
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' },
    })

    busy = false

    if not ok then
        Framework.Notify('You stopped forcing the crate.', 'error')
        return
    end

    local stillNear = nearCrate()
    if not stillNear then
        Framework.Notify('You moved too far from the crate.', 'error')
        return
    end

    TriggerServerEvent('cipher-airdrops:server:finishCrack')
end

local function lootCrate()
    if busy then return end
    TriggerServerEvent('cipher-airdrops:server:loot')
end

-- Prompt loop. Only runs while a crate is actually on the ground, and only
-- does per-frame work when the player is close enough to care.
CreateThread(function()
    while true do
        local wait = 800
        local data = Airdrop.data

        if data and (data.state == 'landed' or data.state == 'open') and data.coords then
            local near, dist = nearCrate()

            if dist and dist < 25.0 then
                wait = 0

                if near and not busy then
                    local text = data.state == 'landed'
                        and '[~g~E~s~] Force the crate'
                        or (data.emptied and 'The crate is empty'
                            or '[~g~E~s~] Search the crate')

                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(text)
                    EndTextCommandDisplayHelp(0, false, true, -1)

                    if IsControlJustReleased(0, 38) and not data.emptied then   -- E
                        if data.state == 'landed' then crackCrate() else lootCrate() end
                    end
                end
            end
        end

        Wait(wait)
    end
end)

-- ox_target support, when the server runs it. The key prompt above still works
-- either way, so a server without a target resource loses nothing.
CreateThread(function()
    if GetResourceState('ox_target') ~= 'started' then return end

    -- Targeting a local prop means registering by model rather than by entity,
    -- and filtering to the one crate that is actually the drop.
    exports.ox_target:addModel(Config.Delivery.CrateModel, {
        {
            name = 'cipher_airdrop_crack',
            label = 'Force the crate',
            icon = 'fa-solid fa-screwdriver-wrench',
            distance = Config.Drop.CrackDistance or 5.0,
            canInteract = function()
                local data = Airdrop.data
                return data and data.state == 'landed' and nearCrate()
            end,
            onSelect = crackCrate,
        },
        {
            name = 'cipher_airdrop_loot',
            label = 'Search the crate',
            icon = 'fa-solid fa-box-open',
            distance = Config.Drop.CrackDistance or 5.0,
            canInteract = function()
                local data = Airdrop.data
                return data and data.state == 'open' and nearCrate()
            end,
            onSelect = lootCrate,
        },
    })
end)
