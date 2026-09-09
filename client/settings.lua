-- Applies settings changed in the admin panel.
--
-- config.lua is a shared script, so the client boots with whatever the file
-- says. Anything an admin changes afterwards lives only in the database, and
-- without this the client would keep using the file's values until the next
-- resource restart — a crack time changed mid-session would apply on the server
-- and not in the progress bar the player is watching.

RegisterNetEvent('XS-AirDrops:client:settings', function(values)
    if type(values) ~= 'table' then return end

    for key, value in pairs(values) do
        local section, name = key:match('^([^.]+)%.(.+)$')
        if section and name and Config[section] ~= nil then
            Config[section][name] = value
        end
    end
end)

-- Asked for on join, so a player connecting mid-session gets the live values
-- rather than the file's.
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    TriggerServerEvent('XS-AirDrops:server:requestSettings')
end)
