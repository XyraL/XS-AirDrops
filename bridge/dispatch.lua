Dispatch = { name = nil }

if not Config then return end

local IS_SERVER = IsDuplicityVersion()

local CANDIDATES = {
    'XS-Dispatch',
    'ps-dispatch',
    'qs-dispatch',
    'cd_dispatch',
    'core_dispatch',
    'rcore_dispatch',
    'linden_outlawalert',
}

do
    local forced = Config.Bridges and Config.Bridges.dispatch or 'auto'
    if forced == 'none' then
        Dispatch.name = nil
    elseif forced ~= 'auto' then
        Dispatch.name = forced
    else
        for _, r in ipairs(CANDIDATES) do
            if GetResourceState(r) == 'started' then Dispatch.name = r break end
        end
    end
end

local function policeJobs(a)
    local out = {}
    for _, j in ipairs((a and a.jobs) or (Config.Police or {}).Jobs or {}) do out[#out + 1] = j end
    if #out == 0 then out = { 'police' } end
    return out
end

if IS_SERVER then
    local function vec(c)
        return vector3((tonumber(c.x) or 0.0) + 0.0, (tonumber(c.y) or 0.0) + 0.0, (tonumber(c.z) or 0.0) + 0.0)
    end

    local Senders = {}

    Senders['XS-Dispatch'] = function(a)
        if a.partial then return false end
        exports['XS-Dispatch']:CreateCall({
            type = 'custom',
            code = a.code,
            title = a.title,
            description = a.description,
            priority = 2,
            coords = vec(a.coords),
            sprite = a.sprite,
            color = a.colour,
            caller = 'Air traffic control',
            origin = GetCurrentResourceName(),
        })
    end

    Senders['ps-dispatch'] = function(a, allow)
        local targets = {}
        for _, src in ipairs(Framework.PoliceSources(true)) do
            if not allow or allow(src) then targets[#targets + 1] = src end
        end
        local jobs = policeJobs(a)
        if not a.partial then jobs[#jobs + 1] = 'leo' end
        local alert = {
            message = a.title,
            codeName = 'xs_airdrop',
            code = a.code,
            icon = 'fas fa-parachute-box',
            priority = 2,
            coords = vec(a.coords),
            information = a.description,
            jobs = jobs,
            addToList = true,
            alert = {
                radius = 0, sprite = a.sprite, color = a.colour, scale = 1.0, length = 5,
                sound = 'Lose_1st', sound2 = 'GTAO_FM_Events_Soundset', offset = false, flash = false,
            },
        }
        local sent = pcall(function()
            exports['ps-dispatch']:SendTargetedAlert(targets, alert)
        end)
        if not sent then TriggerEvent('ps-dispatch:server:notify', alert) end
    end

    Senders['qs-dispatch'] = function(a)
        TriggerEvent('qs-dispatch:server:CreateDispatchCall', {
            job = policeJobs(a),
            callLocation = vec(a.coords),
            callCode = { code = a.code, snippet = a.title },
            message = a.description,
            flashes = false,
            image = nil,
            blip = { sprite = a.sprite, scale = 1.0, colour = a.colour, flashes = false, text = a.title, time = 300000 },
        })
    end

    Senders['cd_dispatch'] = function(a)
        TriggerClientEvent('cd_dispatch:AddNotification', -1, {
            job_table = policeJobs(a),
            coords = vec(a.coords),
            title = ('%s - %s'):format(a.code, a.title),
            message = a.description,
            flash = 0,
            unique_id = tostring(math.random(1000000, 9999999)),
            sound = 1,
            blip = { sprite = a.sprite, scale = 1.0, colour = a.colour, flashes = false, text = ('%s - %s'):format(a.code, a.title), time = 5, radius = 0 },
        })
    end

    Senders['core_dispatch'] = function(a)
        local extra = { { icon = 'fa-parachute-box', info = a.description } }
        local sent = pcall(function()
            exports['core_dispatch']:sendAlert({
                code = a.code, message = a.title, extraInfo = extra, coords = vec(a.coords),
                priority = false, job = policeJobs(a), time = 30000, blip = a.sprite, color = a.colour,
            })
        end)
        if sent then return end
        local c = vec(a.coords)
        for _, job in ipairs(policeJobs(a)) do
            TriggerEvent('core_dispatch:addCall', a.code, a.title, extra, { c.x, c.y, c.z }, job, 30000, a.sprite, a.colour, false)
        end
    end

    Senders['rcore_dispatch'] = function(a)
        TriggerEvent('rcore_dispatch:server:sendAlert', {
            code = ('%s - %s'):format(a.code, a.title),
            default_priority = 'medium',
            coords = vec(a.coords),
            job = policeJobs(a),
            text = a.description,
            type = 'alerts',
            blip = { sprite = a.sprite, colour = a.colour, scale = 1.0, text = a.title, flashes = false, radius = 0 },
        })
    end

    Senders['linden_outlawalert'] = function(a)
        TriggerEvent('wf-alerts:svNotify', {
            dispatchData = {
                displayCode = a.code, description = a.title, isImportant = 0, recipientList = policeJobs(a),
                length = 10000, infoM = 'fa-info-circle', info = a.description,
                blipSprite = a.sprite, blipColour = a.colour, blipScale = 1.0,
            },
            caller = 'Air traffic control',
            coords = vec(a.coords),
        })
    end

    function Dispatch.Alert(a, allow)
        a.code = a.code or '10-66'
        a.title = a.title or 'Unregistered Cargo Drop'
        a.description = a.description or 'Aircraft seen dropping cargo. Several parties likely heading there.'
        a.sprite = a.sprite or 478
        a.colour = a.colour or 1

        local sender = Dispatch.name and Senders[Dispatch.name]
        if sender and GetResourceState(Dispatch.name) == 'started' then
            local ok, res = pcall(sender, a, allow)
            if ok and res ~= false then return Dispatch.name end
            if not ok then
                print(('^3[XS-AirDrops]^0 %s refused the alert (%s). Police get a plain notification instead.')
                    :format(Dispatch.name, tostring(res)))
            end
        end

        for _, src in ipairs(Framework.PoliceSources(false)) do
            if not allow or allow(src) then TriggerClientEvent('XS-AirDrops:client:policeAlert', src, a) end
        end
        return 'notify'
    end
end
