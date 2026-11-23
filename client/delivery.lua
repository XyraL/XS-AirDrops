local FALLBACK = 'prop_mil_crate_01'
local CHUTE = 'p_cargo_chute_s'
local warned = {}

local function ensurePtfx()
    if HasNamedPtfxAssetLoaded('core') then return true end
    RequestNamedPtfxAsset('core')
    local deadline = GetGameTimer() + 5000
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < deadline do Wait(50) end
    return HasNamedPtfxAssetLoaded('core')
end

function AirdropLoadModel(model)
    if not model or model == '' then return nil end
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then
        if not warned[hash] then
            warned[hash] = true
            print(('^1[XS-AirDrops]^0 "%s" is not a valid model. Check the crate type in /airdrops.'):format(tostring(model)))
        end
        return nil
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(50) end
    return HasModelLoaded(hash) and hash or nil
end

function AirdropRemoveCrate(e)
    e.gen = (e.gen or 0) + 1
    if e.prop then
        if CrateTargetRemove then CrateTargetRemove(e) end
        if DoesEntityExist(e.prop) then DeleteEntity(e.prop) end
    end
    e.prop, e.propCoords, e.placed, e.spawning = nil, nil, nil, nil
end

function AirdropSpawnCrate(e)
    if e.spawning or e.prop then return end
    e.spawning = true
    local gen = e.gen or 0
    CreateThread(function()
        local hash = AirdropLoadModel(e.data.crate.model) or AirdropLoadModel(FALLBACK)
        e.spawning = false
        if not hash then
            print('^1[XS-AirDrops]^0 no crate model would load, so this drop has nothing to open.')
            return
        end
        if Airdrop.drops[e.id] ~= e or (e.gen or 0) ~= gen or e.prop then
            SetModelAsNoLongerNeeded(hash)
            return
        end
        local c = e.data.coords
        local prop = CreateObject(hash, c.x, c.y, c.z, false, false, false)
        SetEntityInvincible(prop, true)
        FreezeEntityPosition(prop, true)
        SetModelAsNoLongerNeeded(hash)
        e.prop = prop
        e.propCoords = GetEntityCoords(prop)
        if CrateTargetAdd then CrateTargetAdd(e) end
    end)
end

local function settle(e)
    if e.placed or not e.prop or not DoesEntityExist(e.prop) then return end
    if not HasCollisionLoadedAroundEntity(e.prop) then return end
    local c = e.data.coords
    local ray = StartExpensiveSynchronousShapeTestLosProbe(c.x, c.y, c.z + 1.5, c.x, c.y, c.z - 8.0, 1 + 16, e.prop, 4)
    local _, hit, at = GetShapeTestResult(ray)
    if hit == true or hit == 1 then
        SetEntityCoords(e.prop, at.x, at.y, at.z, false, false, false, false)
    end
    PlaceObjectOnGroundProperly(e.prop)
    FreezeEntityPosition(e.prop, true)
    e.propCoords = GetEntityCoords(e.prop)
    e.placed = true
end

CreateThread(function()
    while true do
        local wait = 1000
        local pos = GetEntityCoords(PlayerPedId())
        local now = GetGameTimer()
        for _, e in pairs(Airdrop.drops) do
            local data = e.data
            if data and (data.state == 'landed' or data.state == 'open') then
                local c = e.propCoords or data.coords
                local dist = #(pos - c)
                if dist < 160.0 then settle(e) end
                if dist < 320.0 and not data.emptied and (data.crate.flare or data.crate.smoke) and ensurePtfx() then
                    wait = math.min(wait, 200)
                    if data.crate.flare and now >= (e.flareAt or 0) then
                        e.flareAt = now + 400
                        UseParticleFxAssetNextCall('core')
                        StartParticleFxNonLoopedAtCoord('exp_grd_flare', c.x, c.y, c.z + 0.4, 0.0, 0.0, 0.0, 1.4, false, false, false)
                    end
                    if data.crate.smoke and now >= (e.smokeAt or 0) then
                        e.smokeAt = now + 2500
                        UseParticleFxAssetNextCall('core')
                        StartParticleFxNonLoopedAtCoord('exp_grd_grenade_smoke', c.x, c.y, c.z + 0.6, 0.0, 0.0, 0.0, 1.0, false, false, false)
                    end
                end
            end
        end
        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        local wait = 1000
        local pos = GetEntityCoords(PlayerPedId())
        for _, e in pairs(Airdrop.drops) do
            local data = e.data
            if data and data.crate and data.crate.flare and not data.emptied and (data.state == 'landed' or data.state == 'open') then
                local c = e.propCoords or data.coords
                if #(pos - c) < 320.0 then
                    wait = 0
                    DrawLightWithRange(c.x, c.y, c.z + 1.0, 255, 120, 40, 8.0, 2.0)
                end
            end
        end
        Wait(wait)
    end
end)

