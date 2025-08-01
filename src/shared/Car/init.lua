--[[

    Car Behavior Module

    Griffin Dalby
    2025.07.24

    This module will handle car behavior and the networking in between.

--]]

--]] Services
local Players = game:GetService('Players')
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')
local https = game:GetService('HttpService')

--]] Modules
local raider = require(replicatedStorage.Shared.Raider)
local physItems = require(replicatedStorage.Shared.PhysItem)

local vehiVisualizer = require(script.VehiVisualizer)
local partChances = require(script.partChances)

local sawdust = require(replicatedStorage.Sawdust)
local networking = sawdust.core.networking
local caching = sawdust.core.cache

--]] Settings
local spawnStrip = workspace.Gameplay:WaitForChild('SpawnStrip') :: Part

local defDirtyRange = {0, 100}
local dirtyRanges = {

}

local partSpawns = {
    ['engine'] = {
        {'engine.scrappy', 70},
        {'engine.v4', 30},
    },
    ['battery'] = {
        {'battery.scrappy', 60},
        {'battery.t1', 40},
    },
    ['filter'] = {
        {'filter.scrappy', 50},
        {'filter.t1', 50},
    },
    ['reservoir'] = {
        {'reservoir.scrappy', 100}
    }
}

--]] Constants
local isServer = runService:IsServer()

--> Networking channel
local gameChannel = networking.getChannel('game')
local vehicleChannel = networking.getChannel('vehicle')

--> Caching groups
local vehicleCache = caching.findCache('vehicle')
local carSlotCache = caching.findCache('carSlots')

--]] Variables
--]] Functions
local function deepCopy(original)
    if type(original) ~= "table" then
        return original end
    
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = deepCopy(value) end
    
    return copy
end

--]] Module
local car = {}
car.__index = car

type chassisBuild = {
    dirty: number,
}
type self = {
    --[[ GENERAL ]]--
    uuid: string,      --> Access ID for car
    spawned: boolean?, --> True if spawned, nil if not.

    build: {
        chassis: {
            chassis: chassisBuild,
            tailgate: chassisBuild,
            driverDoor: chassisBuild,
            passengerDoor: chassisBuild,
            hood: chassisBuild
        },

        engineBay: {
            engine: {},
            battery: {},
            filter: {},
            reservoir: {},
        }
    },

    --[[ SERVER ]]--


    --[[ CLIENT ]]--
    buildUuids: {
        engine: string,
        battery: string,
        filter: string,
        reservoir: string,
    },

    visualizer: vehiVisualizer.CarVisualizer?,
}
export type Car = typeof(setmetatable({} :: self, car))

--[[ car.new()
    Create a new car data or physical object. ]]
