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
local cdn = sawdust.core.cdn

--]] Settings
--]] Constants
--> Networking channels
local gameChannel = networking.getChannel('game')
local vehicleChannel = networking.getChannel('vehicle')

--> Cache groups
local gameCache = caching.findCache('game')

local vehicleCache = caching.findCache('vehicle')
local carSlotCache = caching.findCache('carSlots')

local physItems = caching.findCache('physItems')
local physItemDrags = caching.findCache('physItems.dragging')

--> CDN providers
local partCDN = cdn.getProvider('part')

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
    end,
    ['putPart'] = function(caller: Player, vehicle: car.Car, partId: string, itemUuid: string)
        local callerTag = `{caller.Name}.{caller.UserId}`

        local physItem = physItems:getValue(itemUuid) :: physItem.PhysicalItem
        if not physItem then
            warn(`[{script.Name}] Player ({callerTag}) attempted to put an unregistered part in the engine bay!`)
            return end

        vehicle.build.engineBay[partId] = physItem
    end
}

vehicleChannel.fix:handle(function(req, res)
    local caller = players:GetPlayerByUserId(req.caller)
    local callerTag = `{caller.Name}.{caller.UserId}`

    --> Sanity Checks
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

vehicleChannel.finish:handle(function(req, res)
    local caller = players:GetPlayerByUserId(req.caller)
    local callerTag = `{caller.Name}.{caller.UserId}`

    --> Sanity Checks
    local vehicleUuid = req.data[1]
    if not vehicleUuid or typeof(vehicleUuid) ~= 'string' then
        warn(`[{script.Name}] Player ({callerTag}) provided a malformed vehicle uuid! (Provided: {vehicleUuid or '<none>'})`)
        return end

    local foundVehicle = vehicleCache:getValue(vehicleUuid) :: car.Car
    if not foundVehicle then
        warn(`[{script.Name}] Player ({callerTag}) provided an unregistered vehicle uuid! (UUID8: {vehicleUuid:sub(1,8)})`)
        return end

    --> Compare expectations
    local expectations = foundVehicle.raider.expectations
    local tolerenceScores = { --> How many total issues each mood can tolerate
        patient = 2,
        impatient = 1,
        violent = 0,
        desperate = 3, }

    local payments = {
        cleanPart = 25,
        issueFixed = 75,
    }

    --> Find total problems
    local totalProblems = 0
    local workDone = {
        partsCleaned = 0,
        issuesFixed = 0,
    }

    --[[ Parts Cleaned ]]--
    for partId: string, partInfo: {} in pairs(foundVehicle.build.chassis) do
        local dirty = partInfo.dirty

        if dirty >= expectations.chassis.maxDirt then
            totalProblems += 1
        end
    end

    for partId: string, partInfo: {} in pairs(foundVehicle.origIssues.chassis) do
        local curDirty = foundVehicle.build.chassis[partId].dirty

        if  (partInfo.dirty > expectations.chassis.maxDirt)
        and (curDirty <= expectations.chassis.maxDirt) then
            --> Part was fully clean
            workDone.partsCleaned += 1
        end
    end

    --[[ Parts Fixed ]]--
    local qualityPoints = 0
    local qualityParts = 0

    for partId: string, part: physItem.PhysicalItem in pairs(foundVehicle.build.engineBay) do
        local isBroken = false
        local tags = part:getTags()
        for tag: string in pairs(tags) do
            local iTag, issue = unpack(tag:split('.'))
            if iTag~='issue' then continue end

            if not table.find(expectations.engineBay.allowedIssues, issue) then
                isBroken = true
                totalProblems += 1
            end
        end

        if not isBroken then
            --> Add quality points
            local partAsset = partCDN:getAsset(part.__itemId)
            qualityPoints+=partAsset.behavior.quality
            qualityParts+=1
        end
    end

    for partId: string, partInfo: {} in pairs(foundVehicle.origIssues.engineBay) do
        local foundPart = foundVehicle.build.engineBay[partId]
        for issueId: string, isIssue in pairs(partInfo[2]) do
            if isIssue~=true then continue end
            if not foundPart:hasTag(`issue.{issueId}`) then
                --> Part was fixed
                workDone.issuesFixed += 1
            end
        end
    end

    --> Calculate base payment
    local basePayment = 0
    basePayment += (workDone.partsCleaned*payments.cleanPart)
    basePayment += (workDone.issuesFixed *payments.issueFixed)

    local avgQuality = qualityPoints/qualityParts
    basePayment += math.floor(avgQuality*.5)

    --> Decide to scam
    local scamChances = {
        patient = .05,
        impatient = .15,
        violent = .25,
        desperate = .10,
    }

    local raiderMood = foundVehicle.raider.mood
    local raiderSatisfied = totalProblems <= tolerenceScores[raiderMood]
    
    local scamChance = scamChances[raiderMood]
    if not raiderSatisfied then
        scamChance *= 1.5 end

    local payment = 0
    local willScam = math.random() < scamChance
    if willScam then
        if raiderSatisfied then
            payment = basePayment*.7 --> Pay partial scam
        else
            payment = 0 --> Pay none scam
        end
    else
        payment = basePayment --> Pay full price
    end

    --> Put payment in balance
    gameCache:setValue('scraps', gameCache:getValue('scraps')+payment)
    gameChannel.scraps:with()
        :broadcastGlobally()
        :headers('set')
        :data(gameCache:getValue('scraps'))
        :fire()

    --> Remove car
    carSlotCache:getValue(foundVehicle:getBay()):empty()
    
    table.remove(req.data, 1)
    foundVehicle:driveAway()

    res.setHeaders(req.headers)
    res.setData(raiderSatisfied, willScam)
    res.send()

end)

--[[ Special Listeners ]]--
local playersExtinguishing = {}
local extinguisherHandlers = {
    ['start'] = function(caller: Player, itemUuid: string)
        assert(not table.find(playersExtinguishing, caller),
            `Player ({caller.Name}.{caller.UserId}) attempted to start extinguishing, but they already are!`)

        assert(itemUuid, 'Attempt to start extinguishing w.o/ itemUuid!')
        local item = physItems:getValue(itemUuid) :: physItem.PhysicalItem
        assert(item, `Attempt to extinguish w/ invalid itemUuid!`)

        table.insert(playersExtinguishing, caller)
        gameChannel.extinguisher:with()
            :broadcastGlobally()
            :headers('start')
            :data(caller.UserId, itemUuid)
            :fire()
    end,

    ['extinguish'] = function(caller: Player, itemUuid: string)
        assert(table.find(playersExtinguishing, caller),
            `Player ({caller.Name}.{caller.UserId}) attempted to extinguish item, while not extinguishing!`)

        assert(itemUuid, 'Attempt to extinguish w.o/ itemUuid!')
        local item = physItems:getValue(itemUuid) :: physItem.PhysicalItem
        assert(item, `Attempt to extinguish w/ invalid itemUuid!`)

        if not item:hasTag('issue.fire') then return true end
        item.fire = math.clamp(item.fire-2, 0, 100)
        if item.fire==0 then
            item:removeTag('issue.fire') end

        gameChannel.extinguisher:with()
            :broadcastGlobally()
            :headers('extinguish')
            :data(caller.UserId, itemUuid, item.fire)
            :fire()
        return true;

    end,

    ['stop'] = function(caller: Player)
        local extinguishIndex = table.find(playersExtinguishing, caller)
        assert(extinguishIndex,
            `Player ({caller.Name}.{caller.UserId}) attempted to stop extinguishing, while they aren't!`)

        table.remove(playersExtinguishing, extinguishIndex)
        gameChannel.extinguisher:with()
            :broadcastGlobally()
            :headers('stop')
            :data(caller.UserId)
            :fire()
    end
}

gameChannel.extinguisher:handle(function(req, res)
    local caller = players:GetPlayerByUserId(req.caller)
    local callerTag = `{caller.Name}.{caller.UserId}`

    local header = req.headers

    if not extinguisherHandlers[header] then
        warn(`[{script.Name}] Player ({callerTag}) attempted to extinguish w/ invalid header!`)
        return end

    res.setHeaders(header)
    res.setData(extinguisherHandlers[header](caller, unpack(req.data)))
end)