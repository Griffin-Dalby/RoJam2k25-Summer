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

local physItem = require(replicatedStorage.Shared.PhysItem)

--]] Settings
--]] Constants
--> Networking channels
local gameChannel = networking.getChannel('game')

--]] Variables
--]] Functions
--]] Script
local physItemCache = caching.findCache('physItems')
local physItemDrags = caching.findCache('physItems.dragging')

--> Handle PhysItem Events
gameChannel.physItem:handle(function(req, res)
    local caller: Player = players:GetPlayerByUserId(req.caller)
    local character = caller.Character
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local rootPart = humanoid.RootPart

    local headerControllers = {
        ['grab'] = function()
            --> Sanity checks
            local itemUuid = unpack(req.data)
            local foundItem = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
            if not foundItem then
                warn(`[{script.Name}] Player ({caller.Name}.{caller.UserId}) attempted to pickup invalid item (UUID: {itemUuid:sub(1,8)}...)`)
                res.setHeaders('rejected')
                res.send(); return end

            local dist = (rootPart.Position-Vector3.new(unpack(foundItem:getTransform().position))).Magnitude
            if dist<15 then
                warn(`[{script.Name}] Player ({caller.Name}.{caller.UserId}) attempted to pickup item outside of range! (UUID: {itemUuid:sub(1,8)}...)`)
                res.setHeaders('rejected')
                res.send(); return end

            
        end,

        ['dragUpdate'] = function()
            
        end
    }

    assert(headerControllers[req.headers], `No handler for header "{req.headers or '<none provided>'}".`)
    headerControllers[req.headers]()
end)

--> Register Environment
for _, prop: Instance in pairs(workspace.Terrain.InteractableProps:GetChildren()) do
    local itemId = prop:GetAttribute('itemId')
    local propItem = physItem.new(itemId)

    local tposition, trotation = {}, {}

    local rootPosition = prop:IsA('Model') and prop:GetPivot() or prop.CFrame
    local position,  rotation  = prop

end

--> Replicate Environment
local function replicateEnv(player: Player)
    for _, physItem: physItem.PhysicalItem in pairs(physItemCache:getContents()) do
        gameChannel.physItem:with()
            :broadcastTo{player}
            :headers('create')
            :data{physItem.__itemId, physItem.__itemId}
            :fire()
        gameChannel.physItem:with()
            :broadcastGlobally()
            :headers('put')
            :data{physItem.__itemUuid, }
            :fire()
    end
end

players.PlayerAdded:Connect(replicateEnv)
for _, player: Player in pairs(players:GetPlayers()) do
    replicateEnv(player) end