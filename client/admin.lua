-- Admin panel: NUI plumbing.
--
-- Every callback here is a relay. Nothing is decided on this side — the server
-- re-checks permission on each one, because an admin panel that trusts its own
-- client is an admin panel anyone can open.

local panelOpen = false

local function openPanel()
    -- Asking the server rather than assuming: this is what stops a player who
    -- has found the command from getting a panel at all.
    local allowed, name = lib.callback.await('cipher-airdrops:server:canAdmin', false)
    if not allowed then
        Framework.Notify('You do not have permission for that.', 'error')
        return
    end

    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = { name = name } })
end

local function closePanel()
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('closePanel', function(_, cb)
    closePanel()
    cb({})
end)

RegisterCommand('airdrops', openPanel, false)

-- Live state pushes, so an admin watching the panel sees a drop land.
RegisterNetEvent('cipher-airdrops:client:refreshPanel', function()
    if panelOpen then SendNUIMessage({ action = 'refreshLive' }) end
end)

-- ── Relays ───────────────────────────────────────────────────────────────────
-- One shape for all of them: forward to the server callback of the same name
-- and hand the answer back. Listed explicitly rather than forwarding whatever
-- endpoint the page names, so a compromised page cannot reach arbitrary
-- server callbacks through this bridge.
local RELAYS = {
    'getLive', 'startDrop', 'cancelDrop',
    'getLocations', 'saveLocation', 'deleteLocation',
    'getLoot', 'saveTier', 'deleteTier', 'saveLoot', 'deleteLoot',
    'getHistory',
}

for _, name in ipairs(RELAYS) do
    RegisterNUICallback(name, function(data, cb)
        cb(lib.callback.await('cipher-airdrops:server:admin:' .. name, false, data) or {})
    end)
end

-- ── Local helpers the server has no business answering ───────────────────────

-- Where the admin is standing. Used by "use my current position", and read on
-- this client because that is the only place the answer exists.
RegisterNUICallback('getPosition', function(_, cb)
    local pos = GetEntityCoords(PlayerPedId())
    cb({ x = pos.x, y = pos.y, z = pos.z })
end)

RegisterNUICallback('teleport', function(data, cb)
    if not data or not data.x then cb({}) return end

    -- Straight to the ground rather than to the stored z: a location saved
    -- from a rooftop or a vehicle would otherwise drop the admin through the
    -- map or into the air.
    local ped = PlayerPedId()
    SetEntityCoords(ped, data.x + 0.0, data.y + 0.0, data.z + 1.0, false, false, false, false)

    -- Give the world a moment to stream in before asking for ground height.
    CreateThread(function()
        local deadline = GetGameTimer() + 5000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
            Wait(50)
        end

        local found, z = GetGroundZFor_3dCoord(data.x + 0.0, data.y + 0.0, data.z + 50.0, false)
        if found then
            SetEntityCoords(ped, data.x + 0.0, data.y + 0.0, z + 1.0, false, false, false, false)
        end
    end)

    cb({ ok = true })
end)
