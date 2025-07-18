--[[

    PhysicalItem Module

    Griffin Dalby
    2025.07.16

    This module will provide an object for a physical item, one that
    can be interacted with, picked up, and used in the world.

--]]

--]] Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpsService = game:GetService("HttpService")
local runService = game:GetService("RunService")
local players = game:GetService('Players')

--]] Modules
--> Sawdust
local sawdust = require(replicatedStorage.Sawdust)

local networking = sawdust.core.networking
local caching = sawdust.core.cache
local cdn = sawdust.core.cdn

--]] Settings
--]] Constants
local isServer = runService:IsServer()

--> CDN Providers
local itemCDN = cdn.getProvider('item')

--> Networking channels
local gameChannel = networking.getChannel('game')

--]] Variables
--]] Functions
--]] PhysItem
local physItem = {}
physItem.__index = physItem

type self = {
    __itemId: string, 
    __itemUuid: string,
    __itemAsset: {},
    __itemModel: Model,

    __transform: {
        position: {[number]: number},
        rotation: {[number]: number}?
    },

    grabbed: boolean,
    grabUpdater: {}
}
export type PhysicalItem = typeof(setmetatable({} :: self, physItem))

function physItem.new(itemId: string, itemUuid: string) : PhysicalItem
	--> Server behavior
    if isServer then
        itemUuid = httpsService:GenerateGUID(false)

        local self = setmetatable({
            __itemId = itemId,
            __itemUuid = itemUuid,

            __transform = {
                position = {0, 0, 0}
            },

            grabbed = false,
        } :: self, physItem)

        caching.findCache('physItems'):setValue(itemUuid, self)
        gameChannel.physItem:with()
            :broadcastGlobally()
            :headers('create')
            :data{itemId, itemUuid}
            :fire()

        return self
    end

    --> Create & verify info
    local self = setmetatable({} :: self, physItem)

	local itemAsset = itemCDN:getAsset(itemId)
	assert(itemAsset, `Item with ID {itemId} not found in CDN.`)

	--> Set up self
    self.__itemId = itemId
    self.__itemUuid = itemUuid
    self.__itemAsset = itemAsset
    self.__itemModel = itemAsset.style.model:Clone()

    self.__transform = {
        position = {0, 0, 0},
        rotation = {0, 0, 0}
    }

    --> Set up item model
    self.__itemModel:AddTag('physItem')
    self.__itemModel:SetAttribute('itemUuid', self.__itemUuid)
    self.__itemModel:SetAttribute('itemId', self.__itemId)

    --> Set up item data
    self.grabbed = false
    self.grabUpdater = nil

    return self
end

function physItem:putItem(position: {[number]: number}, rotation: {[number]: number})
    self.__transform = {
        ['position'] = position,
        ['rotation'] = rotation,
    }
    
    if isServer then
        --> Tell clients to put this item @ transform
        local call = gameChannel.physItem:with()
            :broadcastGlobally()
            :headers('put')
            :data{self.__itemUuid, position, rotation}
            :fire()

        return true end

    --> Reparent
    if self.__itemModel.Parent~=workspace.Objects then
        self.__itemModel.Parent=workspace.Objects end
    
    --> Put this item @ transform
    if self.grabbed and self.grabbed == players.LocalPlayer then
        --> Drop item
       
        self.grabbed = nil
    end

    --> Pivot item
    self.__itemModel:PivotTo(
        CFrame.new(unpack(position)) * CFrame.Angles(
            math.rad(rotation[1]),
            math.rad(rotation[2]),
            math.rad(rotation[3])
        )
    )
end

function physItem:getTransform() : {position: {}, rotation: {}}
    return self.__transform end

return physItem