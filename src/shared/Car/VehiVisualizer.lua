--[[

    Vehicle Client Visualizer

    Griffin Dalby
    2025.07.24

    This module will provide a controller, wrapping a vehicular model
    for client replication.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')
local players = game:GetService('Players')

--]] Modules
local physItem = require(replicatedStorage.Shared.PhysItem)
local raider = require(replicatedStorage.Shared.Raider)

local sawdust = require(replicatedStorage.Sawdust)
local cdn = sawdust.core.cdn
local maid = sawdust.core.util.maid
local signal = sawdust.core.signal
local caching = sawdust.core.cache
local services = sawdust.services
local networking = sawdust.core.networking

--]] Settings
local maxSpeed = 60
local accelTime, decelTime = 2, 1.5 --> Secs to reach max speed & time to slow down
local accelDist, decelDist = (maxSpeed*accelTime)/2, (maxSpeed*decelTime/2)

--]] Constants
--> CDN providers
local cdnPart, cdnItem = cdn.getProvider('part'), cdn.getProvider('item')
local cdnGame, cdnVFX  = cdn.getProvider('game'), cdn.getProvider('vfx')

--> Cache groups
local vehicleCache = caching.findCache('vehicle')
local carSlotCache = caching.findCache('carSlots')
local physItemCache = caching.findCache('physItems')

--> Networking channels
local gameChannel = networking.getChannel('game')
local vehicleChannel = networking.getChannel('vehicle')

--]] Variables
--]] Functions
function getAvailableSlot() : (number, Vector3)
        local slot
        local slotI
        for i=1,#players:GetPlayers() do
            local iSlot = carSlotCache:getValue(i)
            if not iSlot:occupied() then
                slot = slot or iSlot
                slotI = slotI or i
            else
                slot = nil
                slotI = nil
            end
        end

        if not slot then
            --> Not slot available!
            error(`There is no slot available!`)
            return
        end
        return slotI, slot:getSlotModel().PrimaryPart.Position
    end

--]] Module
local carVis = {}
carVis.__index = carVis

type self = {
    __raider: raider.Raider,
    __uuid: string,
    __maid: maid.SawdustMaid,

    buildInfo: {},
    model: Model,
    runtime: RBXScriptConnection,

    enteredBay: signal.SawdustSignal,
}
export type CarVisualizer = typeof(setmetatable({} :: self, carVis))

