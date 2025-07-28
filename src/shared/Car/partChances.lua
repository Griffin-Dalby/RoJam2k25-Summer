--[[

    Random Spawn Part Chances

    Griffin Dalby
    2025.07.27

    This module contains metadata for randomly choosing parts for each
    item in the engine bay on spawn.

--]]

local chances = {
    ['engine'] = {
        {'engine.scrappy', 100}
    },
    ['battery'] = {
        {'battery.scrappy', 100}
    },
    ['filter'] = {
        {'filter.scrappy', 100}
    },
    ['resevoir'] = {
        {'resevoir.scrappy', 100}
    }
}

return function(id: string)
    local chanceTable = chances[id]
    if not chanceTable then return nil end

    local totalWeight = 0
    for _, itm in ipairs(chanceTable) do
        totalWeight = totalWeight + itm[2]
    end

    local random = math.random(1, totalWeight)
    local currentWeight = 0
    for _, itm in ipairs(chanceTable) do
        currentWeight = currentWeight+itm[2]
        if random<currentWeight then
            return itm[1]
        end
    end

    return chanceTable[1][1]
end