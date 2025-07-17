--[[

    game.physObject Replicator

    Griffin Dalby
    2025.07.16

    This script will handle the replication of physical objects in the game.
    It will handle creation, deletion, grabbing, and interaction with
    physical objects.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local caching = sawdust.core.cache

local physItem = require(replicatedStorage.Shared.PhysItem)

--]] Settings
--]] Constants
local physItems = caching.findCache('physItems')

--]] Variables
--]] Functions
--]] Listener
local headerHandlers = {
    ['create'] = function(itemUuid: string) --> Create a item on client
        if physItems:hasEntry(itemUuid) then
            warn(`[{script.Name}] Item ({itemUuid:sub(1,8)}...) already registered!`)
            return end
        
        local newPhysItem = physItem.new(itemUuid)
        physItems:setValue(itemUuid, newPhysItem)
    end,

    ['put'] = function(itemUuid: string, position: {[number]: number}, rotation: {[number]: number})
        if not physItems:hasEntry(itemUuid) then
            warn(`[{script.Name}:put()] Item ({itemUuid:sub(1,8)}...) hasn't been registered yet!`)
            return end

        local foundPhysItem = physItems:getValue(itemUuid) :: physItem.PhysicalItem
        foundPhysItem:putItem(position, rotation)
    end
}

return function(req)
    headerHandlers[req.headers](unpack(req.data))
end