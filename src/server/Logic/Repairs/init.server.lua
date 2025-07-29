--[[

    Repair Server Logic

    Griffin Dalby
    2025.07.28

    This script will provide extra logic for repairs and things of the sort.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')

--]] Modules
local car = require(replicatedStorage.Shared.Car)
local physItem = require(replicatedStorage.Shared.PhysItem)

local sawdust = require(replicatedStorage.Sawdust)

local networking = sawdust.core.networking
local caching = sawdust.core.cache

--]] Settings
--]] Constants
--> Networking channels
local vehicleChannel = networking.getChannel('vehicle')

--> Cache groups
local vehicleCache = caching.findCache('vehicle')

local physItems = caching.findCache('physItems')
local physItemDrags = caching.findCache('physItems.dragging')

--]] Variables
--]] Functions
--]] Script
local headerHandlers = {
    ['clean'] = function(caller: Player, vehicle: car.Car, cleanPart: string)
        local callerTag = `{caller.Name}.{caller.UserId}`
        local translator = {
            Chassis = 'chassis',
            Tailgate = 'tailgate',
            DriverDoor = 'driverDoor',
            PassengerDoor = 'passengerDoor',
            Hood = 'hood'
        }

        local partInfo = vehicle.build.chassis[translator[cleanPart]]
        if not partInfo then
            warn(`[{script.Name}] Player ({callerTag}) provided an unregistered cleanPart! ({cleanPart or '<none>'})`)
            return end

        local itemUuid = physItemDrags:getValue(caller)
        if not itemUuid then
            warn(`[{script.Name}] Player ({callerTag}) attempted to clean a vehicle, while holding nothing!`)
            return end
        
        local physItem = physItems:getValue(itemUuid) :: physItem.PhysicalItem
        if not physItem then
            warn(`[{script.Name}] Player ({callerTag}) is dragging an item, but it's unregistered? This is odd...`)
            return end
        if physItem.__itemId ~= 'sponge' then --> TODO: Check w/ other cleaning items
            warn(`[{script.Name}] Player ({callerTag}) attempted to clean a vehicle, while not holding a cleaning item!`)
            return end

        if physItem.wetness<=0 then return end --> Too dry to clean

        partInfo.dirty=math.clamp(partInfo.dirty-2, 0, partInfo.dirty+2)
        physItem:setWetness(math.clamp(physItem.wetness-.5, 0, 100))

        vehicleChannel.fix:with()
            :broadcastGlobally()
            :headers('updateChassis')
            :data(vehicle.uuid, translator[cleanPart], partInfo)
            :fire()
    end,

    ['takePart'] = function(caller: Player, vehicle: car.Car, partId: string)
        local callerTag = `{caller.Name}.{caller.UserId}`
        local partInBay = vehicle.build.engineBay[partId]
        if not partInBay then
            warn(`[{script.Name}] Player ({callerTag}) attempted to take a {partId} from the bay, which isn't there!`)
            return end

        vehicle.build.engineBay[partId] = nil
        print('success')
    end,
    ['putPart'] = function(caller: Player, vehicle: car.Car, partId: string, itemUuid: string)
        local callerTag = `{caller.Name}.{caller.UserId}`

        local physItem = physItems:getValue(itemUuid) :: physItem.PhysicalItem
        if not physItem then
            warn(`[{script.Name}] Player ({callerTag}) attempted to put an unregistered part in the engine bay!`)
            return end

        vehicle.build.engineBay[partId] = physItem
        print('success')
    end
}

vehicleChannel.fix:handle(function(req, res)
    local caller = players:GetPlayerByUserId(req.caller)
    local callerTag = `{caller.Name}.{caller.UserId}`

    local vehicleUuid = req.data[1]
    if not vehicleUuid or typeof(vehicleUuid) ~= 'string' then
        warn(`[{script.Name}] Player ({callerTag}) provided a malformed vehicle uuid! (Provided: {vehicleUuid or '<none>'})`)
        return end

    local foundVehicle = vehicleCache:getValue(vehicleUuid) :: car.Car
    if not foundVehicle then
        warn(`[{script.Name}] Player ({callerTag}) provided an unregistered vehicle uuid! (UUID8: {vehicleUuid:sub(1,8)})`)
        return end

    if not headerHandlers[req.headers] then
        warn(`[{script.Name}] Player ({callerTag}) provided an unregistered header! (Provided: {req.headers})`)
        return end
    
    table.remove(req.data, 1)

    -- res.setHeaders(req.headers)
    headerHandlers[req.headers](caller, foundVehicle, unpack(req.data))
    -- res.send()
end)