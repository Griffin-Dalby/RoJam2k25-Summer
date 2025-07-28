--[[

    vehicle.fix listener

    Griffin Dalby
    2025.07.28

    This module will provide a listener for the vehicle fix event, allowing
    this client to replicate changes.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local car = require(replicatedStorage.Shared.Car)

local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache

--]] Settings
--]] Constants
--> Caching groups
local vehicleCache = caching.findCache('vehicle')

--]] Variables
--]] Functions
--]] Listener
local headerHandlers = {
    ['updateChassis'] = function(vehicleUuid: string, cleanPart: string, partInfo: {})
        local foundVehicle = vehicleCache:getValue(vehicleUuid) :: car.Car
        assert(foundVehicle, `Failed to find vehicle! (UUID8: {vehicleUuid:sub(1, 8)})`)

        foundVehicle.build.chassis[cleanPart] = partInfo

        foundVehicle.visualizer.buildInfo = foundVehicle.build
        foundVehicle.visualizer:updateChassis()
    end
}

return function (req)
    headerHandlers[req.headers](unpack(req.data))
end