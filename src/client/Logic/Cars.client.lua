--[[

    Car Client Controller

    Griffin Dalby
    2025.07.24

    This script will render and handle car behavior and interactions.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local carSlot = require(replicatedStorage.Shared.CarSlot)
local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache

--]] Settings
local slotFolder = workspace.Gameplay.CarSpots
local slotCount = #slotFolder:GetChildren()

--]] Constants
--> Caches
local carSlotCache = caching.findCache('carSlots')

--]] Variables
--]] Functions
--]] Script

--> Setup slots
for i = 1, slotCount do
    local thisSlot = carSlot.new(i)
end