--[[

    Car Slot Interface

    Griffin Dalby
    2025.07.24

    This interface will control the car parking spots, simply recording
    data and allowing replicated changes.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')

--]] Modules
local car = require(replicatedStorage.Shared.Car)
local sawdust = require(replicatedStorage.Sawdust)

local networking = sawdust.core.networking
local caching = sawdust.core.cache

--]] Settings
--]] Constants
local isServer = runService:IsServer()

--> Networking channels
local gameChannel = networking.getChannel('game')

--> Caching groups
local carSlotCache = caching.findCache('carSlots')
local vehicleCache = caching.findCache('vehicle')

--]] Variables
--]] Functions
--]] Module
local carSlot = {}
carSlot.__index = carSlot

type self = {
    index: number,

    --[[ CLIENT ]]--
    slotModel: Model,
    currentCar: car.Car?
}
export type CarSlot = typeof(setmetatable({} :: self, carSlot))

--[[ carSlot.new(index: number)
    Creates a new car slot @ the index provided. ]]
function carSlot.new(index: number) : CarSlot
    local self = setmetatable({} :: self, carSlot)

    self.index = index
    carSlotCache:setValue(index, self)

    if isServer then return self end

    self.slotModel = workspace.Gameplay.CarSpots:FindFirstChild(index)

    return self
end

--[[ CONTROLLERS ]]--
function carSlot:occupySlot(carUUID: string)
    local sideTag = isServer and 'SERVER' or 'CLIENT'
    assert(not self.currentCar, `[{sideTag}][UUID8:{carUUID:sub(1, 8)}] There was an attempt to occupy an already occupied slot!`)

    local currentCar = vehicleCache:getValue(carUUID) :: car.Car
    assert(currentCar, `[{sideTag}][UUID8:{carUUID:sub(1, 8)}] Unable to locate vehicle in cache!`)

    if isServer then
        gameChannel.vehicleSlot:with()
            :broadcastGlobally()
            :headers('occupied')
            :data(self.index, carUUID)
    end

    self.currentCar = currentCar
end

function carSlot:empty()
    assert(self.currentCar, `Attempt to empty an already empty slot!`)

    if isServer then
        gameChannel.vehicleSlot:with()
            :broadcastGlobally()
            :headers('empty')
            :data(self.index)
    end

    self.currentCar = nil
end

--[[ DATA FETCHERS ]]--

--[[ carSlot:occupied()
    Returns the occupied status of this car slot. ]]
function carSlot:occupied()
    return (self.currentCar~=nil) end

--[[ carSlot:getSlotModel()
    Returns the model of the current slot. ]]
function carSlot:getSlotModel()
    return self.slotModel end

return carSlot