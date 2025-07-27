--[[

    Raider Module

    Griffin Dalby
    2025.07.27

    This module will provide an object for server and client, controlling
    raiders, from simply standing there to raids.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')
local https = game:GetService('HttpService')

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
local vehicleCache = caching.findCache('vehicle')

--]] Variables
--]] Functions
--]] Modules
local raider = {}
raider.__index = raider

type self = {}
export type Raider = typeof(setmetatable({} :: self, raider))

function raider.new(uuid: string): Raider
    local self = setmetatable({} :: self, raider)

    --[[ SETUP SELF ]]--
    self.uuid = isServer and https:GenerateGUID(false) or uuid

    if isServer then
        --[[ SERVER ]]--
        gameChannel.raider:with()
            :broadcastGlobally()
            :headers('create')
            :data(self.uuid)
            :fire()

        return self
    end

    --[[ CLIENT ]]--

    return self
end

return raider