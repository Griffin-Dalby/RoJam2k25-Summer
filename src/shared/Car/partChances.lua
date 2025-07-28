--[[

    Random Spawn Part Chances

    Griffin Dalby
    2025.07.27

    This module contains metadata for randomly choosing parts for each
    item in the engine bay on spawn.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local cdn = sawdust.core.cdn

--]] Settings
local issueConfig = {
    engine = {
        fire = .15,
        overheat = .4,
    },
    filter = {
        fire = .05,
        overheat = .2,
    },
    battery = {
        fire = .25,
        overheat = .10,
    },
    reservoir = {
        fire = .02,
        overheat = .3,
    }
}

--]] Constants
--> CDN Providers
local partCDN = cdn.getProvider('part')

--]] Chance

local chances = {
    ['engine'] = {
        {'engine.scrappy', 50},
        {'engine.v4', 35},
        {'engine.v6', 10},
        {'engine.v8', 5},
    },
    ['battery'] = {
        {'battery.scrappy', 100}
    },
    ['filter'] = {
        {'filter.scrappy', 100}
    },
    ['reservoir'] = {
        {'reservoir.scrappy', 100}
    }
}

return function(id: string)
    --> Choose part
    local chanceTable = chances[id]
    if not chanceTable then return nil end

    local totalWeight = 0
    for _, itm in ipairs(chanceTable) do
        totalWeight = totalWeight + itm[2]
    end

    local random = math.random(1, totalWeight)
    local currentWeight = 0
    local chosenPart = chanceTable[1][1]

    for _, itm in ipairs(chanceTable) do
        currentWeight = currentWeight+itm[2]
        if random>currentWeight then
            chosenPart = itm[1]
            break
        end
    end

    --> Choose flags
    local issues = {
        fire = false,
        overheat = false
    }

    local partAsset = partCDN:getAsset(chosenPart)
    local partQuality = partAsset.behavior.quality

    local thisConfig = issueConfig[id]
    local fireChance = thisConfig.fire*(100-partQuality)/100
    local overheatChance = thisConfig.overheat*(100-partQuality)/100

    issues.fire = (math.random() < fireChance)
    issues.overheat = (math.random() < overheatChance)

    return {chosenPart, issues}
end