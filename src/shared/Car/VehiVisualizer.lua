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

--]] Modules
local raider = require(replicatedStorage.Shared.Raider)

local sawdust = require(replicatedStorage.Sawdust)
local cdn = sawdust.core.cdn
local maid = sawdust.core.util.maid
local signal = sawdust.core.signal
local caching = sawdust.core.cache

--]] Settings
--]] Constants
--> CDN providers
local cdnPart, cdnItem = cdn.getProvider('part'), cdn.getProvider('item')
local cdnGame, cdnVFX  = cdn.getProvider('game'), cdn.getProvider('vfx')

--> Cache groups
local carSlotCache = caching.findCache('carSlots')

--]] Variables
--]] Functions
--]] Module
local carVis = {}
carVis.__index = carVis

type self = {
    __raider: raider.Raider,
    __uuid: string,
    __maid: maid.SawdustMaid,

    model: Model,
    runtime: RBXScriptConnection,

    enteredBay: signal.SawdustSignal,
}
export type CarVisualizer = typeof(setmetatable({} :: self, carVis))

function carVis.new(uuid: string, spawnOffset: number, buildInfo: {}) : CarVisualizer
    local self = setmetatable({} :: self, carVis)

    --> Setup self
    self.__uuid = uuid
    self.__maid = maid.new()

    self.model = cdnGame:getAsset('VehicleBase'):Clone()
    self.model.PrimaryPart.Anchored = true
    
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
    
    local engine, battery, filter, reservoir =
        cdnPart:getAsset(engineId), cdnPart:getAsset(batteryId),
        cdnPart:getAsset(filterId), cdnPart:getAsset(reservoirId)

    local engineModel, batteryModel, filterModel, reservoirModel =
        engine.style.model:Clone(), battery.style.model:Clone(),
        filter.style.model:Clone(), reservoir.style.model:Clone()
    engineModel.PrimaryPart.Anchored, batteryModel.PrimaryPart.Anchored,
    filterModel.PrimaryPart.Anchored, reservoirModel.PrimaryPart.Anchored =
        true, true, true, true
    
    local mappedHitboxes = {}
    local hitboxes = {}
    local engineBay = self.model.EngineBay
    for _, hitbox: Instance in pairs(engineBay:GetChildren()) do
        local hitboxId = hitbox:GetAttribute('hitboxId')
        if not hitboxId then continue end

        local hitboxToModel = {
            ['engine'] = engineModel,
            ['battery'] = batteryModel,
            ['filter'] = filterModel,
            ['reservoir'] = reservoirModel,
        }
        mappedHitboxes[hitboxId] = hitboxToModel[hitboxId]
        hitboxes[hitboxId] = hitbox
    end

    local runtime = runService.Heartbeat:Connect(function(deltaTime)
        for hitboxId, model in pairs(mappedHitboxes) do
            model:PivotTo(hitboxes[hitboxId].CFrame * CFrame.Angles(
                math.rad(90),
                math.rad(0),
                math.rad(0)
            ))
        end
    end)

    engineModel.Parent, batteryModel.Parent, filterModel.Parent, reservoirModel.Parent =
        engineBay, engineBay, engineBay, engineBay

    --> Chassis
    local chassisIdToPart = {
        ['chassis'] = self.model.Chassis.Chassis,
        ['driverDoor'] = self.model.DriverDoor,
        ['passengerDoor'] = self.model.PassengerDoor,
        ['hood'] = self.model.Hood
    }
    for partId: string, info: {} in pairs(buildInfo.chassis) do
        local part = chassisIdToPart[partId] :: BasePart

        local surfaceAppearances = {} :: {SurfaceAppearance}
        for _, inst in pairs(part:GetDescendants()) do
            if inst:IsA('SurfaceAppearance') then
                table.insert(surfaceAppearances, inst)
            end
        end

        local dirty = info.dirty

        local cleanColor = Color3.fromRGB(255, 255, 255)
        local dirtyColor = Color3.fromRGB(144, 111, 88)
        local dirtFactor = dirty/100

        for _, appearance in pairs(surfaceAppearances) do
            appearance.Color = cleanColor:Lerp(dirtyColor, dirtFactor)
        end
    end

    --> Create effects
    local issueHandlers = {
        ['fire'] = function(id: string)
            local model = mappedHitboxes[id] :: Model

            local vfx = cdnVFX:getAsset('PartFire').Attachment:Clone()
            vfx.Parent = model.PrimaryPart
        end,

        ['overheat'] = function(id: string)
            local model = mappedHitboxes[id] :: Model
            
            local vfx = cdnVFX:getAsset('PartSmoke').Attachment:Clone()
            vfx.Parent = model.PrimaryPart
        end
    }

    local function handleIssues(id: string, issues: {})
        for issue: string, isIssue: boolean in pairs(issues) do
            if not isIssue then continue end
            print(id, issue)
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

