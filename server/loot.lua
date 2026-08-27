-- Crate contents.
--
-- Rolled on the server, at the moment a crate is cracked. Never earlier and
-- never on a client: if the contents can be known before the fight, people
-- decide whether the fight is worth having, and the fight is the entire point
-- of the script.
Loot = {}

local function totalWeight(list)
    local sum = 0
    for _, entry in ipairs(list) do sum = sum + (entry.weight or 1) end
    return sum
end

-- Standard weighted pick. Weights are relative, so a server owner can add a
-- tier without rebalancing every other number.
local function pickWeighted(list)
    local sum = totalWeight(list)
    if sum <= 0 then return nil end

    local roll = math.random() * sum
    local running = 0
    for _, entry in ipairs(list) do
        running = running + (entry.weight or 1)
        if roll <= running then return entry end
    end
    return list[#list]
end

-- Tiers are ranked by their order in the config, so "uncommon or better" means
-- "at or past the index uncommon sits at".
local function tierIndex(name)
    for i, tier in ipairs(Config.Loot.Tiers) do
        if tier.name == name then return i end
    end
    return nil
end

local function rollFromTier(tier)
    local entry = tier and tier.items and pickWeighted(tier.items)
    if not entry then return nil end

    local min = entry.min or 1
    local max = entry.max or min
    if max < min then max = min end

    return {
        item = entry.item,
        count = math.random(min, max),
        tier = tier.name,
        isWeapon = entry.isWeapon or false,
    }
end

-- Returns a list of { item, count, tier, isWeapon }.
function Loot.Roll()
    local cfg = Config.Loot
    local out = {}

    local stacks = math.random(cfg.MinStacks or 3, cfg.MaxStacks or 6)

    for _ = 1, stacks do
        local tier = pickWeighted(cfg.Tiers)
        local entry = tier and rollFromTier(tier)
        if entry then out[#out + 1] = entry end
    end

    -- A crate that is entirely bandages after a five-minute fight over it is
    -- the fastest way to teach players to ignore the next one. One roll is
    -- forced up to the guaranteed tier when nothing already qualified.
    local floorName = cfg.GuaranteeAtLeast
    local floorIdx = floorName and tierIndex(floorName)

    if floorIdx then
        local satisfied = false
        for _, entry in ipairs(out) do
            local idx = tierIndex(entry.tier)
            if idx and idx >= floorIdx then
                satisfied = true
                break
            end
        end

        if not satisfied then
            -- Pick among the qualifying tiers by their own weights, so the
            -- guarantee does not always hand out the exact floor tier.
            local eligible = {}
            for i = floorIdx, #cfg.Tiers do eligible[#eligible + 1] = cfg.Tiers[i] end

            local entry = rollFromTier(pickWeighted(eligible))
            if entry then
                if #out > 0 then out[#out] = entry else out[1] = entry end
            end
        end
    end

    return out
end

-- Called once at start so a typo in a tier is reported at boot rather than
-- discovered by a player standing over an empty crate.
function Loot.Validate()
    local problems = {}

    if type(Config.Loot.Tiers) ~= 'table' or #Config.Loot.Tiers == 0 then
        problems[#problems + 1] = 'Config.Loot.Tiers is empty'
    end

    for i, tier in ipairs(Config.Loot.Tiers or {}) do
        if not tier.name then
            problems[#problems + 1] = ('tier #%d has no name'):format(i)
        end
        if type(tier.items) ~= 'table' or #tier.items == 0 then
            problems[#problems + 1] = ('tier "%s" has no items'):format(tier.name or i)
        end
        for _, entry in ipairs(tier.items or {}) do
            if not entry.item then
                problems[#problems + 1] = ('tier "%s" has an item with no name'):format(tier.name or i)
            end
        end
    end

    local floorName = Config.Loot.GuaranteeAtLeast
    if floorName and not tierIndex(floorName) then
        problems[#problems + 1] = ('GuaranteeAtLeast is "%s", which is not a tier'):format(floorName)
    end

    if #problems > 0 then
        print('^1[cipher-airdrops]^0 loot config problems:')
        for _, p in ipairs(problems) do print('  - ' .. p) end
        return false
    end
    return true
end
