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

local vehiVisualizer = require(script.VehiVisualizer)
local partChances = require(script.partChances)

local sawdust = require(replicatedStorage.Sawdust)
local networking = sawdust.core.networking
local caching = sawdust.core.cache

--]] Settings
local spawnStrip = workspace.Gameplay:WaitForChild('SpawnStrip') :: Part

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
    visualizer: vehiVisualizer.CarVisualizer?

}
export type Car = typeof(setmetatable({} :: self, car))

--[[ car.new()
    Create a new car data or physical object. ]]
function car.new(uuid: string, spawnOffset: number, buildInfo: {}) : Car
    --[[ CREATE SELF ]]--
    local self = setmetatable({} :: self, car)
    self.uuid = isServer and 
        https:GenerateGUID(false) or uuid

    self.build = isServer and {
        chassis = {
            chassis = {
                dirty = math.random(0, 100),
            },
            driverDoor = {
                dirty = math.random(0, 100)
            },
            passengerDoor = {
                dirty = math.random(0, 100)
            },
            hood = {
                dirty = math.random(0, 100),
            },
        },

        engineBay = {
            engine    = partChances('engine'),
            battery   = partChances('battery'),
            filter    = partChances('filter'),
            reservoir = partChances('reservoir'),
        }
    } or buildInfo

    --[[ SERVER BEHAVIOR ]]--
    if isServer then
        local xOffset = math.random(-spawnStrip.Size.X/2, spawnStrip.Size.X/2)
        
        --> Replicate & save
        gameChannel.vehicle:with()
            :broadcastGlobally()
            :headers('spawn')
            :data(self.uuid, xOffset, self.build)
            :fire()

        self.raider = raider.new(self.uuid)

        vehicleCache:setValue(self.uuid, self)
        return self
    end

    --[[ CLIENT BEHAVIOR ]]--
    self.visualizer = vehiVisualizer.new(uuid, spawnOffset, self.build)

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