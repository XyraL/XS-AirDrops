-- ─────────────────────────────────────────────────────────────
-- Inventory bridge
-- One API over ox_inventory / qb-inventory / qs-inventory /
-- codem-inventory / core_inventory / ps-inventory.
--
-- Deliberately smaller than the one in cipher-drugs. A crate needs to exist as
-- a container, be filled once, and be opened by whoever reaches it — there is
-- no metadata, no quality banding and no per-player item juggling here.
-- ─────────────────────────────────────────────────────────────
Inv = { name = nil }

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
        print('^1[cipher-airdrops]^0 No supported inventory found. Start one of: ' .. table.concat(DETECT_ORDER, ', '))
    end
end

if IS_SERVER then
    -- Crates are stashes. Using the inventory's own container means two players
    -- looting at once is the inventory's problem to solve, and it already has,
    -- rather than something this script invents badly.
    function Inv.RegisterStash(id, label, slots, maxWeight)
        if Inv.name == 'ox_inventory' then
            exports.ox_inventory:RegisterStash(id, label, slots, maxWeight)
        end
        -- qb / qs / ps / codem / core open stashes by id with no registration.
        return true
    end

    -- Puts an item into the crate rather than into a player.
    function Inv.AddToStash(id, item, count)
        if Inv.name == 'ox_inventory' then
            return exports.ox_inventory:AddItem(id, item, count)
        end

        -- Every other backend creates stash contents lazily when first opened,
        -- and none of them expose a reliable "add to a stash that nobody has
        -- opened yet" call. Those crates are filled on open instead — see
        -- server/loot.lua, which keeps the rolled contents until then.
        return false
    end

    -- True when the backend can be filled up front. Decides whether loot is
    -- pushed into the container at crack time or held and handed over on open.
    function Inv.CanPrefillStash()
        return Inv.name == 'ox_inventory'
    end

    -- Has the crate been emptied? Only ox_inventory can answer; the others
    -- create their stash lazily and cannot be read back.
    --
    -- Returns nil for "cannot tell", which is not the same as false.
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

    -- Emptied when a drop ends. Every crate registers its own stash under a
    -- unique id, so without this a server accumulates one orphaned stash per
    -- drop forever — each still holding whatever nobody bothered to loot.
    function Inv.ClearStash(id)
        if Inv.name == 'ox_inventory' then
            return exports.ox_inventory:ClearInventory(id)
        end
        -- Lazily-created stashes on other backends only exist once opened, and
        -- are keyed per drop, so there is nothing registered to clear here.
        return false
    end

    function Inv.AddItem(src, item, count)
        if Inv.name == 'ox_inventory' then
            return exports.ox_inventory:AddItem(src, item, count)
        elseif Inv.name == 'qb-inventory' then
            return exports['qb-inventory']:AddItem(src, item, count, false, nil, 'cipher-airdrops')
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
        -- Other backends refuse the add themselves when full, so assume yes
        -- and let the add fail rather than blocking a legitimate pickup.
        return true
    end
else
    function Inv.OpenStash(id, data)
        data = data or {}
        if Inv.name == 'ox_inventory' then
            exports.ox_inventory:openInventory('stash', id)
        elseif Inv.name == 'qb-inventory' or Inv.name == 'ps-inventory' then
            TriggerServerEvent('cipher-airdrops:server:openStash', id)
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

if Config and Config.Debug then
    print(('^2[cipher-airdrops]^0 inventory bridge loaded (%s) on %s'):format(
        Inv.name or 'none', IS_SERVER and 'server' or 'client'))
end
