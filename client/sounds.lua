-- Audio cues.
--
-- Native GTA frontend sounds only, so there is nothing to stream and no audio
-- files in the resource. Same approach as cipher-drugs.
--
-- Cues are driven off the state the server already sends, rather than being
-- fired by separate events. One less thing to keep in step, and a player who
-- joins mid-drop gets the audio state that matches what they are actually
-- looking at instead of a sting for something that happened before they
-- connected.

function PlayDropSound(key)
    local cfg = Config.Sounds
    if not cfg or not cfg.Enabled then return end

    local sound = (cfg.Events or {})[key]
    if not sound or not sound.name then return end

    PlaySoundFrontend(-1, sound.name, sound.set, true)
end

-- State transitions worth hearing. Tracked here rather than in client/main.lua
-- so the sync handler stays about state and this stays about noise.
local lastState = nil

CreateThread(function()
    while true do
        Wait(250)

        local data = Airdrop.data
        local state = data and data.state or nil

        if state ~= lastState then
            -- Only the transitions a player would want announced. Moving from
            -- announced to inbound is the plane taking off, which nobody needs
            -- a sound for.
            if state == 'announced' then
                PlayDropSound('announced')
            elseif state == 'landed' then
                PlayDropSound('landed')
            elseif state == 'open' then
                PlayDropSound('opened')
            end

            lastState = state
        end
    end
end)

-- Countdown ticks over the last ten seconds.
--
-- Driven from the same local deadline the HUD uses, and fired once per whole
-- second rather than per frame — the tick is a metronome, and a metronome that
-- fires sixty times a second is a buzz.
CreateThread(function()
    local lastTick = nil

    while true do
        Wait(200)

        local cfg = Config.Sounds
        local data = Airdrop.data

        if cfg and cfg.Enabled and cfg.CountdownTicks
            and data and (data.state == 'announced' or data.state == 'inbound')
            and data.landsAtMs then

            local remaining = math.ceil((data.landsAtMs - GetGameTimer()) / 1000)

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