function car.new(uuid: string, spawnOffset: number, buildInfo: {}, buildUuids: {}) : Car
    --[[ CREATE SELF ]]--
    local self = setmetatable({} :: self, car)
    self.uuid = isServer and 
        https:GenerateGUID(false) or uuid

    local function generateChassisBuild(id: string)
        local dirtyRange = dirtyRanges[id]

        return {
            dirty = dirtyRange 
                and math.random(dirtyRange[1], dirtyRange[2]) 
                or math.random(defDirtyRange[1], defDirtyRange[2])
        }
    end

    --> Generate build
    self.build = isServer and {
        chassis = {
            chassis = generateChassisBuild('chassis'),
            tailgate = generateChassisBuild('tailgate'),
            driverDoor = generateChassisBuild('driverDoor'),
            passengerDoor = generateChassisBuild('passengerDoor'),
            hood = generateChassisBuild('hood'),
        },

        engineBay = {
            engine    = partChances('engine'),
            battery   = partChances('battery'),
            filter    = partChances('filter'),
            reservoir = partChances('reservoir'),
        }
    } or buildInfo
    self.buildUuids = isServer and nil or buildUuids

    --[[ SERVER BEHAVIOR ]]--
    if isServer then
        local xOffset = math.random(-spawnStrip.Size.X/2, spawnStrip.Size.X/2)
        
        --> Register parts as physItems
        self.origIssues = deepCopy(self.build)

        local engineBay = self.build.engineBay

        local enginePart = physItems.new(engineBay.engine[1])
        local batteryPart = physItems.new(engineBay.battery[1])
        local filterPart = physItems.new(engineBay.filter[1])
        local reservoirPart = physItems.new(engineBay.reservoir[1])

        for partId: string, part: physItems.PhysicalItem in pairs{engine=enginePart,battery=batteryPart,filter=filterPart,reservoir=reservoirPart} do
            local chances = self.build.engineBay[partId]
            local issues = chances[2]

            for issueId: string, state: boolean in pairs(issues) do
                if not state then continue end
                part:addTag(`issue.{issueId}`)

                if issueId == 'fire' then
                    part.fire = math.random(50, 100)
                end
            end
        end

        --> Create new scrap parts
        local spawnParts = {
            engine = math.random(1,2),
            battery = math.random(1,2),
            filter = math.random(1,2),
            reservoir = math.random(1,2)
        } :: {[number]: string}
        local function randomPart(partType: string)
            local chances = partSpawns[partType]
            local weight = 0
            for i=1,#chances do
                weight = weight+chances[i][2] end
            local roll = math.random(1, weight)

            weight = 0
            for i=1,#chances do
                weight = weight+chances[i][2]
                if roll <= weight then
                    return chances[i][1]
                end
            end
        end

        for id, amount in pairs(spawnParts) do
            for i=1,amount do
                local part = physItems.new(randomPart(id))

                local spawnAreas = workspace.Gameplay.PartSpawns
                local areaChildren = spawnAreas:GetChildren()
                local chosenArea = areaChildren[math.random(1, #areaChildren)]

                local rng = Random.new()
                local x = rng:NextNumber(-chosenArea.Size.X/2, chosenArea.Size.X/2)
                local y = rng:NextNumber(-chosenArea.Size.Y/2, chosenArea.Size.Y/2)
                local z = rng:NextNumber(-chosenArea.Size.Z/2, chosenArea.Size.Z/2)

                part:putItem(
                    {chosenArea.Position.X+x, chosenArea.Position.Y+y, chosenArea.Position.Z+z},
                    {math.random(-360, 360), math.random(-360, 360), math.random(-360, 360)}
                )
            end
        end

        --> Replicate & save
        gameChannel.vehicle:with()
            :broadcastGlobally()
            :headers('spawn')
            :data(self.uuid, xOffset, self.build, 
                {enginePart.__itemUuid, batteryPart.__itemUuid,
                 filterPart.__itemUuid, reservoirPart.__itemUuid, })
            :fire()
        
        engineBay.engine = enginePart
        engineBay.battery = batteryPart
        engineBay.filter = filterPart
        engineBay.reservoir = reservoirPart

        self.raider = raider.new(self.uuid)
        self.raider:calculatePatience(self.build)

        vehicleCache:setValue(self.uuid, self)
        return self
    end

    --[[ CLIENT BEHAVIOR ]]--
    self.visualizer = vehiVisualizer.new(uuid, spawnOffset, self.build, buildUuids)

    vehicleCache:setValue(self.uuid, self)
    return self
end

--[[ FETCHERS ]]--
function car:getBay(): number
    return self.bayId end
function car:getRaider(): raider.Raider
    return self.raider end

--[[ CONTROLLER ]]--
function car:driveAway()
    if isServer then
        vehicleChannel.finish:with()
            :broadcastGlobally()
            :headers('finish')
            :data(self.uuid)
            :fire()

        return
    end

    carSlotCache:getValue(self:getBay()):empty()    
    self.visualizer:__start_driving_away()
end

--[[ car:setBay(bayId: number)
    Sets the internal bay ID value. ]]
function car:setBay(bayId: number)
    self.bayId = bayId end

--[[ car:hasRaider(raider: Raider)
    This will add a raider to the car. ]]
function car:hasRaider(hasRaider: raider.Raider)
    assert(not self.__raider, `Attempt to add raider to car ({self.uuid:sub(1,8)}) with a raider already in it!`)
    self.raider = hasRaider
    self.visualizer:hasRaider(hasRaider)
end

return car