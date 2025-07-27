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
local vehiVisualizer = require(script.VehiVisualizer)

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

type self = {
    --[[ GENERAL ]]--
    uuid: string,      --> Access ID for car
    spawned: boolean?, --> True if spawned, nil if not.

    --[[ SERVER ]]--


    --[[ CLIENT ]]--
    visualizer: vehiVisualizer.CarVisualizer?

}
export type Car = typeof(setmetatable({} :: self, car))

--[[ car.new()
    Create a new car data or physical object. ]]
function car.new(uuid: string, spawnOffset: number) : Car
    --[[ CREATE SELF ]]--
    local self = setmetatable({} :: self, car)
    self.uuid = isServer and 
        https:GenerateGUID(false) or uuid

    --[[ SERVER BEHAVIOR ]]--
    if isServer then
        local xOffset = math.random(-spawnStrip.Size.X/2, spawnStrip.Size.X/2)

        --> Choose vehicle variety
        local engine, battery, resevoir, filter
        

        --> Replicate & save
        gameChannel.vehicle:with()
            :broadcastGlobally()
            :headers('spawn')
            :data(self.uuid, xOffset)
            :fire()

        vehicleCache:setValue(self.uuid, self)
        return self
    end

    --[[ CLIENT BEHAVIOR ]]--
    self.visualizer = vehiVisualizer.new(uuid, spawnOffset)

    vehicleCache:setValue(self.uuid, self)
    return self
end

return car