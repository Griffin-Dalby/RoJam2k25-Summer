--[[

    game.physItemReplication Listener

    Griffin Dalby
    2025.07.19

    This module will provide a listener for PhysItem replications.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local physItem = require(replicatedStorage.Shared.PhysItem)

local sawdust = require(replicatedStorage.Sawdust)
local caching = sawdust.core.cache

--]] Settings
--]] Constants
--> Caches
local physItemCache = caching.findCache('physItems')

--]] Variables
--]] Functions
--]] Listener

local headerHandlers = {
    ['grab'] = function(itemUuid: string, caller: Player)
        local foundItem = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
        assert(foundItem, `Failed to find item (UUID8:{itemUuid:sub(1,8)}) in physItemCache!`)

        foundItem:grab(caller)
    end,

    ['drag'] = function(itemUuid: string, position: Vector3, velocity: {})
        local foundItem = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
        assert(foundItem, `Failed to find item (UUID8:{itemUuid:sub(1,8)}) in physItemCache!`)

        --> Update
        foundItem:setTransform{{position.X, position.Y, position.Z}} --> Rotation is auto-handled
        foundItem:setVelocity(velocity)
    end,

    ['drop'] = function(itemUuid: string, position: Vector3, velocity: {
            linear: Vector3, angular: Vector3})

        local foundItem = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
        assert(foundItem, `Failed to find item (UUID8:{itemUuid:sub(1,8)}) in physItemCache!`)

        foundItem:drop(position, velocity)
    end,

    ['wetness'] = function(itemUuid: string, wetness: number)
        local foundItem = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
        assert(foundItem, `Failed to find item (UUID8:{itemUuid:sub(1,8)}) in physItemCache!`)

        foundItem:setWetness(wetness)
    end
}

return function (req)
    headerHandlers[req.headers](unpack(req.data))
end