local function parachute(e, from)
    CreateThread(function()
        local crate = e.data.crate
        local hash = AirdropLoadModel(crate.model) or AirdropLoadModel(FALLBACK)
        if not hash then return end
        local target = e.data.coords
        local box = CreateObject(hash, from.x, from.y, from.z, false, false, false)
        SetEntityCollision(box, false, false)
        SetEntityInvincible(box, true)
        SetModelAsNoLongerNeeded(hash)

        local chute
        if crate.parachute then
            local chuteHash = AirdropLoadModel(CHUTE)
            if chuteHash then
                chute = CreateObject(chuteHash, from.x, from.y, from.z, false, false, false)
                SetEntityCollision(chute, false, false)
                AttachEntityToEntity(chute, box, 0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                SetModelAsNoLongerNeeded(chuteHash)
                RequestAnimDict(CHUTE)
                local until_ = GetGameTimer() + 1000
                while not HasAnimDictLoaded(CHUTE) and GetGameTimer() < until_ do Wait(10) end
                if HasAnimDictLoaded(CHUTE) then
                    PlayEntityAnim(chute, 'p_cargo_chute_s_deploy', CHUTE, 1000.0, false, true, false, 0.0, 0)
                end
            end
        end

        local speed = crate.parachute and Util.FALL_CHUTE or Util.FALL_FREE
        local z = from.z
        local last = GetGameTimer()
        local puff = 0
        while z > target.z + 0.6 and Airdrop.drops[e.id] == e and e.data.state == 'inbound' and DoesEntityExist(box) do
            local now = GetGameTimer()
            z = z - speed * ((now - last) / 1000)
            last = now
            SetEntityCoordsNoOffset(box, target.x, target.y, math.max(z, target.z + 0.6), false, false, false)
            SetEntityRotation(box, 0.0, 0.0, (now / 40) % 360, 2, true)
            if crate.flare and now >= puff and ensurePtfx() then
                puff = now + 250
                UseParticleFxAssetNextCall('core')
                StartParticleFxNonLoopedAtCoord('exp_grd_flare', target.x, target.y, z, 0.0, 0.0, 0.0, 0.6, false, false, false)
            end
            Wait(0)
        end

        while Airdrop.drops[e.id] == e and e.data.state == 'inbound' do Wait(100) end
        if chute and DoesEntityExist(chute) then DeleteEntity(chute) end
        if DoesEntityExist(box) then DeleteEntity(box) end
    end)
end

function AirdropFlyover(e)
    CreateThread(function()
        local data = e.data
        local crate = data.crate
        local target = data.coords
        local alt = target.z + (crate.altitude or 320.0)
        local out = (Config.Delivery.SpawnDistance or 900.0) + 0.0
        local speed = math.max(10.0, (Config.Delivery.PlaneSpeed or 90.0) + 0.0)
        local heading = (data.heading or 0) + 0.0
        local h = math.rad(heading)
        local dir = vector3(-math.sin(h), math.cos(h), 0.0)
        local start = vector3(target.x, target.y, alt) - dir * out

        local planeHash = AirdropLoadModel(crate.plane)
        local plane
        if planeHash then
            plane = CreateVehicle(planeHash, start.x, start.y, start.z, heading, false, false)
            SetEntityInvincible(plane, true)
            SetEntityCollision(plane, false, false)
            SetVehicleEngineOn(plane, true, true, false)
            SetModelAsNoLongerNeeded(planeHash)
        end

        local total = out * 2.0
        local travelled = 0.0
        local dropped = false
        local last = GetGameTimer()
        while travelled < total and Airdrop.drops[e.id] == e do
            local now = GetGameTimer()
            travelled = travelled + speed * ((now - last) / 1000)
            last = now
            if plane and DoesEntityExist(plane) then
                local pos = start + dir * travelled
                SetEntityCoordsNoOffset(plane, pos.x, pos.y, pos.z, false, false, false)
                SetEntityHeading(plane, heading)
            end
            if not dropped and travelled >= out then
                dropped = true
                if e.data.state == 'inbound' then parachute(e, vector3(target.x, target.y, alt - 6.0)) end
            end
            Wait(0)
        end

        if plane and DoesEntityExist(plane) then DeleteEntity(plane) end
    end)
end
