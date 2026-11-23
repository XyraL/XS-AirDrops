Builder = { open = false }

local function call(action, payload)
    return lib.callback.await('XS-AirDrops:server:builder', false, action, payload or {})
end

local function round(n, p)
    return Util.Round(n, p or 3)
end

local function here()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local zone = GetNameOfZone(pos.x, pos.y, pos.z)
    local street = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    return {
        x = round(pos.x), y = round(pos.y), z = round(pos.z - 0.98),
        area = GetLabelText(zone), street = GetStreetNameFromHashKey(street),
    }
end

local function show(on)
    UI.Focus('builder', on)
    UI.Send('builder', on and 'show' or 'hide', {})
end

function Builder.Open()
    if Builder.open or Placement.active then return end
    local ok, data = call('data')
    if not ok then
        Framework.Notify(data or 'You do not have permission for that.', 'error')
        return
    end
    data.here = here()
    UI.Send('builder', 'open', data)
    Builder.open = true
    UI.Focus('builder', true)
end

function Builder.Close()
    if not Builder.open then return end
    Builder.open = false
    UI.Send('builder', 'close', {})
    UI.Focus('builder', false)
end

UI.OnClose('builder', function()
    Builder.open = false
    UI.Send('builder', 'close', {})
    UI.Focus('builder', false)
end)

UI.Handle('b:server', function(p)
    return call(p.action, p.payload)
end)

UI.Handle('b:here', function()
    return true, here()
end)

UI.Handle('b:place', function(p)
    show(false)
    local ok, result = pcall(Placement.Start, {
        label = p.label,
        model = p.model,
        radius = p.radius,
        approx = p.approx,
        origin = p.origin,
        existing = p.existing,
    })
    if Builder.open then show(true) end
    if not ok then
        print(('^1[XS-AirDrops]^0 placing failed: %s'):format(tostring(result)))
        return false, 'Placing failed. The F8 console has the details.'
    end
    if not result then return false, 'Cancelled.' end
    return true, { x = round(result.x), y = round(result.y), z = round(result.z) }
end)

UI.Handle('b:teleport', function(p)
    if not p or not p.x then return false end
    local ok = call('teleport')
    if not ok then return false, 'You do not have permission for that.' end
    local ped = PlayerPedId()
    local x, y, z = p.x + 0.0, p.y + 0.0, p.z + 0.0
    DoScreenFadeOut(200)
    Wait(220)
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z + 1.0, false, false, false)
    local untilAt = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < untilAt do Wait(20) end
    DoScreenFadeIn(250)
    return true
end)

UI.Handle('b:waypoint', function(p)
    if not p or not p.x then return false end
    SetNewWaypoint(p.x + 0.0, p.y + 0.0)
    return true
end)

UI.Handle('b:showPoints', function(p)
    local points = type(p) == 'table' and p.points or nil
    if type(points) ~= 'table' or #points == 0 then return false, 'No points to show.' end
    local radius = (tonumber(p.radius) or 0) + 0.0
    show(false)
    CreateThread(function()
        local untilAt = GetGameTimer() + math.floor(((Config.Builder or {}).showSeconds or 10) * 1000)
        lib.showTextUI(('**%s**\n%d landing point%s · [Backspace] back to the builder'):format(p.label or 'Landing points', #points, #points == 1 and '' or 's'), { position = 'left-center' })
        while GetGameTimer() < untilAt do
            for i, pt in ipairs(points) do
                local x, y, z = pt.x + 0.0, pt.y + 0.0, pt.z + 0.0
                DrawMarker(2, x, y, z + 2.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 140, 70, 220, true, false, 2, false, nil, nil, false)
                DrawLine(x, y, z, x, y, z + 80.0, 255, 140, 70, 200)
                if radius > 0 then
                    DrawMarker(1, x, y, z - 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2.0, radius * 2.0, 4.0, 255, 70, 60, 50, false, false, 2, false, nil, nil, false)
                end
                if i == 1 then
                    DrawMarker(28, x, y, z + 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 180, 137, 220, false, false, 2, false, nil, nil, false)
                end
            end
            if IsControlJustPressed(0, 194) or IsControlJustPressed(0, 177) then break end
            Wait(0)
        end
        lib.hideTextUI()
        if Builder.open then show(true) end
    end)
    return true
end)

local pending = false

RegisterNetEvent('XS-AirDrops:client:refreshPanel', function()
    if not Builder.open or pending then return end
    pending = true
    SetTimeout(400, function()
        pending = false
        if not Builder.open then return end
        local ok, data = call('live')
        if ok then UI.Send('builder', 'live', data) end
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    Placement.Abort()
    Builder.Close()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Builder.open then SetNuiFocus(false, false) end
end)

CreateThread(function()
    while not Framework.name do Wait(200) end
    RegisterCommand((Config.AdminCommand or {}).Builder or 'airdrops', function()
        Builder.Open()
    end, false)
end)