function carVis:hasRaider(thisRaider: raider.Raider)
    self.__raider = thisRaider end

function carVis:__start_driving(spawnPosition: Vector3)
    local bayPosition = workspace.Gameplay.StreetBayPoint.Position :: Vector3
    local turnPoint  = workspace.Gameplay.TurnBayPoint.Position :: Vector3

    local cPosition  = CFrame.new(spawnPosition) * CFrame.Angles(
        math.rad(-90),
        math.rad(-90),
        math.rad(0)
    ):Inverse()
    local origY = cPosition.Position.Y

    local distance   = (bayPosition-cPosition.Position).Magnitude
    local direction  = (bayPosition-cPosition.Position).Unit

    local maxSpeed = 60
    local accelTime, decelTime = 2, 1.5 --> Secs to reach max speed & time to slow down
    local accelDist, decelDist = (maxSpeed*accelTime)/2, (maxSpeed*decelTime/2)
    
    local cruiseDist = math.max(0, distance-accelDist-decelDist)

    local cSpeed
    local currentPhase = 'approaching' :: 'approaching'|'turning'|'queueing'
    local startTime = tick()

    local function handlePos(position: Vector3)
        return Vector3.new(
            position.X,
            origY,
            position.Z
        )
    end

    local function getAvailableSlot() : (number, Vector3)
        local slot
        local slotI
        for i=1,5 do
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

    local function startTurnPhase() : number
        currentPhase = 'turning'
        startTime = tick()
        spawnPosition = self.model.PrimaryPart.Position

        local turnDist = (turnPoint-spawnPosition).Magnitude
        local turnTime = turnDist/15
        
        direction = (turnPoint-spawnPosition).Unit

        return turnTime
    end

    local function startQueuePhase() : number
        currentPhase = 'queueing'
        startTime = tick()
        spawnPosition = self.model.PrimaryPart.Position

        local slotI, slotPos = getAvailableSlot()
        local queueDist = (slotPos-spawnPosition).Magnitude
        local queueTime = queueDist/25
        direction = (slotPos-spawnPosition).Unit

        return queueTime
    end

    local defaultRotation = CFrame.Angles(math.rad(-90), math.rad(-90), 0):Inverse()
    local moveConnection, wheelConnection
    moveConnection = runService.Heartbeat:Connect(function(deltaTime)
        
        --> Move car
        local elapsed = tick()-startTime
        
        local distTravel
        if currentPhase == 'approaching' then
            local shouldStartTurn = false
            
            if elapsed <= accelTime then --> Accel
                cSpeed = (maxSpeed/accelTime)*elapsed
                distTravel = .5*(maxSpeed/accelTime)*elapsed^2
            elseif elapsed <= accelTime+(cruiseDist/maxSpeed) then --> Cruising
                local cruiseTime = elapsed-accelTime
                cSpeed = maxSpeed
                distTravel = accelDist+(maxSpeed*cruiseTime)
            else --> Decel
                local decelElapsed = elapsed-accelTime-(cruiseDist/maxSpeed)
                local decelProg = decelElapsed/decelTime
                cSpeed = maxSpeed*(1-decelProg)
                distTravel = accelDist+cruiseDist+(maxSpeed*decelElapsed*(1-decelProg/2))
            
                if decelProg >= .7 and currentPhase == 'approaching' then
                    shouldStartTurn = true end
        end

        if shouldStartTurn then
            startTurnPhase()
        else
            local newPos = spawnPosition+(direction*distTravel)
            self.model:PivotTo(CFrame.new(handlePos(newPos)) * defaultRotation)
        end
        elseif currentPhase == 'turning' then
        local turnDistance = (turnPoint - spawnPosition).Magnitude
        local turnTime = turnDistance / 30
        
        if elapsed >= turnTime then
            self.model:PivotTo(CFrame.new(handlePos(turnPoint))*defaultRotation)
            startQueuePhase()
        else
            local alpha = elapsed / turnTime
            local newPosition = spawnPosition:Lerp(turnPoint, alpha)
            
            local offset = .65
            local lookDirection
            if alpha < offset then
                lookDirection = (turnPoint - newPosition).Unit
            else
                local slotI, slotPosition = getAvailableSlot()
                local turnAlpha = (alpha - offset) / offset
                
                local turnPointDirection = (turnPoint - newPosition).Unit
                local slotDirection = (slotPosition - newPosition).Unit
                
                lookDirection = turnPointDirection:Lerp(slotDirection, turnAlpha).Unit
            end
            
            local frontAxleOffset = 2.5
            local rotationPoint = newPosition + (self.model.PrimaryPart.CFrame.LookVector * frontAxleOffset)
            local lookCFrame = CFrame.lookAt(rotationPoint, rotationPoint + lookDirection)
            local finalCFrame = lookCFrame * CFrame.new(0, 0, -frontAxleOffset)
            
            self.model:PivotTo(CFrame.new(handlePos(finalCFrame.Position), handlePos(finalCFrame.Position + lookDirection)) * CFrame.Angles(math.rad(-90), math.rad(180), 0):Inverse())
        end
        elseif currentPhase == 'queueing' then
            local slotIndex, slotPosition = getAvailableSlot()
            local queueDistance = (slotPosition - spawnPosition).Magnitude
            local queueTime = queueDistance / 25
            
            if elapsed >= queueTime then
                self.model:PivotTo(CFrame.new(handlePos(slotPosition))*defaultRotation)

                --> Cleanup
                moveConnection:Disconnect()
                moveConnection=nil
                
                wheelConnection:Disconnect()
                wheelConnection=nil

                carSlotCache:getValue(slotIndex):occupySlot(self.__uuid)

                --> Move raider outside
                task.delay(1, function()
                    self.__raider:pivotTo(CFrame.new(slotPosition+Vector3.new(0, 3, 18))*CFrame.Angles(0, math.rad(180), 0))
                end)
            else
                local alpha = elapsed / queueTime
                local newPosition = spawnPosition:Lerp(slotPosition, alpha)
                self.model:PivotTo(CFrame.new(handlePos(newPosition))*defaultRotation)
            end
        end

        --> Move raider
        if self.__raider then
            local primaryPosition = self.model.PrimaryPart.CFrame :: CFrame
            local raiderPosition = primaryPosition:PointToWorldSpace(
                Vector3.new(2, 0, 0))
            
            self.__raider:pivotTo(CFrame.new(raiderPosition) * CFrame.Angles(
                math.rad(0),
                math.rad(-90),
                math.rad(0)
            ))
        end
    end)
    
    local wheelMotors = {}
    for _, inst: Instance in pairs(self.model.PrimaryPart:GetChildren()) do
        if not inst:IsA('Motor6D') then continue end
        if not inst.Name:sub(3,7) == 'Wheel' then continue end
        
        table.insert(wheelMotors, inst)
    end

    local cRot = 0
    wheelConnection = runService.Heartbeat:Connect(function(deltaTime)
        if not cSpeed then return end
        cRot = (cRot+cSpeed/8)%359
        
        for _, Motor: Motor6D in pairs(wheelMotors) do
            Motor.C1 = CFrame.new(Vector3.new(0, 0, 0)) * CFrame.Angles(0, math.rad(90), math.rad(-cRot))
        end
    end)
end

return carVis