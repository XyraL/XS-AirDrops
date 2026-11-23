Airdrop = { drops = {} }

local function clearBlips(e)
    if e.blip and DoesBlipExist(e.blip) then RemoveBlip(e.blip) end
    if e.radiusBlip and DoesBlipExist(e.radiusBlip) then RemoveBlip(e.radiusBlip) end
    e.blip, e.radiusBlip = nil, nil
end

local function buildBlips(e)
    clearBlips(e)
    local data = e.data
    local c = data.coords
    local crate = data.crate or {}
    local cfg = Config.Blip

    e.blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(e.blip, crate.sprite or 478)
    SetBlipColour(e.blip, crate.colour or 5)
    SetBlipScale(e.blip, (cfg.Scale or 1.1) + 0.0)
    SetBlipAsShortRange(e.blip, false)
    if data.approx then SetBlipFlashes(e.blip, true) end

    local name = (crate.blip and crate.blip ~= '') and crate.blip or 'Supply Drop'
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.approx and (name .. ' (inbound)') or name)
    EndTextCommandSetBlipName(e.blip)

    if cfg.ShowRadius then
        local radius = data.approx and (data.approxRadius or 250.0) or (data.zoneRadius or 120.0)
        if radius > 0 then
            e.radiusBlip = AddBlipForRadius(c.x, c.y, c.z, radius + 0.0)
            SetBlipColour(e.radiusBlip, data.approx and (cfg.ApproxColour or 5) or (cfg.RadiusColour or 1))
            SetBlipAlpha(e.radiusBlip, data.approx and (cfg.ApproxAlpha or 60) or (cfg.RadiusAlpha or 90))
        end
    end
end

function Airdrop.Remove(id)
    if PoliceAlert then PoliceAlert.Clear(id) end
    local e = Airdrop.drops[id]
    if not e then return end
    clearBlips(e)
    AirdropRemoveCrate(e)
    Airdrop.drops[id] = nil
end

function Airdrop.ClearAll()
    for id in pairs(Airdrop.drops) do Airdrop.Remove(id) end
end

local function apply(id, data)
    if not id then return end
    if type(data) ~= 'table' then
        Airdrop.Remove(id)
        return
    end

    local e = Airdrop.drops[id]
    local previous = e and e.data
    if not e then
        e = { id = id }
        Airdrop.drops[id] = e
    end

    local now = GetGameTimer()
    data.coords = vector3(data.coords.x + 0.0, data.coords.y + 0.0, data.coords.z + 0.0)
    data.landsAtMs = data.landsIn and (now + data.landsIn * 1000) or nil
    data.expiresAtMs = data.expiresIn and (now + data.expiresIn * 1000) or nil
    data.crate = data.crate or {}
    e.data = data

    if data.state == 'open' then
        clearBlips(e)
        if PoliceAlert then PoliceAlert.Clear(id) end
    else
        buildBlips(e)
    end

    if data.state == 'landed' or data.state == 'open' then
        if not e.prop then AirdropSpawnCrate(e) end
    else
        AirdropRemoveCrate(e)
    end

    if data.state == 'inbound' and (not previous or previous.state ~= 'inbound') then
        if Config.Delivery.Flyover and data.crate.flyover then AirdropFlyover(e) end
    end
end

function Airdrop.Nearest(states)
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for _, e in pairs(Airdrop.drops) do
        if e.data and (not states or states[e.data.state]) then
            local target = e.propCoords or e.data.coords
            local dist = #(pos - target)
            if not bestDist or dist < bestDist then best, bestDist = e, dist end
        end
    end
    return best, bestDist
end

RegisterNetEvent('XS-AirDrops:client:sync', function(id, data)
    if id == nil then
        Airdrop.ClearAll()
        return
    end
    apply(id, data)
end)

RegisterNetEvent('XS-AirDrops:client:syncAll', function(list)
    Airdrop.ClearAll()
    for _, data in ipairs(list or {}) do apply(data.id, data) end
end)

RegisterNetEvent('XS-AirDrops:client:announce', function(message)
    Framework.Notify(message, 'inform')
end)

RegisterNetEvent('XS-AirDrops:client:openStash', function(id, data)
    Inv.OpenStash(id, data)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    Airdrop.ClearAll()
    if PoliceAlert then PoliceAlert.ClearAll() end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('XS-AirDrops:server:requestSync')
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    TriggerServerEvent('XS-AirDrops:server:requestSync')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Airdrop.ClearAll()
    if PoliceAlert then PoliceAlert.ClearAll() end
end)
