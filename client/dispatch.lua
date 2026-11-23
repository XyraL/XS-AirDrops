PoliceAlert = { blips = {}, n = 0 }

function PoliceAlert.Clear(id)
    if id == nil then return end
    local blip = PoliceAlert.blips[id]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    PoliceAlert.blips[id] = nil
end

function PoliceAlert.ClearAll()
    for id in pairs(PoliceAlert.blips) do PoliceAlert.Clear(id) end
end

RegisterNetEvent('XS-AirDrops:client:policeAlert', function(data)
    if type(data) ~= 'table' or type(data.coords) ~= 'table' then return end
    local c = data.coords

    Framework.Notify(('%s · %s'):format(data.code or '10-66', data.title or 'Unregistered cargo drop'), 'warning', 'Dispatch')

    local known = data.id and Airdrop.drops[data.id]
    if known and known.data and known.data.state == 'open' then return end

    PoliceAlert.n = PoliceAlert.n + 1
    local key = data.id or ('alert-' .. PoliceAlert.n)
    PoliceAlert.Clear(key)

    local blip = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetBlipSprite(blip, data.sprite or 478)
    SetBlipColour(blip, data.colour or 1)
    SetBlipScale(blip, 1.0)
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.title or 'Cargo Drop')
    EndTextCommandSetBlipName(blip)
    PoliceAlert.blips[key] = blip

    SetTimeout(300000, function()
        if PoliceAlert.blips[key] == blip then PoliceAlert.Clear(key) end
    end)
end)
