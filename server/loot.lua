Loot = {}

local function pickWeighted(list)
    local sum = 0
    for _, entry in ipairs(list) do sum = sum + (entry.weight or 1) end
    if sum <= 0 then return nil end

    local roll, running = math.random() * sum, 0
    for _, entry in ipairs(list) do
        running = running + (entry.weight or 1)
        if roll <= running then return entry end
    end
    return list[#list]
end

function Loot.Live(data)
    local out = {}
    for rank, tier in ipairs((data or {}).tiers or {}) do
        if tier.enabled ~= false then
            local items = {}
            for _, item in ipairs(tier.items or {}) do
                if item.enabled ~= false and item.item and item.item ~= '' then items[#items + 1] = item end
            end
            if #items > 0 then
                out[#out + 1] = { name = tier.name, weight = tier.weight, rank = rank, items = items }
            end
        end
    end
    return out
end

local function rollFromTier(tier)
    local entry = tier and pickWeighted(tier.items)
    if not entry then return nil end
    local min = entry.min or 1
    local max = entry.max or min
    if max < min then max = min end
    return { item = entry.item, count = math.random(min, max), tier = tier.name, rank = tier.rank }
end

function Loot.Roll(data)
    data = data or {}
    local tiers = Loot.Live(data)
    local out = {}
    if #tiers == 0 then
        print(('^1[XS-AirDrops]^0 loot table "%s" has nothing enabled, so the crate is empty'):format(tostring(data.label)))
        return out
    end

    local minStacks = data.minStacks or 4
    local maxStacks = math.max(minStacks, data.maxStacks or minStacks)
    for _ = 1, math.random(minStacks, maxStacks) do
        local entry = rollFromTier(pickWeighted(tiers))
        if entry then out[#out + 1] = entry end
    end

    local floorName = data.guarantee
    if not floorName or floorName == '' then return out end

    local floorRank
    for _, tier in ipairs(tiers) do
        if tier.name == floorName then floorRank = tier.rank break end
    end
    if not floorRank then return out end

    for _, entry in ipairs(out) do
        if entry.rank >= floorRank then return out end
    end

    local eligible = {}
    for _, tier in ipairs(tiers) do
        if tier.rank >= floorRank then eligible[#eligible + 1] = tier end
    end

    local forced = rollFromTier(pickWeighted(eligible))
    if forced then out[math.max(1, #out)] = forced end
    return out
end

function Loot.Problems(data, known)
    local problems = {}
    local tiers = Loot.Live(data)
    if #tiers == 0 then problems[#problems + 1] = { level = 'bad', text = 'Nothing in it is switched on' } end
    if data.guarantee and data.guarantee ~= '' then
        local found = false
        for _, t in ipairs(tiers) do if t.name == data.guarantee then found = true end end
        if not found then problems[#problems + 1] = { level = 'warn', text = ('The guarantee tier "%s" is off or empty'):format(data.guarantee) } end
    end
    if known then
        local missing = {}
        for _, t in ipairs(data.tiers or {}) do
            for _, it in ipairs(t.items or {}) do
                if it.item and not known[it.item] and not known[it.item:lower()] then missing[#missing + 1] = it.item end
            end
        end
        if #missing > 0 then
            problems[#problems + 1] = { level = 'warn', text = ('%d item%s not on this server: %s'):format(#missing, #missing == 1 and '' or 's', table.concat(missing, ', ', 1, math.min(#missing, 4))) }
        end
    end
    return problems
end
