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
local sawdust = require(replicatedStorage.Sawdust)

--]] Settings
--]] Constants
--]] Variables
--]] Functions
--]] Listener
local headerHandlers = {
    
}

return function (req)
    headerHandlers[req.headers](unpack(req.data))
end