if not IsDuplicityVersion() and type(RegisterNUICallback) == 'function' then
    local _registerNUI = RegisterNUICallback

    RegisterNUICallback = function(name, handler)
        return _registerNUI(name, function(data, cb)
            CreateThread(function()
                handler(data, function(payload, ...)
                    if payload == nil then payload = false end
                    cb(payload, ...)
                end)
            end)
        end)
    end
end

Framework = { name = nil, core = nil }

if not Config then
    print(('^1[XS-AirDrops]^0 config.lua did not load, so this resource cannot start.\n'
        .. '  Almost always start order. In server.cfg, these must come first:\n'
        .. '    ensure ox_lib\n'
        .. '    ensure oxmysql\n'
        .. '    ensure %s'):format(GetCurrentResourceName()))
    return
end

local forced = Config.Bridges and Config.Bridges.framework or 'auto'

if forced == 'qbox' or forced == 'qbx_core' or (forced == 'auto' and GetResourceState('qbx_core') == 'started') then
    Framework.name = 'qbox'
elseif forced == 'qbcore' or forced == 'qb-core' or (forced == 'auto' and GetResourceState('qb-core') == 'started') then
    Framework.name = 'qbcore'
    Framework.core = exports['qb-core']:GetCoreObject()
else
    print('^1[XS-AirDrops]^0 No supported framework found. Start qbx_core or qb-core before XS-AirDrops.')
end

local IS_SERVER = IsDuplicityVersion()

if IS_SERVER then
    function Framework.GetPlayer(src)
        if Framework.name == 'qbox' then
            return exports.qbx_core:GetPlayer(src)
        elseif Framework.core then
            return Framework.core.Functions.GetPlayer(src)
        end
    end

    function Framework.GetCitizenId(src)
        local player = Framework.GetPlayer(src)
        return player and player.PlayerData.citizenid or nil
    end

    function Framework.GetName(src)
        local player = Framework.GetPlayer(src)
        if not player then return nil end
        local ci = player.PlayerData.charinfo or {}
        if not ci.firstname then return nil end
        return ('%s %s'):format(ci.firstname, ci.lastname or '')
    end

    function Framework.GetJob(src)
        local player = Framework.GetPlayer(src)
        if not player then return nil end
        local j = player.PlayerData.job or {}
        return {
            name    = j.name,
            grade   = (type(j.grade) == 'table') and j.grade.level or j.grade,
            onDuty  = j.onduty,
            label   = j.label,
        }
    end

    function Framework.GetGang(src)
        local player = Framework.GetPlayer(src)
        if not player then return nil end

        local g = player.PlayerData.gang
        if not g or not g.name or g.name == 'none' or g.name == '' then return nil end

        return {
            name  = g.name,
            grade = (type(g.grade) == 'table') and g.grade.level or g.grade,
            label = g.label,
        }
    end

    function Framework.PoliceSources(onDutyOnly)
        local jobs = {}
        for _, j in ipairs((Config.Police or {}).Jobs or {}) do jobs[j] = true end
        local out = {}
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local job = src and Framework.GetJob(src)
            if job and jobs[job.name] and (not onDutyOnly or job.onDuty ~= false) then
                out[#out + 1] = src
            end
        end
        return out
    end

    local function groupList(source)
        local out = {}
        for name, data in pairs(source or {}) do
            if type(data) == 'table' and name ~= 'none' then
                out[#out + 1] = { name = name, label = data.label or name }
            end
        end
        table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
        return out
    end

    function Framework.Jobs()
        local ok, list = pcall(function()
            if Framework.name == 'qbox' then return exports.qbx_core:GetJobs() end
            return Framework.core and Framework.core.Shared.Jobs or {}
        end)
        return groupList(ok and list or {})
    end

    function Framework.Gangs()
        local ok, list = pcall(function()
            if Framework.name == 'qbox' then return exports.qbx_core:GetGangs() end
            return Framework.core and Framework.core.Shared.Gangs or {}
        end)
        return groupList(ok and list or {})
    end

    function Framework.IsAdmin(src)
        local A = Config.Admin or {}
        if A.acePermission and IsPlayerAceAllowed(src, A.acePermission) then return true end
        for _, lic in ipairs(A.licenses or {}) do
            if GetPlayerIdentifierByType(src, 'license') == lic then return true end
        end
        local groups = A.groups or {}
        if Framework.name == 'qbox' then
            for _, g in ipairs(groups) do
                if exports.qbx_core:HasPermission(src, g) then return true end
            end
        elseif Framework.core then
            for _, g in ipairs(groups) do
                if Framework.core.Functions.HasPermission(src, g) then return true end
            end
        end
        return false
    end

    function Framework.CanBuild(src)
        if Framework.IsAdmin(src) then return true end
        for _, ace in ipairs((Config.AdminCommand or {}).Aces or {}) do
            if IsPlayerAceAllowed(src, ace) then return true end
        end
        return false
    end

    function Framework.Notify(src, msg, type, title)
        local NS = Config.NotifyStyle or {}
        TriggerClientEvent('ox_lib:notify', src, {
            title = title or (NS.title ~= '' and NS.title or nil),
            description = msg,
            type = type or 'inform',
            position = NS.position,
            duration = NS.duration,
            icon = NS.icon ~= '' and NS.icon or nil,
        })
    end
else
    function Framework.GetPlayerData()
        if Framework.name == 'qbox' then
            return exports.qbx_core:GetPlayerData()
        elseif Framework.core then
            return Framework.core.Functions.GetPlayerData()
        end
    end

    function Framework.Notify(msg, type, title)
        local NS = Config.NotifyStyle or {}
        lib.notify({
            title = title or (NS.title ~= '' and NS.title or nil),
            description = msg,
            type = type or 'inform',
            position = NS.position,
            duration = NS.duration,
            icon = NS.icon ~= '' and NS.icon or nil,
        })
    end
end

if Config.Debug then
    print(('^2[XS-AirDrops]^0 framework bridge loaded (%s) on %s'):format(
        Framework.name or 'none', IS_SERVER and 'server' or 'client'))
end