function carVis.new(uuid: string, spawnOffset: number, buildInfo: {}, buildUuids: {[string]: string}) : CarVisualizer
    local self = setmetatable({} :: self, carVis)

    --> Index player
    local player = players.LocalPlayer
    local playerUi = player.PlayerGui:WaitForChild('UI') :: ScreenGui
    local keybindUi = playerUi:WaitForChild('Keybinds')   :: Frame

    --> Setup self
    self.__uuid = uuid
    self.__maid = maid.new()

    self.buildInfo = buildInfo
    self.model = cdnGame:getAsset('VehicleBase'):Clone()
    self.model.PrimaryPart.Anchored = true

    self.model:SetAttribute('uuid', uuid)
    
    local thisSignal = signal.new()
    self.enteredBay = thisSignal:newSignal()

    --> Create engine bay
    local engineBayInfo = buildInfo.engineBay
    local engineInfo, batteryInfo, filterInfo, reservoirInfo = 
        engineBayInfo.engine, engineBayInfo.battery,
        engineBayInfo.filter, engineBayInfo.reservoir

    local engineId, engineIssues = unpack(engineInfo)
    local batteryId, batteryIssues = unpack(batteryInfo)
    local filterId, filterIssues = unpack(filterInfo)
    local reservoirId, reservoirIssues = unpack(reservoirInfo)

    local function getItem(uuid: string): physItem.PhysicalItem
        return physItemCache:getValue(uuid) end
    local engineItem, batteryItem, filterItem, reservoirItem =
        getItem(buildUuids[1]), getItem(buildUuids[2]), getItem(buildUuids[3]), getItem(buildUuids[4])

    assert(engineItem, `Failed to find engine item!`); assert(batteryItem, `Failed to find battery item!`)
    assert(filterItem, `Failed to find filter item!`); assert(reservoirItem, `Failed to find reservoir item!`)
    
    local mappedHitboxes = {} --> Expose this
    local hitboxes = {}
    local engineBay = self.model.EngineBay

    local idToItem = {
        ['engine'] = engineItem,
        ['battery'] = batteryItem,
        ['filter'] = filterItem,
        ['reservoir'] = reservoirItem,
    }
    for _, hitbox: Instance in pairs(engineBay:GetChildren()) do
        local hitboxId = hitbox:GetAttribute('hitboxId')
        if not hitboxId then continue end

        mappedHitboxes[hitboxId] = idToItem[hitboxId]
        hitboxes[hitboxId] = hitbox
    end

    local engineOlapParams = OverlapParams.new()
    local runtime = runService.Heartbeat:Connect(function(deltaTime)
        --> Update engine bay
        for hitboxId, item: physItem.PhysicalItem in pairs(mappedHitboxes) do
            local model = item.__itemModel
            local hitboxCf = hitboxes[hitboxId].CFrame :: CFrame

            if item.grabbed then --> Remove from engine bay
                vehicleChannel.fix:with()
                    :headers('takePart')
                    :data(self.__uuid, hitboxId)
                    :fire()

                model:AddTag('DontAddToEngine')
                task.delay(2, function()
                    model:RemoveTag('DontAddToEngine') end)

                model.PrimaryPart.Anchored = false
                mappedHitboxes[hitboxId] = nil
                
                return
            end
            model.PrimaryPart.Anchored = true
            item:setTransform{{hitboxCf.X, hitboxCf.Y, hitboxCf.Z}, {90, 0, 0}}
            item.isRendered = true

            model:PivotTo(hitboxCf * CFrame.Angles(
                math.rad(90),
                math.rad(0),
                math.rad(0)
            ))
        end
    
        for _, hitbox: Instance in pairs(hitboxes) do
            --> Check placement
            local hitboxId = hitbox:GetAttribute('hitboxId')
            if not mappedHitboxes[hitboxId] then
                local partsIn = workspace:GetPartsInPart(hitbox, engineOlapParams)
                for _, instance: Instance in pairs(partsIn) do
                    --> Run checks
                    local topLayer = instance:FindFirstAncestorWhichIsA('Model')
                    if not topLayer then continue end

                    local itemUuid = topLayer:GetAttribute('itemUuid')
                    local itemId = topLayer:GetAttribute('itemId')
                    if not itemUuid or not itemId then continue end

                    local enginePart = cdnPart:getAsset(itemId)
                    if not enginePart then continue end
                    if enginePart.behavior.partType ~= hitboxId then continue end

                    local physPart = physItemCache:getValue(itemUuid) :: physItem.PhysicalItem
                    if not physPart then continue end

                    --> Add to engine
                    if physPart.__itemModel:HasTag('DontAddToEngine') then continue end

                    if physPart.grabbed and physPart.grabbed == players.LocalPlayer then
                        gameChannel.physItem:with()
                            :headers('drop')
                            :data{
                                hitbox.Position,
                                {linear = Vector3.zero, angular = Vector3.zero}}
                            :invoke()

                        services:getService('grab').grabbing = false
                        keybindUi.PickUp.Visible = false
                        keybindUi.Drop.Visible = false
                        keybindUi.Use.Visible = false

                        physPart:drop() end
                        
                    vehicleChannel.fix:with()
                        :headers('putPart')
                        :data(self.__uuid, hitboxId, physPart.__itemUuid)
                        :fire()

                    mappedHitboxes[hitboxId] = physPart
                end
            end

            --> Update slots
            if not mappedHitboxes[hitboxId] then
                --> Missing!
                hitbox.Transparency = .75
                hitbox.Missing.Enabled = true
            else
                --> Present
                hitbox.Transparency = 1
                hitbox.Missing.Enabled = false
            end
        end
    end)

    engineItem.__itemModel.Parent, batteryItem.__itemModel.Parent,
    filterItem.__itemModel.Parent, reservoirItem.__itemModel.Parent =
        workspace.__objects, workspace.__objects, workspace.__objects, workspace.__objects

    --> Chassis
    self:updateChassis()

    --> Create effects
    local issueHandlers = {
        ['fire'] = function(id: string)
            local item = mappedHitboxes[id] :: physItem.PhysicalItem
            local model = item.__itemModel

            local vfx = cdnVFX:getAsset('PartFire').Attachment:Clone()
            vfx.Parent = model.PrimaryPart
            vfx.Name =  `issue.fire`
            item:addTag('issue.fire')
        end,

        ['overheat'] = function(id: string)
            local item = mappedHitboxes[id] :: physItem.PhysicalItem
            local model = item.__itemModel
            
            local vfx = cdnVFX:getAsset('PartSmoke').Attachment:Clone()
            vfx.Parent = model.PrimaryPart
            vfx.Name =  `issue.overheat`
            item:addTag('issue.overheat')
        end
    }

    local function handleIssues(id: string, issues: {})
        for issue: string, isIssue: boolean in pairs(issues) do
            if not isIssue then continue end
            issueHandlers[issue](id)
        end
    end

    handleIssues('engine', engineIssues)
    handleIssues('battery', batteryIssues)
    handleIssues('filter', filterIssues)
    handleIssues('reservoir', reservoirIssues)
    
    --> Start driving behavior & render
    local spawnPosition = workspace.Gameplay.SpawnStrip.Position
        + Vector3.new(spawnOffset, 0, 0)

    self:__start_driving(spawnPosition)
    self.model.Name = `vehicle_{uuid}`
    self.model.Parent = workspace.__temp

    --> Setup maid
    self.__maid:add(self.model)
    self.__maid:add(function()
        self.enteredBay:destroy()
    end)

    return self
