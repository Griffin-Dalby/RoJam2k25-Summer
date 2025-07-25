--[[

    Vehicle Client Visualizer

    Griffin Dalby
    2025.07.24

    This module will provide a controller, wrapping a vehicular model
    for client replication.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local cdn = sawdust.core.cdn

--]] Settings
--]] Constants
--> CDN providers
local cdnPart, cdnItem = cdn.getProvider('part'), cdn.getProvider('item')
local cdnGame          = cdn.getProvider('game')

--]] Variables
--]] Functions
--]] Module
local carVis = {}
carVis.__index = carVis

type self = {
    model: Model
}
export type CarVisualizer = typeof(setmetatable({} :: self, carVis))

function carVis.new() : CarVisualizer
    local self = setmetatable({} :: self, carVis)

    self.model = cdnGame:getAsset('VehicleBase'):Clone()

    return self
end

return carVis