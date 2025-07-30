--[[

    Car Master Controller

    Griffin Dalby
    2025.07.24

    This script will control car behavior on the server and replicate
    to all clients.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')
local players = game:GetService('Players')

--]] Modules
local car     = require(replicatedStorage.Shared.Car)
local carSlot = require(replicatedStorage.Shared.CarSlot)
local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache
local networking = sawdust.core.networking

--]] Settings
--> Spawn Rate (Cubic)
local spawn_baseInterval = 20
local spawn_minInterval  = 40
local spawn_maxPlayers   = 4

--> Gameplay
local slotFolder = workspace.Gameplay.CarSpots
local slotCount = #slotFolder:GetChildren()

--]] Constants
--> Caches
local carSlotCache = caching.findCache('carSlots')

--> Networking Channels
local vehicleChannel = networking.getChannel('vehicle')

--]] Variables
local spawnInterval = spawn_baseInterval
local timeScaledInterval = spawnInterval

local gameTime = 0

--]] Functions

--[[ calcSpawnInterval() [ Cubic Curve ]
    This function will update the spawn interval according to the amount
    of players in the game. ]]
function calcSpawnInterval()
    local playerCount = #players:GetPlayers()
    local t = math.min(playerCount-1, spawn_maxPlayers-1)/(spawn_maxPlayers-1)
    local scaleFactor = 3*t^2 - 2*t^3

    local b_spawnInterval = spawn_baseInterval-(spawn_baseInterval-spawn_minInterval)*scaleFactor
    spawnInterval = math.max(spawn_minInterval, b_spawnInterval)
end

--[[ calcTimeScaling() [ Linear Curve ]
    This function will update the spawn interval according to the length
    of the current game session. ]]
function calcTimeScaling()
    local timeScale = math.max(.3, 1-(gameTime/500)) --> ~
end

--]] Script

--> Setup slots
for i = 1, slotCount do
    local thisSlot = carSlot.new(i)
end

--> Wait for tutorial to end (TODO)
--> Start spawning cars
print(`[{script.Name}] Car spawns starting...`)

local lastPlayerCount = 0

local spawnGoal = {
             baseTime = workspace:GetServerTimeNow()
}; spawnGoal.endTime  = workspace:GetServerTimeNow()+spawnInterval*(runService:IsStudio() and .1 or 1.5)

runService.Heartbeat:Connect(function(deltaTime)
    --[[ UPDATE SPAWN TIME ]]--
    calcSpawnInterval()

    --> Reconcile Players
    local maxPlayers = #players:GetPlayers()

    --[[ SPAWN ]]--

    --> Check if we should spawn
    local thisTime = workspace:GetServerTimeNow()
    if thisTime<spawnGoal.endTime then
        return end

    --> Check if there's a spot available
    local thisSlot: carSlot.CarSlot
    local slotIndex: number
    for i=1,maxPlayers do
        local iSlot = carSlotCache:getValue(i) :: carSlot.CarSlot
        if not iSlot:occupied() then
            thisSlot = thisSlot or iSlot
            slotIndex = slotIndex or i
        else
            thisSlot = nil
            slotIndex = nil
        end
    end

    if not thisSlot then return end --> Wait until ones available

    --> Set time
    spawnGoal.baseTime = thisTime
    spawnGoal.endTime  = thisTime+spawn_minInterval

    print(`[{script.Name}] Spawning car!`)
    
    local newCar = car.new()
    thisSlot:occupySlot(newCar.uuid)
    newCar:setBay(slotIndex)

end)