end

function carVis:updateChassis()
    local chassisIdToPart = {
        ['chassis'] = self.model.Chassis.Chassis,
        ['tailgate'] = self.model.Chassis.Tailgate,
        ['driverDoor'] = self.model.DriverDoor,
        ['passengerDoor'] = self.model.PassengerDoor,
        ['hood'] = self.model.Hood
    }

    for partId: string, info: {} in pairs(self.buildInfo.chassis) do
        local part = chassisIdToPart[partId] :: BasePart

        local surfaceAppearances = {} :: {SurfaceAppearance}
        for _, inst in pairs(part:GetDescendants()) do
            if inst:IsA('SurfaceAppearance') then
                table.insert(surfaceAppearances, inst)
            end
        end

        local dirty = info.dirty
        part:SetAttribute('dirty', dirty)

        local cleanColor = Color3.fromRGB(255, 255, 255)
        local dirtyColor = Color3.fromRGB(144, 111, 88)
        local dirtFactor = dirty/100

        for _, appearance in pairs(surfaceAppearances) do
            appearance.Color = cleanColor:Lerp(dirtyColor, dirtFactor)
        end
    end
end

function carVis:hasRaider(thisRaider: raider.Raider)
    self.__raider = thisRaider end

function carVis:__start_driving(spawnPosition: Vector3)
    local bayPosition = workspace.Gameplay.StreetBayPoint.Position :: Vector3
    local turnPoint  = workspace.Gameplay.TurnBayPoint.Position :: Vector3

    local cSpeed = 0
    local cPhase = 'approaching_entrance' :: 'approaching_entrance'|'turning_into_bay'|'finding_parking'|'parked'
    local startTime = tick()
    local moveConn, wheelConn

    local origY = spawnPosition.Y
    local function handlePos(position: Vector3)
        return Vector3.new(position.X, origY, position.Z) end

    local function moveStraight(startPos: Vector3, targetPos: Vector3, speed: number, onComplete: () -> ())
        local dist = (targetPos-startPos).Magnitude
        local travelTime = dist/speed

        return function (elapsed: number): boolean
            if elapsed >= travelTime then
                self.model:PivotTo(CFrame.new(handlePos(targetPos))
                    * CFrame.Angles(math.rad(-90), math.rad(-90), 0):Inverse())

                cSpeed = speed
                if onComplete then onComplete() end
                return true
            else
                local alpha = elapsed/travelTime
                local newPos = startPos:Lerp(targetPos, alpha)

                cSpeed = speed
                self.model:PivotTo(CFrame.new(handlePos(newPos))
                    * CFrame.Angles(math.rad(-90), math.rad(-90), 0):Inverse())

                return false
            end
        end
    end

    local function turnToTarget(startPos: Vector3, targetPos: Vector3, speed: number, onComplete: () -> ())
        local dist = (targetPos-startPos).Magnitude
        local travelTime = dist/speed

        return function(elapsed: number): boolean
            if elapsed >= travelTime then
                self.model:PivotTo(CFrame.new(handlePos(targetPos))
                    * CFrame.Angles(math.rad(-90), math.rad(-90), 0):Inverse())

                cSpeed = speed
                if onComplete then onComplete() end
                return true
            else
                local alpha = elapsed/travelTime
                local newPos = startPos:Lerp(targetPos, alpha)
                cSpeed = speed
                
                -- Smooth turning - gradually rotate from current direction to target direction
                local lookDirection
                if alpha < 0.6 then
                    --> First part of turn | look toward turn target
                    lookDirection = (targetPos - newPos).Unit
                else
                    --> Later part of turn | start looking toward bay entry
                    local bayDirection = (turnPoint - newPos).Unit
                    local turnDirection = (targetPos - newPos).Unit
                    local turnAlpha = (alpha - 0.6) / 0.4
                    lookDirection = turnDirection:Lerp(bayDirection, turnAlpha).Unit
                end
                
                -- Apply rotation
                self.model:PivotTo(CFrame.new(handlePos(newPos), handlePos(newPos + lookDirection)) * CFrame.Angles(math.rad(-90), math.rad(180), 0):Inverse())
                return false
            end
        end
    end

    local cMover
    cMover = moveStraight(spawnPosition, bayPosition, 60, function()
        cPhase = 'turning_into_bay'
        startTime = tick()

        cMover = turnToTarget(bayPosition, turnPoint, 30, function()
            cPhase = 'finding_parking'
            startTime = tick()

            local slotIndex, slotPosition = getAvailableSlot()
            cMover = moveStraight(turnPoint, slotPosition, 20, function()
                cPhase = 'parked'
                
                local vehicle = vehicleCache:getValue(self.__uuid)
                vehicle:setBay(slotIndex)
                carSlotCache:getValue(slotIndex):occupySlot(self.__uuid)
                
                task.delay(1, function()
                    if self.__raider then
                        self.__raider:pivotTo(CFrame.new(slotPosition + Vector3.new(0, 3, 18)) * CFrame.Angles(0, math.rad(180), 0))
                        self.__raider:calculatePatience(self.buildInfo)
                    end
                end)
                
                if moveConn then
                    moveConn:Disconnect()
                    moveConn = nil end
                if wheelConn then
                    wheelConn:Disconnect()
                    wheelConn = nil end
            end)
        end)
    end)

    moveConn = runService.Heartbeat:Connect(function(deltaTime)
        if cPhase == 'parked' then return end
        
        local elapsed = tick() - startTime
        if cMover then
            cMover(elapsed) end
        
        -- Update raider position
        if self.__raider then
            local primaryPosition = self.model.PrimaryPart.CFrame :: CFrame
            local raiderPosition = primaryPosition:PointToWorldSpace(Vector3.new(2, 0, 0))
            self.__raider:pivotTo(CFrame.new(raiderPosition) * CFrame.Angles(0, math.rad(-90), 0))
        end
    end)

    local wheelMotors = {}
    for _, inst: Instance in pairs(self.model.PrimaryPart:GetChildren()) do
        if not inst:IsA('Motor6D') then continue end
        if not inst.Name:sub(3,7) == 'Wheel' then continue end
        
        table.insert(wheelMotors, inst)
    end

    local cRot = 0
    wheelConn = runService.Heartbeat:Connect(function(deltaTime)
        if not cSpeed then return end
        cRot = (cRot+cSpeed/1.5)%359
        
        for _, Motor: Motor6D in pairs(wheelMotors) do
            Motor.C1 = CFrame.new(Vector3.new(0, 0, 0)) * CFrame.Angles(0, math.rad(90), math.rad(-cRot))
        end
    end)
    
