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

local signal = sawdust.core.signal

--]] Settings
local itemDropDistance = 10
local itemHoldDistance = 5

local itemUpdateSpeed = .15

--]] Constants
local isServer = runService:IsServer()

--> CDN Providers
local itemCDN = cdn.getProvider('item')

--> Networking channels
local gameChannel = networking.getChannel('game')

--> Cache groups
local physItems = caching.findCache('physItems')
local physItemDrags = caching.findCache('physItems.dragging')

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
	--> Setup self in general
    local self = setmetatable({} :: self, physItem)

    self.__itemId = itemId

    local shouldReplicate = isServer and (itemUuid or true) or nil
    self.__itemUuid = isServer and httpsService:GenerateGUID(false) or itemUuid
    itemUuid = self.__itemUuid

    self.__transform = {
        position = {0, 0, 0},
        rotation = {0, 0, 0}
    }

    self.grabbed = false
    self.grabUpdater = nil
    
    --> Server behavior
    if isServer then
        physItems:setValue(itemUuid, self)
        if shouldReplicate then
            gameChannel.physItem:with()
                :broadcastGlobally()
                :headers('create')
                :data{itemId, itemUuid}
                :fire()
        end

        return self
    end

    --> Create & verify info
	local itemAsset = itemCDN:getAsset(itemId)
	assert(itemAsset, `Item with ID {itemId} not found in CDN.`)

	--> Set up self visually
    self.__itemAsset = itemAsset
    self.__itemModel = itemAsset.style.model:Clone()

    --> Set up item model
    self.__itemModel:AddTag('physItem')
    self.__itemModel:SetAttribute('itemUuid', self.__itemUuid)
    self.__itemModel:SetAttribute('itemId', self.__itemId)

    return self
end

