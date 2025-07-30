--[[

    Scrap Machine Server Logic

    Griffin Dalby
    2025.07.29

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')

--]] Modules
local physItem = require(replicatedStorage.Shared.PhysItem)
local sawdust = require(replicatedStorage.Sawdust)

local networking = sawdust.core.networking
local caching = sawdust.core.cache

--]] Settings
--]] Constants
--> Networking channels
local worldChannel = networking.getChannel('world')
local gameChannel = networking.getChannel('game')

--> Caching groups
local physItems = caching.findCache('physItems')
local playerCache = caching.findCache('players')

--]] Variables
--]] Functions
--]] Script
local headerHandlers = {
    ['use'] = function(caller: Player, itemUuid: string)
        local thisItem = physItems:getValue(itemUuid) :: physItem.PhysicalItem
        if not thisItem then
            warn(`[{script.Name}] Player ({caller.Name}.{caller.UserId}) attempted to scrap unregistered item!`)
            return false end
        if thisItem.__itemAsset.stats.canScrap==false then
            return true end --> Simply dont scrap

        thisItem:destroy()

        local playerData = playerCache:findTable(caller) --> TODO: Add scraps
        local currentScraps = playerData:getValue('scraps')

        local scrapPriceRng = thisItem.__itemAsset.stats.scrapPrice
        playerData:setValue('scraps', currentScraps+math.random(scrapPriceRng[1], scrapPriceRng[2]))

        gameChannel.scraps:with()
            :broadcastTo(caller)
            :headers('set')
            :data(playerData:getValue('scraps'))
            :fire()

        return true
    end
}

worldChannel.scrapMachine:handle(function(req, res)
    local caller = players:GetPlayerByUserId(req.caller)
   
    if not headerHandlers[req.headers] then
        warn(`[{script.Name}] Player ({caller.Name}.{caller.UserId})`)
        return false end

    res.setHeaders(req.headers)
    res.setData(headerHandlers[req.headers](caller, unpack(req.data)))
    res.send()
end)