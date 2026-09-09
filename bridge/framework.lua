-- ─────────────────────────────────────────────────────────────
-- Framework bridge
-- Auto-detects QBox (qbx_core) or QBCore (qb-core) and exposes ONE API
-- so the rest of the resource never branches on framework. ox_lib and
-- oxmysql are used directly elsewhere since both frameworks ship with them.
-- Force a backend via Config.Bridges.framework.
-- ─────────────────────────────────────────────────────────────
Framework = { name = nil, core = nil }

-- config.lua is a shared_script sitting next to @ox_lib/init.lua. If ox_lib has
-- not started yet, that whole block can fail to run, config.lua never executes,
-- and every file after it sees Config as nil.
--
-- Without this you get three "attempt to index a nil value (global 'Config')"
-- errors pointing at the bridges and server/main, none of which is the actual
-- problem. This is the first file to load in both contexts, so it is where the
-- real cause gets named.
if not Config then
    print(('^1[XS-AirDrops]^0 config.lua did not load, so this resource cannot start.\n'
        .. '  Almost always start order. In server.cfg, these must come first:\n'
        .. '    ensure ox_lib\n'
        .. '    ensure oxmysql\n'
        .. '    ensure %s'):format(GetCurrentResourceName()))
    return
end

local forced = Config.Bridges and Config.Bridges.framework or 'auto'

if forced == 'qbox' or (forced == 'auto' and GetResourceState('qbx_core') == 'started') then
    Framework.name = 'qbox'
elseif forced == 'qbcore' or (forced == 'auto' and GetResourceState('qb-core') == 'started') then
    Framework.name = 'qbcore'
    Framework.core = exports['qb-core']:GetCoreObject()
else
    print('^1[XS-AirDrops]^0 No supported framework found. Start qbx_core or qb-core before XS-AirDrops.')
end

local IS_SERVER = IsDuplicityVersion()

if IS_SERVER then
    -- ── Player lookups ──────────────────────────────────────
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
        local ci = player.PlayerData.charinfo
        return ('%s %s'):format(ci.firstname, ci.lastname)
    end

    function Framework.GetJob(src)
        local player = Framework.GetPlayer(src)
        if not player then return nil end
        local j = player.PlayerData.job
        return {
            name    = j.name,
            grade   = (type(j.grade) == 'table') and j.grade.level or j.grade,
            onDuty  = j.onduty,
            label   = j.label,
        }
    end

    -- Gangs, for access rules that key on them. Both frameworks keep gang
    -- alongside job in PlayerData; a character with no gang returns nil rather
    -- than the "none" placeholder QBCore uses, so callers can test it plainly.
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

    -- Online src for a citizenid, or nil.
    function Framework.GetPlayerByCitizenId(citizenid)
        if Framework.name == 'qbox' then
            local p = exports.qbx_core:GetPlayerByCitizenId(citizenid)
            return p and p.PlayerData.source or nil
        elseif Framework.core then
            local p = Framework.core.Functions.GetPlayerByCitizenId(citizenid)
            return p and p.PlayerData.source or nil
        end
    end

    -- "First Last" for a citizenid (online or from the DB). charinfo is JSON
    -- on the `players` table in both frameworks.
    function Framework.GetNameByCitizenId(citizenid)
        local online = Framework.GetPlayerByCitizenId(citizenid)
        if online then return Framework.GetName(online) end
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
        if row then
            local ci = json.decode(row.charinfo or '{}') or {}
            if ci.firstname then return ('%s %s'):format(ci.firstname, ci.lastname or '') end
        end
        return citizenid
    end

    -- All on-duty players holding one of the given job names.
    function Framework.GetPlayersByJobs(jobNames)
        local jobSet = {}
        for _, j in ipairs(jobNames or {}) do jobSet[j] = true end
        local out = {}
        for _, sid in ipairs(GetPlayers()) do
            sid = tonumber(sid)
            local job = Framework.GetJob(sid)
            if job and jobSet[job.name] and job.onDuty ~= false then
                out[#out + 1] = sid
            end
        end
        return out
    end

    -- ── Money (cash/bank via framework) ─────────────────────
    function Framework.AddMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddMoney(account, amount, reason or 'XS-AirDrops')
    end

    function Framework.RemoveMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.RemoveMoney(account, amount, reason or 'XS-AirDrops')
    end

    function Framework.GetMoney(src, account)
        local player = Framework.GetPlayer(src)
        if not player then return 0 end
        return player.PlayerData.money[account] or 0
    end

    -- Admin check: ACE, framework group, or explicit license (Config.Admin).
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

    -- Branded, icon-led notification. `title` overrides the default header.
    function Framework.Notify(src, msg, type, title)
        local NS = Config.NotifyStyle or {}
        local ico = (NS.icons or {})[type or 'inform'] or {}
        TriggerClientEvent('ox_lib:notify', src, {
            title = title or (NS.title ~= false and NS.title or nil),
            description = msg,
            type = type or 'inform',
            position = NS.position,
            duration = NS.duration,
            icon = ico.icon,
            iconColor = ico.color,
        })
    end
else
    -- ── Client ──────────────────────────────────────────────
    function Framework.GetPlayerData()
        if Framework.name == 'qbox' then
            return exports.qbx_core:GetPlayerData()
        elseif Framework.core then
            return Framework.core.Functions.GetPlayerData()
        end
    end

    function Framework.Notify(msg, type, title)
        local NS = Config.NotifyStyle or {}
        local ico = (NS.icons or {})[type or 'inform'] or {}
        lib.notify({
            title = title or (NS.title ~= false and NS.title or nil),
            description = msg,
            type = type or 'inform',
            position = NS.position,
            duration = NS.duration,
            icon = ico.icon,
            iconColor = ico.color,
        })
    end
end

if Config and Config.Debug then
    print(('^2[XS-AirDrops]^0 framework bridge loaded (%s) on %s'):format(
        Framework.name or 'none', IS_SERVER and 'server' or 'client'))
end
