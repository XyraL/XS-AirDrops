-- Client state for the active drop.
--
-- Everything here is a projection of what the server sent. The client draws the
-- blip, the crate prop and the zone, and asks the server whenever something
-- should actually happen. It never decides that a crate opened.

Airdrop = {
    data = nil,      -- last payload from the server
    blip = nil,
    radiusBlip = nil,
    prop = nil,      -- local crate prop; see the note in server/main.lua
}

local function clearBlips()
    if Airdrop.blip then
        RemoveBlip(Airdrop.blip)
        Airdrop.blip = nil
    end
    if Airdrop.radiusBlip then
        RemoveBlip(Airdrop.radiusBlip)
        Airdrop.radiusBlip = nil
    end
end

local function clearProp()
    if Airdrop.prop and DoesEntityExist(Airdrop.prop) then
        DeleteEntity(Airdrop.prop)
    end
    Airdrop.prop = nil
end

function AirdropCleanup()
    clearBlips()
    clearProp()
    Airdrop.data = nil
end

local function buildBlips(data)
    clearBlips()
    if not data or not data.coords then return end

    local cfg = Config.Blip
    local c = data.coords

    Airdrop.blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(Airdrop.blip, cfg.Sprite or 478)
    SetBlipColour(Airdrop.blip, cfg.Colour or 5)
    SetBlipScale(Airdrop.blip, cfg.Scale or 1.1)
    SetBlipAsShortRange(Airdrop.blip, false)

    -- A pulsing blip while it is still in the air reads as "happening now".
    if data.state == 'announced' or data.state == 'inbound' then
        SetBlipFlashes(Airdrop.blip, true)
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(
        data.approx and 'Supply Drop (inbound)' or 'Supply Crate')
    EndTextCommandSetBlipName(Airdrop.blip)

    -- The radius blip does double duty: while inbound it shows the search area,
    -- and once landed it shows the contested ground people are fighting over.
    if cfg.ShowRadius then
        local radius = data.approx and (data.approxRadius or 250.0) or (data.zoneRadius or 120.0)
        Airdrop.radiusBlip = AddBlipForRadius(c.x, c.y, c.z, radius + 0.0)
        SetBlipColour(Airdrop.radiusBlip, cfg.Colour or 5)
        SetBlipAlpha(Airdrop.radiusBlip, cfg.RadiusAlpha or 80)
    end
end

RegisterNetEvent('cipher-airdrops:client:sync', function(data)
    if not data then
        AirdropCleanup()
        return
    end

    local previous = Airdrop.data
    Airdrop.data = data

    buildBlips(data)

    -- The crate becomes a real prop only once it is on the ground.
    if data.state == 'landed' or data.state == 'open' then
        if not Airdrop.prop then
            AirdropSpawnCrate(data.coords)
        end
    else
        clearProp()
    end

    -- Fly the plane in when the server says it is inbound, once.
    if data.state == 'inbound' and (not previous or previous.state ~= 'inbound') then
        if Config.Delivery.Flyover then
            AirdropFlyover(data.coords)
        end
    end
end)

RegisterNetEvent('cipher-airdrops:client:announce', function(message)
    Framework.Notify(message, 'inform', 'Airdrop')
end)

RegisterNetEvent('cipher-airdrops:client:openStash', function(id, data)
    Inv.OpenStash(id, data)
end)

-- Someone joining mid-event should see the drop that is already running.
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    TriggerServerEvent('cipher-airdrops:server:requestSync')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then AirdropCleanup() end
end)
