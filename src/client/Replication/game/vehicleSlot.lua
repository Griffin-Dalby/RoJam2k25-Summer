--[[

    game.vehicleSlot listener

    Griffin Dalby
    2025.07.27

    This listener will just.. do the same thing, it's 3 am let me just
    make this in peace

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local carSlot = require(replicatedStorage.Shared.CarSlot)
local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache

--]] Constants
--> Caching groups
local carSlotCache = caching.findCache('carSlots')

--]] Variables
--]] Functions
--]] Listener
local headerHandlers = {
    ['occupied'] = function(index: number, carUUID: string)
        local foundSlot = carSlotCache:getValue(index) :: carSlot.CarSlot
        assert(foundSlot, `Failed to find slot @ index [{index}]!`)

        foundSlot:occupySlot(carUUID)
    end,

    ['empty'] = function(index: number)
        local foundSlot = carSlotCache:getValue(index) :: carSlot.CarSlot
        assert(foundSlot, `Failed to find slot @ index [{index}]!`)

        foundSlot:empty()
    end
}

return function(req)
    headerHandlers[req.headers](unpack(req.data))
end