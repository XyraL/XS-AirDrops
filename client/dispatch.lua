-- Police alert when a crate lands.
--
-- An unregistered aircraft dropping cargo is a legitimate police matter, and
-- giving law enforcement a reason to attend turns a two-way gang fight into a
-- three-way one. That is the most interesting thing this script can do to a
-- server that already has both.
--
-- Detection order matters: cipher-dispatch first because it is ours and gets
-- the richest call, then the common community ones, then a plain notification
-- so a server with no dispatch resource still gets told.

local function isPolice()
    local job = Framework.GetPlayerData and Framework.GetPlayerData()
    local name = job and job.job and job.job.name
    if not name then return false end

    for _, allowed in ipairs(Config.Police.Jobs or {}) do
        if name == allowed then return true end
    end
    return false
end

local function detectDispatch()
    local candidates = {
        'cipher-dispatch',
        'ps-dispatch',
        'qs-dispatch',
        'cd_dispatch',
        'core_dispatch',
        'rcore_dispatch',
        'origen_police',
    }

    for _, resource in ipairs(candidates) do
        if GetResourceState(resource) == 'started' then return resource end
    end
    return nil
end

RegisterNetEvent('cipher-airdrops:client:policeAlert', function(data)
    -- Every client receives this; only officers act on it. Filtering here
    -- rather than server-side keeps the job lookup on the machine that already
    -- knows the answer.
    if not isPolice() then return end

    local coords = vector3(data.coords.x, data.coords.y, data.coords.z)
    local provider = detectDispatch()

    if provider == 'cipher-dispatch' then
        exports['cipher-dispatch']:CustomAlert({
            code = data.code or '10-66',
            title = data.title or 'Unregistered Cargo Drop',
            description = 'Aircraft observed dropping cargo. Multiple parties likely responding.',
            coords = coords,
            priority = 2,
            jobs = data.jobs,
            blip = { sprite = Config.Blip.Sprite or 478, colour = Config.Blip.Colour or 5, scale = 1.0, time = 300 },
        })
        return
    end

    if provider == 'ps-dispatch' then
        exports['ps-dispatch']:CustomAlert({
            coords = coords,
            message = data.title or 'Unregistered Cargo Drop',
            dispatchCode = data.code or '10-66',
            description = 'Aircraft observed dropping cargo',
            radius = 0,
            sprite = Config.Blip.Sprite or 478,
            color = Config.Blip.Colour or 5,
            scale = 1.0,
            length = 5,
        })
        return
    end

    if provider == 'qs-dispatch' then
        exports['qs-dispatch']:VehicleShooting({
            displayCode = data.code or '10-66',
            description = data.title or 'Unregistered Cargo Drop',
            radius = 0,
            coords = coords,
        })
        return
    end

    if provider == 'cd_dispatch' then
        TriggerEvent('cd_dispatch:AddNotification', {
            job_table = data.jobs,
            coords = coords,
            title = (data.code or '10-66') .. ' - ' .. (data.title or 'Cargo Drop'),
            message = 'Aircraft observed dropping cargo',
            flash = 0,
            unique_id = tostring(math.random(10000000, 99999999)),
            blip = { sprite = Config.Blip.Sprite or 478, scale = 1.0, colour = Config.Blip.Colour or 5, time = 5 },
        })
        return
    end

    if provider == 'core_dispatch' then
        TriggerServerEvent('core_dispatch:addCall',
            data.code or '10-66', data.title or 'Cargo Drop',
            { { icon = 'fa-parachute-box', info = 'Unregistered aircraft' } },
            { coords.x, coords.y, coords.z },
            data.jobs, 30000, Config.Blip.Sprite or 478, Config.Blip.Colour or 5)
        return
    end

    -- No dispatch resource: say it plainly and put a blip down, because an
    -- alert nobody can find is not an alert.
    Framework.Notify(
        ('%s — %s'):format(data.code or '10-66', data.title or 'Unregistered cargo drop'),
        'inform', 'Dispatch')

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.Blip.Sprite or 478)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.title or 'Cargo Drop')
    EndTextCommandSetBlipName(blip)

    SetTimeout(300000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)
