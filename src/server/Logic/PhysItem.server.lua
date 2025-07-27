--[[

    PhysItem Server Controller

    Griffin Dalby
    2025.07.16

    This script will allow players to interact with physical items in the world.
    It will handle the creation, deletion, and interaction of physical items.

--]]

--]] Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local networking = sawdust.core.networking
local caching = sawdust.core.cache
local cdn = sawdust.core.cdn

local physItem = require(replicatedStorage.Shared.PhysItem)

--]] Settings
--]] Constants
--> Networking channels
local gameChannel = networking.getChannel('game')

--> CDN Providers
local itemProvider = cdn.getProvider('item')

--]] Variables
--]] Functions
--]] Script
local playerCache = caching.findCache('players')

local physItemCache = caching.findCache('physItems')
local physItemDrags = caching.findCache('physItems.dragging')
local physItemGoals = caching.findCache('physItems.drag_goals')

--> Handle PhysItem Events
local physItemRemote, physItemReplication = gameChannel.physItem, gameChannel.physItemReplication

physItemRemote:handle(function(req, res)
    local caller: Player = players:GetPlayerByUserId(req.caller)
    local character = caller.Character
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local rootPart = humanoid.RootPart

    local function runSanityChecks(foundItem, itemUuid, inversePickup)
        local playerSig = `Player ({caller.Name}.{caller.UserId}) attempted to`

        if not inversePickup and physItemDrags:getValue(caller) then
            warn(`[{script.Name}] {playerSig} grab an item while they're already grabbing one!`)
            res.setData(false)
            res.send(); return end
        if inversePickup and not physItemDrags:getValue(caller) then
            warn(`[{script.Name}] {playerSig} pick up and item while they're grabbing none!`)
            res.setData(false)
            res.send(); return end

        if not foundItem then
            warn(`[{script.Name}] {playerSig} interact w/ invalid item (UUID: {itemUuid:sub(1,8)}...)`)
            res.setData(false)
            res.send(); return end

        local dist = (rootPart.Position-Vector3.new(unpack(foundItem:getTransform().position))).Magnitude
        if not inversePickup and dist>50 then
            warn(`[{script.Name}] {playerSig} interact w/ item outside of range! (UUID: {itemUuid:sub(1,8)}...)`)
            res.setData(false)
            res.send(); return end
    end

    local headerControllers = {
        ['grab'] = function()
            res.setHeaders('grab')

            local itemUuid = unpack(req.data)
            local foundItem = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
            runSanityChecks(foundItem, itemUuid)

            --> Verify
            local canGrab = foundItem:grab(caller)
            res.setData(canGrab)

            --> Replicate
            physItemReplication:with()
                :setFilterType('exclude')
                :broadcastTo{caller}
                :headers('grab')
                :data{itemUuid, caller}
                :fire()
            res.send()

            return true
        end,

        ['pickUp'] = function()
            res.setHeaders('pickUp')

            local itemUuid = unpack(req.data)
            local foundItem = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
            runSanityChecks(foundItem, itemUuid, true)

            --> Player Data
            local playerData = playerCache:findTable(caller)
            local inventory  = playerData:getValue('inventory')
            
            if #inventory >= 2 then --> TODO: Have dynamic when upgrades implemented
                res.setData(false)
                res.send(); return end

            --> Verify
            local canPickUp = foundItem:pickUp()
            if not canPickUp then
                res.setData(false)
                res.send(); return end

            --> Remove from phys world
            local itemId, itemUuid = foundItem.__itemId, foundItem.__itemUuid
            foundItem:destroy{caller}
                
            --> Add to inventory & finish up
            table.insert(inventory, {itemId, itemUuid})

            res.setData(true)
            res.send()
            return true
        end,

        ['dragUpdate'] = function()
            local newPosition: Vector3, velocity: {
                linear: Vector3,
                angular: Vector3
            } = unpack(req.data)
            assert(newPosition, `Missing position value!`)
            assert(velocity, `Missing velocity value!`)

            res.setHeaders('dragUpdate')
            
            --> Sanity checks
            local grabbedItemUUID = physItemDrags:getValue(caller)
            local grabbedItem = physItemCache:getValue(grabbedItemUUID) :: physItem.PhysicalItem
            if not grabbedItem then return end

            local lastPosition = grabbedItem:getTransform().position
            local constructed = CFrame.lookAt(newPosition, character.Head.Position)
            local rotX, rotY, rotZ = constructed:ToEulerAnglesXYZ()
                  rotX, rotY, rotZ = math.deg(rotX), math.deg(rotY), math.deg(rotZ)

            local dist = (Vector3.new(unpack(lastPosition))-newPosition).Magnitude
            if dist>15 then
                warn(`[{script.Name}] Player ({caller.Name}.{caller.UserId}) attempted to drag item too far during tick!`)
                return end

            physItemGoals:setValue(caller, newPosition)
            grabbedItem:setTransform{
                {newPosition.X, newPosition.Y, newPosition.Z},
                {rotX, rotY, rotZ} }

            --> Replicate
            physItemReplication:with()
                :setFilterType('exclude')
                :broadcastTo{caller}
                :headers('drag')
                :data{grabbedItemUUID, newPosition, velocity}
                :fire()

            return true
        end,

        ['drop'] = function()
            res.setHeaders('drop')

            --> Sanity checks
            local position: Vector3, velocity: {
                linear: Vector3,
                angular: Vector3,
            } = unpack(req.data)

            local grabbedItemUUID = physItemDrags:getValue(caller)
            local grabbedItem = physItemCache:getValue(grabbedItemUUID) :: physItem.PhysicalItem
            if not grabbedItem then
                warn(`[{script.Name}] Player ({caller.Name}.{caller.UserId}) attempted to drop an item while they aren't grabbing anything.`)
                res.setData('sync'); res.send()
				return end
			
			local canDrop = grabbedItem:drop()
            if not canDrop then
                res.setData(false)
                res.send(); return end

            physItemGoals:setValue(caller, nil)
            physItemDrags:setValue(caller, nil)

            res.setData(true)
            res.send()

            --> Replicate
            physItemReplication:with()
                :setFilterType('exclude')
                :broadcastTo{caller}
                :headers('drop')
                :data{grabbedItemUUID, position, velocity}
                :fire()

            return true
        end
    }

    assert(headerControllers[req.headers], `No handler for header "{req.headers or '<none provided>'}".`)
    return headerControllers[req.headers]()
end)

