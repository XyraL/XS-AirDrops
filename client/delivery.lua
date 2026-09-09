-- The plane, the parachute and the crate.
--
-- All of it is local to each client. Nothing here is networked, so there is no
-- entity for another player to own, damage or delete, and two clients rendering
-- slightly different smoke is a cost worth paying for that.

-- Particle assets have to be requested before use. Without this,
-- UseParticleFxAssetNextCall silently draws nothing, which looks exactly like
-- the effect not existing.
local function ensurePtfx()
    if HasNamedPtfxAssetLoaded('core') then return true end

    RequestNamedPtfxAsset('core')
    local deadline = GetGameTimer() + 5000
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < deadline do
        Wait(50)
    end

    return HasNamedPtfxAssetLoaded('core')
end

local warnedModel = {}

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)

    -- A bad model name used to return nil here and the caller gave up quietly,
    -- which means no crate spawns and the drop looks like it simply does not
    -- work. Say which model, once.
    if not IsModelValid(hash) then
        if not warnedModel[hash] then
            warnedModel[hash] = true
            print(('^1[XS-AirDrops]^0 "%s" is not a valid model — check Config.Delivery.')
                :format(tostring(model)))
        end
        return nil
    end

    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(50)
    end

    return HasModelLoaded(hash) and hash or nil
end

-- Spawns the crate the player can walk up to. Local, unnetworked, frozen.
-- Used when the configured model will not load, so a drop is never invisible.
local CRATE_FALLBACK = 'prop_mil_crate_01'

function AirdropSpawnCrate(coords)
    CreateThread(function()
        local hash = loadModel(Config.Delivery.CrateModel)

        if not hash then
            hash = loadModel(CRATE_FALLBACK)
            if not hash then
                print('^1[XS-AirDrops]^0 no crate model would load — the drop has nothing to open.')
                return
            end
        end

        local ground, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
        local placeZ = ground and z or coords.z

        local prop = CreateObject(hash, coords.x, coords.y, placeZ, false, false, false)
        PlaceObjectOnGroundProperly(prop)
        FreezeEntityPosition(prop, true)
        SetEntityInvincible(prop, true)
        SetModelAsNoLongerNeeded(hash)

        Airdrop.prop = prop

        -- Where it really ended up after the ground snap, which the reach check
        -- measures against.
        Airdrop.propCoords = GetEntityCoords(prop)
    end)
end

-- Smoke and a flare so the crate is findable from a distance once you are in
-- the right area. Runs for as long as the drop is on the ground.
CreateThread(function()
    while true do
        local wait = 1000
        local data = Airdrop.data

        if data and (data.state == 'landed' or data.state == 'open') and data.coords then
            local player = GetEntityCoords(PlayerPedId())
            local dist = #(player - vector3(data.coords.x, data.coords.y, data.coords.z))

            if dist < 300.0 and ensurePtfx() then
                -- One puff every 400ms rather than every frame: this is a
                -- landmark, not a fire, and per-frame particles at a busy drop
                -- are a measurable frame cost for no visual gain.
                wait = 400

                UseParticleFxAssetNextCall('core')
                StartParticleFxNonLoopedAtCoord(
                    'exp_grd_flare',
                    data.coords.x, data.coords.y, data.coords.z + 0.4,
                    0.0, 0.0, 0.0, 1.4, false, false, false)

                DrawLightWithRange(
                    data.coords.x, data.coords.y, data.coords.z + 1.0,
                    255, 120, 40, 8.0, 2.0)
            end
        end

        Wait(wait)
    end
end)

-- The flyover. Cosmetic: the server lands the crate on its own schedule, so a
-- client that never renders this still gets the drop.
function AirdropFlyover(target)
    CreateThread(function()
        local planeHash = loadModel(Config.Delivery.PlaneModel)
        if not planeHash then return end

        local alt = Config.Delivery.Altitude or 320.0
        local out = Config.Delivery.SpawnDistance or 900.0

        -- Approach on a random bearing so the plane does not always arrive from
        -- the same direction at the same place.
        local bearing = math.random() * math.pi * 2
        local startX = target.x + math.cos(bearing) * out
        local startY = target.y + math.sin(bearing) * out
        local endX   = target.x - math.cos(bearing) * out
        local endY   = target.y - math.sin(bearing) * out

        local plane = CreateVehicle(planeHash, startX, startY, alt, 0.0, false, false)
        SetEntityInvincible(plane, true)
        SetVehicleEngineOn(plane, true, true, false)
        SetEntityHeading(plane, math.deg(bearing) + 90.0)
        SetModelAsNoLongerNeeded(planeHash)

        -- Flown by moving it rather than by a pilot ped: no ped to sync, no AI
        -- deciding to land somewhere else, and it cannot be shot down.
        local speed = Config.Delivery.PlaneSpeed or 90.0
        local dropped = false
        local travelled = 0.0
        local total = #(vector3(endX, endY, alt) - vector3(startX, startY, alt))

        while travelled < total do
            local step = speed * 0.05
            travelled = travelled + step

            local t = travelled / total
            local x = startX + (endX - startX) * t
            local y = startY + (endY - startY) * t

            SetEntityCoordsNoOffset(plane, x, y, alt, true, true, true)

            -- Release roughly overhead.
            if not dropped and t >= 0.5 then
                dropped = true
                AirdropParachute(vector3(x, y, alt), target)
            end

            Wait(50)
        end

        if DoesEntityExist(plane) then DeleteEntity(plane) end
    end)
end

-- A visual crate descending under a chute. Purely for show — the real crate is
-- created by the server telling everyone it has landed.
function AirdropParachute(from, target)
    CreateThread(function()
        local hash = loadModel(Config.Delivery.CrateModel)
        if not hash then return end

        local crate = CreateObject(hash, from.x, from.y, from.z, false, false, false)
        SetEntityCollision(crate, false, false)
        SetModelAsNoLongerNeeded(hash)

        local z = from.z
        local groundZ = target.z

        while z > groundZ + 1.0 and DoesEntityExist(crate) do
            z = z - 1.2

            -- Drift toward the real landing spot as it falls, so the visual
            -- ends where the actual crate is rather than somewhere near it.
            local pos = GetEntityCoords(crate)
            local nx = pos.x + (target.x - pos.x) * 0.05
            local ny = pos.y + (target.y - pos.y) * 0.05

            SetEntityCoordsNoOffset(crate, nx, ny, z, true, true, true)
            SetEntityRotation(crate, 0.0, 0.0, (GetGameTimer() / 20) % 360, 2, true)

            if ensurePtfx() then
                UseParticleFxAssetNextCall('core')
                StartParticleFxNonLoopedAtCoord('exp_grd_flare', nx, ny, z, 0.0, 0.0, 0.0, 0.6, false, false, false)
            end

            Wait(50)
        end

        if DoesEntityExist(crate) then DeleteEntity(crate) end
    end)
end
