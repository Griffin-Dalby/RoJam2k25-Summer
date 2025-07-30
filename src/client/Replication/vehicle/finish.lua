--[[

    vehicle.finish listener

    Griffin Dalby
    2025.07.29

    This script will provide a listener for the finish event.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local car = require(replicatedStorage.Shared.Car)
local sawdust = require(replicatedStorage.Sawdust)

local networking = sawdust.core.networking
local caching = sawdust.core.cache

--]] Settings
--]] Constants
--> Networking channels
local vehicleChannel = networking.getChannel('vehicle')

--> Caching gtoupd
local vehicleCache = caching.findCache('vehicle')

--]] Variables
--]] Functions
--]] Listener
return function(req, res)
    local vehicleUuid = unpack(req.data) 
    local vehicle = vehicleCache:getValue(vehicleUuid) :: car.Car
    if not vehicle then
        warn(`[{script.Name}] Failed to find vehicle! (UUID8: {vehicleUuid and vehicleUuid:sub(1,8) or '<none>'})`)
        return end

    vehicle:driveAway()
    vehicle.raider:removePresence()
end