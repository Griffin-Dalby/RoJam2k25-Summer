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

gameChannel.physItem:handle(function(req, res)
    local headerControllers = {
        ['verify'] = function()
            local itemId = unpack(req.data)
            local cacheItem = physItemCache:getValue(itemId) :: physItem.PhysicalItem

            if not cacheItem then
                local caller = players:GetPlayerByUserId(req.caller)
                warn(`[{script.Name}] Player ({caller.Name}.{caller.UserId}) attempted to verify an invalid item! (uuid: {itemId:sub(1, 8)}...)`)
                return false end

            return cacheItem.__itemId
        end
    }

    assert(headerControllers[req.headers], `No handler for header "{req.headers or '<none provided>'}".`)
    headerControllers[req.headers]()
end)

players.PlayerAdded:Connect(function(player)
    local item = physItem.new('cube')
    task.wait(2)
    item:putItem({1, 3, -3}, {0, 0, 0})
end)