--[[ MECHANICS ]]--
function physItem:drop(position: Vector3?, velocity: {linear: Vector3?, angular: Vector3?})
    if isServer then
        if not self.grabbed then
            return false end

        self.grabbed = nil
        return true
    end

    if self.grabUpdater then --> Disconnect logic
        self.grabUpdater:Disconnect()
        self.grabUpdater = nil end

    --> Destroy drag constraints
    assert(self.grabConstraints, `Missing grab constraints!`)
    self.grabConstraints.goalPart:Destroy()
    self.grabConstraints.itemAttach:Destroy()
    self.grabConstraints.alignOri:Destroy()
    self.grabConstraints.alignPos:Destroy()

    self.grabConstraints = nil
    self.grabbed = nil

    --> Apply pos&velocity
    if not position then return end
    assert(velocity, `Position has been provided, but velocity has not!`)

    local rotation = self:getTransform().rotation
    local cf = CFrame.new(position) * CFrame.Angles(
        math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
    
    local targetPart
    if self.__itemModel:IsA('Model') then
        self.__itemModel:PivotTo(cf)
        targetPart = self.__itemModel.PrimaryPart
        print(self.__itemModel:GetPivot())
    elseif self.__itemModel:IsA('BasePart') then
        self.__itemModel.CFrame = cf
        targetPart = self.__itemModel
    end

    targetPart.AssemblyLinearVelocity  = velocity.linear
    targetPart.AssemblyAngularVelocity = velocity.angular
end

function physItem:grab(grabbingPlayer: Player, callback: (external: true) -> nil)
    if isServer then
        if self.grabbed then
            return false end

        self.grabbed = grabbingPlayer
        physItemDrags:setValue(grabbingPlayer, self.__itemUuid)
        return true
    end

    --> Create drag constraints
    if self.grabbed then return end
    self.grabbed = grabbingPlayer

    local camera = workspace.CurrentCamera
    local goalPart = Instance.new('Part')
    goalPart.Size = Vector3.zero
    goalPart.Transparency = 1
    goalPart.Anchored, goalPart.CanCollide = true, false
    goalPart.Name = `dragGoalPart.{self.__itemUuid:sub(1,8)}}`

    local targetedItem = self.__itemModel
    local itemAttachment, goalAttachment = Instance.new('Attachment'), Instance.new('Attachment')
    itemAttachment.Name, goalAttachment.Name = 'itemAttach', 'goalAttach'
    itemAttachment.Parent, goalAttachment.Parent =
        targetedItem:IsA('Model') and targetedItem.PrimaryPart or targetedItem, goalPart
    
    goalPart.Parent = workspace.Temp

    local alignPos = Instance.new('AlignPosition')
    alignPos.MaxForce = 500000
    alignPos.MaxVelocity = 1000
    alignPos.Responsiveness = 1000
    alignPos.RigidityEnabled = false
    alignPos.Attachment0, alignPos.Attachment1 = itemAttachment, goalAttachment
    alignPos.Parent = itemAttachment.Parent
    alignPos.Visible = true

    local alignOri = Instance.new('AlignOrientation')
    alignOri.MaxTorque = 500000
    alignOri.MaxAngularVelocity = 10000
    alignOri.Responsiveness = 10000
    alignOri.Attachment0, alignOri.Attachment1 = itemAttachment, goalAttachment
    alignOri.Parent = itemAttachment.Parent

    self.grabConstraints = {
        ['goalPart'] = goalPart,
        ['itemAttach'] = itemAttachment,
        ['goalAttach'] = goalAttachment,

        ['alignPos'] = alignPos,
        ['alignOri'] = alignOri
    }

    --> Logic
    local thisPlayer = players.LocalPlayer
    local timeSinceLastUpdate = 100

    local interpPos = nil
    self.grabUpdater = runService.RenderStepped:Connect(function(deltaTime)
        if not self.grabbed then return end

        --> Update attachment
        local basePosition = nil
        local goalPosition = nil
        if thisPlayer==grabbingPlayer then
            basePosition = camera.CFrame
            goalPosition = basePosition.Position + basePosition.LookVector*itemHoldDistance
        else
            local head = grabbingPlayer.Character:FindFirstChild('Head')
            basePosition = head.CFrame
            
            local currentPosition = Vector3.new(unpack(self:getTransform().position))
            if interpPos then
                local distance = (currentPosition-self.__itemModel:GetPivot().Position).Magnitude
                local lerpSpeed = math.min(itemUpdateSpeed * (1 + distance * 0.5), 1)

                interpPos = interpPos:Lerp(currentPosition, lerpSpeed)
            else
                interpPos = currentPosition
                self:putItem({currentPosition.X, currentPosition.Y, currentPosition.Z}, {0, 0, 0})
            end
            local lookPos = CFrame.lookAt(
                head.Position,
                interpPos )

            goalPosition = basePosition.Position + lookPos.LookVector*itemHoldDistance
        end
        
        goalAttachment.WorldCFrame = CFrame.lookAt(
            goalPosition,
            basePosition.Position,
            Vector3.yAxis)

        local itemWorldCf = itemAttachment.WorldCFrame
        local rotX, rotY, rotZ = itemAttachment.WorldCFrame:ToEulerAnglesXYZ()
              rotX, rotY, rotZ = math.deg(rotX), math.deg(rotY), math.deg(rotZ)

        self:setTransform{
            {itemWorldCf.X, itemWorldCf.Y, itemWorldCf.Z},
            {rotX, rotY, rotZ}
        }
        if thisPlayer == grabbingPlayer then --> Mechanics
            --> Check should drop
            if (goalAttachment.WorldCFrame.Position-itemAttachment.WorldCFrame.Position).Magnitude>=itemDropDistance then
                if callback then
                    callback(true) end --> Is external
                self:drop(); return end
                
            --> Check if should update server
            timeSinceLastUpdate+=deltaTime
            if timeSinceLastUpdate>.2 then
                local velocity = self:getVelocity()

                timeSinceLastUpdate = 0
                gameChannel.physItem:with()
                    :headers('dragUpdate')
                    :data{goalPosition}
                    :fire()
            end
        end
    end)

end

function physItem:putItem(position: {[number]: number}, rotation: {[number]: number})
    self:setTransform({position, rotation})
    
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

--[[ TRANSFORM ]]--
function physItem:setTransform(transform: {position: {}, rotation: {}})
    assert(transform, `Attempt to set transform without a transform table!`)
    
    local translatedTransform = {
        ['position'] = transform[1] or self.__transform.position,
        ['rotation'] = transform[2] or self.__transform.rotation,
    }

    self.__transform = translatedTransform
end

function physItem:getTransform() : {position: {}, rotation: {}}
    return self.__transform end

function physItem:getVelocity() : {linear: Vector3, angular: Vector3}
    if isServer then return end

    local checkPart: BasePart = self.__itemModel:IsA('Model') and self.__itemModel.PrimaryPart or self.__itemModel
    local linVelo, angVelo = checkPart.AssemblyLinearVelocity, checkPart.AssemblyAngularVelocity
    
    return {linear = linVelo, angular = angVelo}
end

return physItem