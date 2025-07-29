--[[

    Car Behavior Module

    Griffin Dalby
    2025.07.24

    This module will handle car behavior and the networking in between.

--]]

--]] Services
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

--]] Constants
local isServer = runService:IsServer()

--> Networking channel
local gameChannel = networking.getChannel('game')

--> Caching groups
local vehicleCache = caching.findCache('vehicle')

--]] Variables
--]] Functions
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
        vehicleCache:setValue(self.uuid, self)
        return self
    end

    --[[ CLIENT BEHAVIOR ]]--
    self.visualizer = vehiVisualizer.new(uuid, spawnOffset, self.build, buildUuids)

    vehicleCache:setValue(self.uuid, self)
    return self
end

--[[ CONTROLLER ]]--

--[[ car:hasRaider(raider: Raider)
    This will add a raider to the car. ]]
function car:hasRaider(hasRaider: raider.Raider)
    assert(not self.__raider, `Attempt to add raider to car ({self.uuid:sub(1,8)}) with a raider already in it!`)
    self.raider = hasRaider
    self.visualizer:hasRaider(hasRaider)
end

return car