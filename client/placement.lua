Placement = { active = false }

local cam, ghost, preview, resolve, opts

local KEYS = {
    confirm = 191, cancel = 194, forward = 32, back = 33, left = 34, right = 35, up = 22, down = 36,
    fast = 21, slow = 19, drop = 73,
}

local function camForward()
    local rot = GetCamRot(cam, 2)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local cosX = math.abs(math.cos(x))
    return vector3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x))
end

local function aim(distance)
    local from = GetCamCoord(cam)
    local to = from + camForward() * distance
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, preview or PlayerPedId(), 4)
    local _, hit, coords = GetShapeTestResult(ray)
    if hit == true or hit == 1 then return coords, true end
    return to, false
end

local function stopPreview()
    if preview and DoesEntityExist(preview) then DeleteEntity(preview) end
    preview = nil
end

local function startPreview(model)
    stopPreview()
    local hash = AirdropLoadModel(model) or AirdropLoadModel('prop_mil_crate_01')
    if not hash then return end
    preview = CreateObjectNoOffset(hash, ghost.x, ghost.y, ghost.z, false, false, false)
    SetEntityAlpha(preview, 170, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    SetModelAsNoLongerNeeded(hash)
end

local function ring(x, y, z, radius, r, g, b, a)
    if not radius or radius <= 0 then return end
    DrawMarker(1, x + 0.0, y + 0.0, z - 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2.0, radius * 2.0, 4.0, r, g, b, a, false, false, 2, false, nil, nil, false)
end

local function drawExisting()
    if (Config.Builder or {}).showExisting == false then return end
    for _, p in ipairs(opts.existing or {}) do
        DrawMarker(2, p.x + 0.0, p.y + 0.0, p.z + 2.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.8, 0.8, 0.8, 255, 180, 137, 200, true, false, 2, false, nil, nil, false)
        DrawLine(p.x + 0.0, p.y + 0.0, p.z + 0.0, p.x + 0.0, p.y + 0.0, p.z + 40.0, 255, 180, 137, 160)
    end
end

local function finish(result)
    if cam then
        RenderScriptCams(false, true, 300, true, true)
        SetCamActive(cam, false)
        DestroyCam(cam, true)
        cam = nil
    end
    stopPreview()
    ClearFocus()
    FreezeEntityPosition(PlayerPedId(), false)
    lib.hideTextUI()
    Placement.active = false
    local done = resolve
    resolve = nil
    if done then done(result) end
end

function Placement.Start(options)
    if Placement.active then return nil end
    opts = options or {}
    local ped = PlayerPedId()
    local origin = opts.origin and vector3(opts.origin.x + 0.0, opts.origin.y + 0.0, opts.origin.z + 0.0) or GetEntityCoords(ped)
    ghost = { x = origin.x, y = origin.y, z = origin.z, locked = false }

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, origin.x, origin.y, origin.z + 12.0)
    SetCamRot(cam, -35.0, 0.0, GetEntityHeading(ped), 2)
    SetCamFov(cam, 60.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 300, true, true)
    FreezeEntityPosition(ped, true)
    Placement.active = true

    lib.showTextUI(table.concat({
        ('**%s**'):format(opts.label or 'Place a landing point'),
        '[Enter] place here · [Backspace] cancel',
        '[W A S D] fly · [Space / Ctrl] up and down',
        '[Shift] faster · [Alt] slower · [X] drop to the ground',
    }, '\n'), { position = 'left-center' })

    startPreview(opts.model)

    local promised = promise.new()
    resolve = function(value) promised:resolve(value) end

    CreateThread(function()
        local speeds = (Config.Builder or {}).cameraSpeed or { normal = 8.0, fast = 40.0, slow = 1.5 }
        local radius = (tonumber(opts.radius) or 0) + 0.0
        local approx = (tonumber(opts.approx) or 0) + 0.0
        while Placement.active do
            Wait(0)
            if not Placement.active then break end
            DisableAllControlActions(0)
            EnableControlAction(0, KEYS.confirm, true)
            EnableControlAction(0, KEYS.cancel, true)

            local pos = GetCamCoord(cam)
            local rot = GetCamRot(cam, 2)
            local dx = GetDisabledControlNormal(0, 1) * 6.0
            local dy = GetDisabledControlNormal(0, 2) * 6.0
            SetCamRot(cam, math.max(-89.0, math.min(89.0, rot.x - dy)), 0.0, rot.z - dx, 2)

            local speed = speeds.normal or 8.0
            if IsDisabledControlPressed(0, KEYS.fast) then speed = speeds.fast or 40.0 end
            if IsDisabledControlPressed(0, KEYS.slow) then speed = speeds.slow or 1.5 end
            speed = speed * GetFrameTime()
            local fwd = camForward()
            local right = vector3(fwd.y, -fwd.x, 0.0)
            local move = vector3(0.0, 0.0, 0.0)
            if IsDisabledControlPressed(0, KEYS.forward) then move = move + fwd end
            if IsDisabledControlPressed(0, KEYS.back) then move = move - fwd end
            if IsDisabledControlPressed(0, KEYS.right) then move = move + right end
            if IsDisabledControlPressed(0, KEYS.left) then move = move - right end
            if IsDisabledControlPressed(0, KEYS.up) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsDisabledControlPressed(0, KEYS.down) then move = move - vector3(0.0, 0.0, 1.0) end
            if #move > 0.0 then
                pos = pos + move * speed
                SetCamCoord(cam, pos.x, pos.y, pos.z)
                ghost.locked = false
            end
            SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)

            if not ghost.locked then
                local hit = aim(600.0)
                ghost.x, ghost.y, ghost.z = hit.x, hit.y, hit.z
            end

            if IsDisabledControlJustPressed(0, KEYS.drop) then
                local ray = StartExpensiveSynchronousShapeTestLosProbe(ghost.x, ghost.y, ghost.z + 2.0, ghost.x, ghost.y, ghost.z - 200.0, 1 + 16, preview or PlayerPedId(), 4)
                local _, floorHit, floor = GetShapeTestResult(ray)
                if floorHit == true or floorHit == 1 then
                    ghost.z = floor.z
                    ghost.locked = true
                end
            end

            if preview and DoesEntityExist(preview) then
                SetEntityCoordsNoOffset(preview, ghost.x, ghost.y, ghost.z, false, false, false)
            end
            DrawMarker(28, ghost.x, ghost.y, ghost.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 255, 180, 137, 200, false, false, 2, false, nil, nil, false)
            DrawLine(ghost.x, ghost.y, ghost.z, ghost.x, ghost.y, ghost.z + 60.0, 255, 140, 70, 220)
            ring(ghost.x, ghost.y, ghost.z, radius, 255, 70, 60, 60)
            ring(ghost.x, ghost.y, ghost.z, approx, 255, 200, 60, 25)
            drawExisting()

            if IsDisabledControlJustPressed(0, KEYS.confirm) then
                finish({ x = ghost.x, y = ghost.y, z = ghost.z })
                break
            end
            if IsDisabledControlJustPressed(0, KEYS.cancel) then
                finish(nil)
                break
            end
        end
    end)

    return Citizen.Await(promised)
end

function Placement.Abort()
    if Placement.active then finish(nil) end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Placement.Abort() end
end)
