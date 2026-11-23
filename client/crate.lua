Crate = { busy = false }

local ANIM = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
local ON_GROUND = { landed = true, open = true }

local function reach(e)
    local pos = GetEntityCoords(PlayerPedId())
    local limit = Config.Drop.CrackDistance or 5.0
    if e.propCoords then
        local dist = #(pos - e.propCoords)
        return dist <= limit, dist
    end
    local c = e.data.coords
    local flat = Util.Flat(pos, c)
    return flat <= limit and math.abs(pos.z - c.z) <= 25.0, flat
end

local function anim()
    if HasAnimDictLoaded(ANIM.dict) then return ANIM end
    local ok = pcall(lib.requestAnimDict, ANIM.dict, 3000)
    if ok and HasAnimDictLoaded(ANIM.dict) then return ANIM end
    return nil
end

function Crate.Crack(id)
    if Crate.busy then return end
    local e = Airdrop.drops[id]
    if not e or not e.data or e.data.state ~= 'landed' then return end
    Crate.busy = true

    TriggerServerEvent('XS-AirDrops:server:beginCrack', id)

    local ok = lib.progressBar({
        duration = math.floor((e.data.crate.crackTime or 25) * 1000),
        label = 'Forcing the crate',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = anim(),
    })

    Crate.busy = false

    if not ok then
        Framework.Notify('You stopped forcing the crate.', 'error')
        return
    end

    local now = Airdrop.drops[id]
    if not now or now.data.state ~= 'landed' then return end
    if not reach(now) then
        Framework.Notify('You moved too far from the crate.', 'error')
        return
    end

    TriggerServerEvent('XS-AirDrops:server:finishCrack', id)
end

function Crate.Loot(id)
    if Crate.busy then return end
    TriggerServerEvent('XS-AirDrops:server:loot', id)
end

local CRACK = { name = 'xs_airdrop_crack', label = 'Force the crate', icon = 'fa-solid fa-screwdriver-wrench' }
local LOOT = { name = 'xs_airdrop_loot', label = 'Search the crate', icon = 'fa-solid fa-box-open' }

local function targetResource()
    if GetResourceState('ox_target') == 'started' then return 'ox_target' end
    if GetResourceState('qb-target') == 'started' then return 'qb-target' end
    return nil
end

Crate.mode = 'key'

local function canCrack(id)
    local cur = Airdrop.drops[id]
    return cur ~= nil and cur.data.state == 'landed' and not Crate.busy
end

local function canLoot(id)
    local cur = Airdrop.drops[id]
    return cur ~= nil and cur.data.state == 'open' and not cur.data.emptied and not Crate.busy
end

local function addTarget(e)
    local res = targetResource()
    if not res or not e.prop or e.targeted then return end
    local id, prop = e.id, e.prop
    local distance = (Config.Drop.CrackDistance or 5.0) + 0.0
    local ok, err = pcall(function()
        if res == 'ox_target' then
            exports.ox_target:addLocalEntity(prop, {
                { name = CRACK.name, label = CRACK.label, icon = CRACK.icon, distance = distance, canInteract = function() return canCrack(id) end, onSelect = function() CreateThread(function() Crate.Crack(id) end) end },
                { name = LOOT.name, label = LOOT.label, icon = LOOT.icon, distance = distance, canInteract = function() return canLoot(id) end, onSelect = function() CreateThread(function() Crate.Loot(id) end) end },
            })
        else
            exports['qb-target']:AddTargetEntity(prop, {
                options = {
                    { type = 'client', label = CRACK.label, icon = CRACK.icon, canInteract = function() return canCrack(id) end, action = function() CreateThread(function() Crate.Crack(id) end) end },
                    { type = 'client', label = LOOT.label, icon = LOOT.icon, canInteract = function() return canLoot(id) end, action = function() CreateThread(function() Crate.Loot(id) end) end },
                },
                distance = distance,
            })
        end
    end)
    if ok then
        e.targeted = { res = res, prop = prop }
    else
        print(('^3[XS-AirDrops]^0 %s would not take the crate, so it uses the E prompt: %s'):format(res, tostring(err)))
        Crate.mode = 'key'
    end
end

local function removeTarget(e)
    local t = e.targeted
    if not t then return end
    e.targeted = nil
    pcall(function()
        if t.res == 'ox_target' then
            exports.ox_target:removeLocalEntity(t.prop, { CRACK.name, LOOT.name })
        else
            exports['qb-target']:RemoveTargetEntity(t.prop, { CRACK.label, LOOT.label })
        end
    end)
end

function Crate.Refresh()
    Crate.mode = (Config.Drop.OpenWith == 'target' and targetResource()) and 'target' or 'key'
    for _, e in pairs(Airdrop.drops) do
        if Crate.mode == 'target' then
            if e.targeted and e.targeted.prop ~= e.prop then removeTarget(e) end
            if e.prop and not e.targeted then addTarget(e) end
        elseif e.targeted then
            removeTarget(e)
        end
    end
end

function CrateTargetAdd(e)
    if Crate.mode == 'target' then addTarget(e) end
end

function CrateTargetRemove(e)
    removeTarget(e)
end

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if Crate.busy and lib.progressActive() then lib.cancelProgress() end
end)

local function targetChanged(resource)
    if resource == 'ox_target' or resource == 'qb-target' then SetTimeout(500, Crate.Refresh) end
end

AddEventHandler('onClientResourceStart', targetChanged)
AddEventHandler('onClientResourceStop', targetChanged)

CreateThread(function()
    Crate.Refresh()
    while true do
        local wait = 800
        local best, bestDist, bestNear
        if Crate.mode == 'key' then
            for _, e in pairs(Airdrop.drops) do
                if e.data and ON_GROUND[e.data.state] then
                    local near, dist = reach(e)
                    if dist and (not bestDist or dist < bestDist) then best, bestDist, bestNear = e, dist, near end
                end
            end
        end

        if best and bestDist < 25.0 then
            wait = 0
            if bestNear and not Crate.busy then
                local data = best.data
                local text = data.state == 'landed' and '[~g~E~s~] Force the crate'
                    or (data.emptied and 'The crate is empty' or '[~g~E~s~] Search the crate')
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(text)
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) and not data.emptied then
                    if data.state == 'landed' then Crate.Crack(best.id) else Crate.Loot(best.id) end
                end
            end
        end

        Wait(wait)
    end
end)
