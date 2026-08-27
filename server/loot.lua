-- Crate contents.
--
-- Rolled on the server, at the moment a crate is cracked. Never earlier and
-- never on a client: if the contents can be known before the fight, people
-- decide whether the fight is worth having, and the fight is the entire point
-- of the script.
--
-- Tiers and items come from the database (see server/data.lua), which the admin
-- panel edits. config.lua only supplies the defaults they were seeded from.
Loot = {}

local function pickWeighted(list, weightOf)
    local sum = 0
    for _, entry in ipairs(list) do sum = sum + weightOf(entry) end
    if sum <= 0 then return nil end

    local roll, running = math.random() * sum, 0
    for _, entry in ipairs(list) do
        running = running + weightOf(entry)
        if roll <= running then return entry end
    end
    return list[#list]
end

local tierWeight = function(t) return t.weight or 1 end
local itemWeight = function(i) return i.weight or 1 end

local function rollFromTier(tier)
    local entry = tier and tier.items and pickWeighted(tier.items, itemWeight)
    if not entry then return nil end

    local min = entry.min_count or 1
    local max = entry.max_count or min
    if max < min then max = min end

    return {
        item = entry.item,
        count = math.random(min, max),
        tier = tier.name,
        rank = tier.rank or 0,
    }
end

-- Returns a list of { item, count, tier, rank }.
function Loot.Roll()
    local cfg = Config.Loot
    local tiers = Data.Tiers()
    local out = {}

    if #tiers == 0 then
        print('^1[cipher-airdrops]^0 no enabled loot tiers — the crate will be empty')
        return out
    end

    local stacks = math.random(cfg.MinStacks or 3, cfg.MaxStacks or 6)
    for _ = 1, stacks do
        local entry = rollFromTier(pickWeighted(tiers, tierWeight))
        if entry then out[#out + 1] = entry end
    end

    -- A crate that is entirely bandages after a five-minute fight over it is
    -- the fastest way to teach players to ignore the next one. One roll is
    -- forced up to the guaranteed tier when nothing already qualified.
    local floorName = cfg.GuaranteeAtLeast
    if not floorName then return out end

    local floorRank
    for _, tier in ipairs(tiers) do
        if tier.name == floorName then floorRank = tier.rank break end
    end
    if not floorRank then return out end

    for _, entry in ipairs(out) do
        if (entry.rank or 0) >= floorRank then return out end
    end

    -- Nothing qualified. Pick among the tiers at or above the floor, by their
    -- own weights, so the guarantee does not always hand out the exact floor.
    local eligible = {}
    for _, tier in ipairs(tiers) do
        if (tier.rank or 0) >= floorRank then eligible[#eligible + 1] = tier end
    end

    local forced = rollFromTier(pickWeighted(eligible, tierWeight))
    if forced then
        if #out > 0 then out[#out] = forced else out[1] = forced end
    end

    return out
end

-- Reported at boot so a broken loot table is found before a player is standing
-- over an empty crate wondering whether they were robbed.
function Loot.Validate()
    local tiers = Data.Tiers()
    local problems = {}

    if #tiers == 0 then
        problems[#problems + 1] = 'no enabled tiers with any enabled items'
    end

    if Config.Loot.GuaranteeAtLeast then
        local found = false
        for _, tier in ipairs(tiers) do
            if tier.name == Config.Loot.GuaranteeAtLeast then found = true break end
        end
        if not found then
            problems[#problems + 1] = ('GuaranteeAtLeast is "%s", which is not an enabled tier')
                :format(Config.Loot.GuaranteeAtLeast)
        end
    end

    if #problems > 0 then
        print('^1[cipher-airdrops]^0 loot problems:')
        for _, p in ipairs(problems) do print('  - ' .. p) end
        return false
    end
    return true
end
