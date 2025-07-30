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
local gameCache = caching.findCache('game')

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

        local currentScraps = gameCache:getValue('scraps')
        local scrapPriceRng = thisItem.__itemAsset.stats.scrapPrice
        gameCache:setValue('scraps', currentScraps+math.random(scrapPriceRng[1], scrapPriceRng[2])) --> TODO: Scale w/ players in game
        
        worldChannel.scrapMachine:with()
            :broadcastGlobally()
            :headers('burn')
            :data()
            :fire()
        
        gameChannel.scraps:with()
            :broadcastGlobally()
            :headers('set')
            :data(gameCache:getValue('scraps'))
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