Inv = { name = nil }

if not Config then return end

local IS_SERVER = IsDuplicityVersion()

local DETECT_ORDER = {
    'ox_inventory', 'qb-inventory', 'qs-inventory',
    'codem-inventory', 'core_inventory', 'ps-inventory',
}

do
    local forced = Config.Bridges and Config.Bridges.inventory or 'auto'
    if forced ~= 'auto' then
        Inv.name = forced
    else
        for _, r in ipairs(DETECT_ORDER) do
            if GetResourceState(r) == 'started' then
                Inv.name = r
                break
            end
        end
    end

    if not Inv.name then
        print('^1[XS-AirDrops]^0 No supported inventory found. Start one of: ' .. table.concat(DETECT_ORDER, ', '))
    end
end

if IS_SERVER then
    function Inv.RegisterStash(id, label, slots, maxWeight, at)
        if Inv.name == 'ox_inventory' then
            local coords = at and vector3((tonumber(at.x) or 0) + 0.0, (tonumber(at.y) or 0) + 0.0, (tonumber(at.z) or 0) + 0.0) or nil
            exports.ox_inventory:RegisterStash(id, label, slots, maxWeight, nil, nil, coords)
        end
        return true
    end

    function Inv.AddToStash(id, item, count)
        if Inv.name == 'ox_inventory' then
            return exports.ox_inventory:AddItem(id, item, count)
        end
        return false
    end

    function Inv.CanPrefillStash()
        return Inv.name == 'ox_inventory'
    end

    function Inv.StashIsEmpty(id)
        if Inv.name ~= 'ox_inventory' then return nil end

        local ok, items = pcall(function()
            return exports.ox_inventory:GetInventoryItems(id)
        end)
        if not ok or type(items) ~= 'table' then return nil end

        for _, item in pairs(items) do
            if item and (item.count or 0) > 0 then return false end
        end
        return true
    end

    function Inv.ClearStash(id)
        if Inv.name == 'ox_inventory' then
            return exports.ox_inventory:ClearInventory(id)
        end
        return false
    end

    function Inv.AddItem(src, item, count)
        if Inv.name == 'ox_inventory' then
            return exports.ox_inventory:AddItem(src, item, count)
        elseif Inv.name == 'qb-inventory' then
            return exports['qb-inventory']:AddItem(src, item, count, false, nil, 'XS-AirDrops')
        elseif Inv.name == 'qs-inventory' then
            return exports['qs-inventory']:AddItem(src, item, count, false)
        elseif Inv.name == 'codem-inventory' then
            return exports['codem-inventory']:AddItem(src, item, count)
        elseif Inv.name == 'core_inventory' then
            return exports.core_inventory:addItem(src, item, count)
        elseif Inv.name == 'ps-inventory' then
            return exports['ps-inventory']:AddItem(src, item, count, false)
        end
        return false
    end

    function Inv.CanCarry(src, item, count)
        if Inv.name == 'ox_inventory' then
            return exports.ox_inventory:CanCarryItem(src, item, count)
        end
        return true
    end

    function Inv.Items()
        local out = {}
        local ok, list = pcall(function()
            if GetResourceState('ox_inventory') == 'started' then return exports.ox_inventory:Items() end
            if Framework.core then return Framework.core.Shared.Items end
            return nil
        end)
        if not ok or type(list) ~= 'table' then return out end
        for key, data in pairs(list) do
            if type(data) == 'table' then
                local name = data.name or key
                out[#out + 1] = { name = tostring(name), label = tostring(data.label or name) }
            end
        end
        table.sort(out, function(a, b) return a.name < b.name end)
        return out
    end
else
    function Inv.OpenStash(id, data)
        data = data or {}
        if Inv.name == 'ox_inventory' then
            exports.ox_inventory:openInventory('stash', id)
        elseif Inv.name == 'qb-inventory' or Inv.name == 'ps-inventory' then
            TriggerServerEvent('XS-AirDrops:server:openStash', id)
        elseif Inv.name == 'qs-inventory' then
            TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, {
                maxweight = data.maxWeight or 80000, slots = data.slots or 12,
            })
        elseif Inv.name == 'codem-inventory' then
            TriggerServerEvent('codem-inventory:server:openstash', id, data.slots or 12, data.maxWeight or 80000, id)
        elseif Inv.name == 'core_inventory' then
            TriggerServerEvent('core_inventory:server:openInventory', id, 'stash')
        end
    end
end

if Config.Debug then
    print(('^2[XS-AirDrops]^0 inventory bridge loaded (%s) on %s'):format(
        Inv.name or 'none', IS_SERVER and 'server' or 'client'))
end
