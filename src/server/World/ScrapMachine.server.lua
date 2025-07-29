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

--> Caching groups
local physItems = caching.findCache('physItems')

--]] Variables
--]] Functions
--]] Script
local headerHandlers = {
    ['use'] = function(itemUuid: string)
        local thisItem = physItems:getValue(itemUuid) :: physItem.PhysicalItem
        thisItem:destroy()

        return true
    end
}

worldChannel.scrapMachine:handle(function(req, res)
    local caller = players:GetPlayerByUserId(req.caller)
   
    if not headerHandlers[req.headers] then
        warn(`[{script.Name}] Player ({caller.Name}.{caller.UserId})`)
        return false end

    res.setHeaders(req.headers)
    res.setData(headerHandlers[req.headers](unpack(req.data)))
    res.send()
end)