end

function carVis:__start_driving_away()
    local bayExitEnd = workspace.Gameplay.ExitBayPoint.Position :: Vector3
    local exitSplit = workspace.Gameplay.StreetExitPoint.Position :: Vector3
    local finalExit = workspace.Gameplay.FinalStreetPoint.Position :: Vector3
    
    local parkingCf = self.model:GetPivot() :: CFrame
    local parkingPos = parkingCf.Position

    local cSpeed = 0
    local cPhase = 'exiting_to_bay_end' :: 'exiting_to_bay_end'|'turning_to_road'|'driving_away'
    local startTime = tick()

    local moveConn, wheelConn
    local origY = parkingPos.Y

    local function handlePos(position: Vector3)
        return Vector3.new(position.X, origY, position.Z) end

    local function moveStraight(startPos: Vector3, targetPos: Vector3, speed: number, onComplete: () -> ())
        local dist = (targetPos-startPos).Magnitude
        local travelTime = dist/speed

        return function (elapsed: number): boolean
            if elapsed >= travelTime then
                self.model:PivotTo(CFrame.new(handlePos(targetPos))
                    * CFrame.Angles(math.rad(-90), math.rad(-90), 0):Inverse())

                cSpeed = speed
                if onComplete then onComplete() end
                return true
            else
                local alpha = elapsed/travelTime
                local newPos = startPos:Lerp(targetPos, alpha)

                cSpeed = speed
                self.model:PivotTo(CFrame.new(handlePos(newPos))
                    * CFrame.Angles(math.rad(-90), math.rad(-90), 0):Inverse())

                return false
            end
        end
    end

    local function turnToTarget(startPos: Vector3, targetPos: Vector3, speed: number, onComplete: () -> ())
        local dist = (targetPos-startPos).Magnitude
        local travelTime = dist/speed

        return function(elapsed: number): boolean
            if elapsed >= travelTime then
                self.model:PivotTo(CFrame.new(handlePos(targetPos))
                    * CFrame.Angles(math.rad(-90), math.rad(-90), 0):Inverse())

                cSpeed = speed
                if onComplete then onComplete() end
                return true
            else
                local alpha = elapsed/travelTime
                local newPos = startPos:Lerp(targetPos, alpha)
                cSpeed = speed
                
                local lookDirection
                if alpha < 0.6 then
                    lookDirection = (targetPos - newPos).Unit
                else
                    local roadDirection = (finalExit - newPos).Unit
                    local turnDirection = (targetPos - newPos).Unit

                    local turnAlpha = (alpha - 0.6) / 0.4
                    lookDirection = turnDirection:Lerp(roadDirection, turnAlpha).Unit
                end
                
                -- Apply rotation
                self.model:PivotTo(CFrame.new(handlePos(newPos), handlePos(newPos + lookDirection)) * CFrame.Angles(math.rad(-90), math.rad(180), 0):Inverse())
                return false
            end
        end
    end

    local cMover
    cMover = moveStraight(parkingPos, bayExitEnd, 20, function()
        cPhase = 'turning_to_road'
        startTime = tick()

        cMover = turnToTarget(bayExitEnd, exitSplit, 25, function()
            cPhase = 'driving_away'
            startTime = tick()

            cMover = moveStraight(exitSplit, finalExit, 45, function()
                if moveConn then
                    moveConn:Disconnect()
                    moveConn = nil
                end

                if wheelConn then
                    wheelConn:Disconnect()
                    wheelConn = nil
                end

                --> Cleanup model
            end)
        end)
    end)

    moveConn = runService.Heartbeat:Connect(function(deltaTime)
        local elapsed = tick()-startTime
        if cMover then
            cMover(elapsed) end

        if self.__raider then
            local primaryPosition = self.model.PrimaryPart.CFrame :: CFrame
            local raiderPosition = primaryPosition:PointToWorldSpace(Vector3.new(2, 0, 0))
            self.__raider:pivotTo(CFrame.new(raiderPosition) * CFrame.Angles(0, math.rad(-90), 0))
        end
    end)

    local wheelMotors = {}
    for _, inst: Instance in pairs(self.model.PrimaryPart:GetChildren()) do
        if not inst:IsA('Motor6D') then continue end
        if not inst.Name:sub(3,7) == 'Wheel' then continue end
        
        table.insert(wheelMotors, inst)
    end

    local cRot = 0
    wheelConn = runService.Heartbeat:Connect(function(deltaTime)
        if not cSpeed then return end
        cRot = (cRot+cSpeed/1.5)%359
        
        for _, Motor: Motor6D in pairs(wheelMotors) do
            Motor.C1 = CFrame.new(Vector3.new(0, 0, 0)) * CFrame.Angles(0, math.rad(90), math.rad(-cRot))
        end
    end)
end

return carVis