--> Register Environment
for _, prop: Instance in pairs(workspace.Terrain.InteractableProps:GetChildren()) do
    local itemId = prop:GetAttribute('itemId')
    local propItem = physItem.new(itemId, false)

    local tposition, trotation = {}, {}

    local rootPosition = prop:IsA('Model') and prop:GetPivot() or prop.CFrame
    local position = rootPosition.Position
    local rotX, rotY, rotZ = rootPosition:ToEulerAnglesXYZ()
          rotX, rotY, rotZ = math.deg(rotX), math.deg(rotY), math.deg(rotZ)
    
    tposition = {position.X, position.Y, position.Z}
    trotation = {rotX, rotY, rotZ}

    propItem:setTransform{tposition, trotation}
end

--> Replicate Environment
local function replicateEnv(player: Player)
    for _, physItem: physItem.PhysicalItem in pairs(physItemCache:getContents()) do
        gameChannel.physItem:with()
            :broadcastTo{player}
            :headers('create')
            :data{physItem.__itemId, physItem.__itemUuid}
            :fire()
        gameChannel.physItem:with()
            :broadcastGlobally()
            :headers('put')
            :data{physItem.__itemUuid, physItem:getTransform().position, physItem:getTransform().rotation}
            :fire()
    end
end

for _, player: Player in pairs(players:GetPlayers()) do
    replicateEnv(player) end
players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Once(function()
        replicateEnv(player)
    end)
end)