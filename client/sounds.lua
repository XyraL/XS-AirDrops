function PlayDropSound(key)
    local cfg = Config.Sounds
    if not cfg or not cfg.Enabled then return end
    local sound = (cfg.Events or {})[key]
    if not sound or not sound.name then return end
    PlaySoundFrontend(-1, sound.name, sound.set, true)
end

local seen = {}

CreateThread(function()
    while true do
        Wait(250)
        for id, e in pairs(Airdrop.drops) do
            local state = e.data and e.data.state
            if state ~= seen[id] then
                if seen[id] ~= nil or state == 'announced' then
                    if state == 'announced' then
                        PlayDropSound('announced')
                    elseif state == 'landed' then
                        PlayDropSound('landed')
                    elseif state == 'open' then
                        PlayDropSound('opened')
                    end
                end
                seen[id] = state
            end
        end
        for id in pairs(seen) do
            if not Airdrop.drops[id] then seen[id] = nil end
        end
    end
end)

CreateThread(function()
    local lastTick
    while true do
        Wait(200)
        local cfg = Config.Sounds
        local soonest
        if cfg and cfg.Enabled and cfg.CountdownTicks then
            for _, e in pairs(Airdrop.drops) do
                local data = e.data
                if data and (data.state == 'announced' or data.state == 'inbound') and data.landsAtMs then
                    if not soonest or data.landsAtMs < soonest then soonest = data.landsAtMs end
                end
            end
        end
        if soonest then
            local remaining = math.ceil((soonest - GetGameTimer()) / 1000)
            if remaining > 0 and remaining <= 10 and remaining ~= lastTick then
                lastTick = remaining
                PlayDropSound('tick')
            elseif remaining <= 0 then
                lastTick = nil
            end
        else
            lastTick = nil
        end
    end
end)
