--[[

    game.vehicle Listener

    Griffin Dalby
    2025.07.25

    This module will provide a listener for the vehicle event,
    aiding in communication with the server in relation to
    vehicular repairs.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local car = require(replicatedStorage.Shared.Car)
local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache

--]] Constants
--> Caching groups

--]] Variables
--]] Functions
--]] Listener
local headerHandlers = {
    ['spawn'] = function(carUuid: string, spawnOffset: number)
        local newCar = car.new(carUuid, spawnOffset)
    end
}

return function(req)
    headerHandlers[req.headers](unpack(req.data))
end