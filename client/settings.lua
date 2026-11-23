RegisterNetEvent('XS-AirDrops:client:settings', function(values)
    if type(values) ~= 'table' then return end
    Settings.Apply(values)
    if Crate and Crate.Refresh then Crate.Refresh() end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    TriggerServerEvent('XS-AirDrops:server:requestSettings')
end)
