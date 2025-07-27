--[[

    game.raider Listener

    Griffin Dalby
    2025.07.27

    This module will provide a listener for the raider event, allowing
    the player to render where the raider is and what it's doing.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local raider = require(replicatedStorage.Shared.Raider)
local car = require(replicatedStorage.Shared.Car)

local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache

--]] Constants
--> Caching groups
local vehicleCache = caching.findCache('vehicle')

--]] Variables
--]] Functions
--]] Listener
local headerHandlers = {
    ['create'] = function(raiderUuid: string, outfitId: number, headId: number, skinTone: Color3)
        local thisRaider = raider.new(raiderUuid, outfitId, headId, skinTone)

        --> Attempt to add to vehicle
        local foundVehicle = vehicleCache:getValue(raiderUuid) :: car.Car
        if not foundVehicle then return end

        foundVehicle:hasRaider(thisRaider)
    end
}

return function(req)
    headerHandlers[req.headers](unpack(req.data))
end