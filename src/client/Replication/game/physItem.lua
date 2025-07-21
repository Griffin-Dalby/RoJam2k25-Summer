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
local logging = false

--]] Constants
local physItemCache = caching.findCache('physItems')

--]] Variables
--]] Functions
--]] Listener
--> Cleanup Studio Props
local interactableProps = workspace.Terrain:FindFirstChild('InteractableProps')
if interactableProps then
    interactableProps:Destroy() end

--> Header Handlers
local headerHandlers = {
	['create'] = function(itemId: string, itemUuid: string) --> Create a item on client
		if logging then
			print(`[{script.Name}] Created Object {itemId}[{itemUuid:sub(1,8+1+4)}...]`) end
		
        if physItemCache:hasEntry(itemUuid) then
            warn(`[{script.Name}] Item ({itemUuid:sub(1,8)}...) already registered!`)
            return end
        physItemCache:setValue(itemUuid, 'placeholder')
        
        local newPhysItem = physItem.new(itemId, itemUuid)
        physItemCache:setValue(itemUuid, newPhysItem)
    end,

    ['destroy'] = function(itemUuid: string)
        if logging then
            print(`[{script.Name}] Destroying object ({itemUuid:sub(1,8+1+4)}).`) end

        if not physItemCache:hasEntry(itemUuid) then
            warn(`[{script.Name}] Item ({itemUuid:sub(1,8)}...) is not registered!`)
            return end
            
        local physItem = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
        physItem:destroy()

        physItemCache:setValue(itemUuid, nil)
    end,

	['put'] = function(itemUuid: string, position: {[number]: number}, rotation: {[number]: number})
        if logging then
			print(`[{script.Name}] Put Object "{itemUuid:sub(1,8+1+8)}" @ transform:\nPosition: {position[1]}, {position[2]}, {position[3]}\nRotation: {rotation[1]}°, {rotation[2]}°, {rotation[3]}°`) end
		
        if not physItemCache:hasEntry(itemUuid) then
            warn(`[{script.Name}:put()] Item ({itemUuid:sub(1,8)}...) hasn't been registered yet!`)
            return end

        local foundPhysItem = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
        foundPhysItem:putItem(position, rotation)
    end
}

return function(req)
    headerHandlers[req.headers](unpack(req.data))
end