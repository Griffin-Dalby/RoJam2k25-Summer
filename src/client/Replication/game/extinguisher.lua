--[[

    game.extinguisher listener

    Griffin Dalby
    2025.07.29

    This module will provide a listener for the extinguisher remote.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')

--]] Modules
local physItem = require(replicatedStorage.Shared.PhysItem)
local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache

--]] Settings
--]] Constants
--> Caching groups
local physItems = caching.findCache('physItems')

--]] Variables
--]] Functions
--]] Listener
local extinguishingPlayers = {}

local headerHandlers = {
    ['start'] = function(caller: number, extinguisherUuid: string)
        caller = players:GetPlayerByUserId(caller)

        local thisItem = physItems:getValue(extinguisherUuid) :: physItem.PhysicalItem
        extinguishingPlayers[caller] = thisItem

        thisItem.__itemModel.Tube.Attachment.Smoke.Enabled = true
        thisItem.__itemModel.Cylinder.Tube.C1 = CFrame.new(0.4, 0.8, -0) * CFrame.Angles(0, 0, math.rad(90))
    end,

    ['extinguish'] = function(caller: number, extinguishedUuid: string, fire: number)
        caller = players:GetPlayerByUserId(caller)

        if not extinguishingPlayers[caller] then return end
        local thisItem = physItems:getValue(extinguishedUuid) :: physItem.PhysicalItem
        
        thisItem.fire = fire
        if fire==0 then
            --> Remove fire FX
            local priPart = thisItem.__itemModel.PrimaryPart
            local fx = priPart:FindFirstChild('issue.fire')
            if fx then
                for _, particle: ParticleEmitter in pairs(fx:GetChildren()) do
                    if not particle:IsA('ParticleEmitter') then continue end
                    particle.Enabled = false
                end
                task.delay(3, function()
                    fx:Destroy()
                end)
            end
        end
    end,

    ['stop'] = function(caller: number)
        caller = players:GetPlayerByUserId(caller)

        if extinguishingPlayers[caller] then
            local item = extinguishingPlayers[caller] :: physItem.PhysicalItem
            item.__itemModel.Tube.Attachment.Smoke.Enabled = false
            item.__itemModel.Cylinder.Tube.C1 = CFrame.new(0.4, 0.8, -0) * CFrame.Angles(0, 0, 0)

            extinguishingPlayers[caller] = nil
        end
    end
}

return function (req)
    headerHandlers[req.headers](unpack(req.data))
end