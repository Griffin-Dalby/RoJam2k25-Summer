--[[

    Car Slot Interface

    Griffin Dalby
    2025.07.24

    This interface will control the car parking spots, simply recording
    data and allowing replicated changes.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)

--]] Settings
--]] Constants
--]] Variables
--]] Functions
--]] Module
local carSlot = {}
carSlot.__index = carSlot

type self = {
    index: number
}
export type CarSlot = typeof(setmetatable({} :: self, carSlot))

--[[ carSlot.new(index: number)
    Creates a new car slot @ the index provided. ]]
function carSlot.new(index: number) : CarSlot
    local self = setmetatable({} :: self, carSlot)

    self.index = index

    return self
end

return carSlot