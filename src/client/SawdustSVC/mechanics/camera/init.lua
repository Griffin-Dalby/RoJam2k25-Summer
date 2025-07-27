--[[

    Camera Mechanics Service

    Griffin Dalby
    2025.07.16

    This service will handle first person camera mechanics, as well as
    the viewmodel.

--]]

--]] Services
local contextActionService = game:GetService('ContextActionService')
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpsService = game:GetService("HttpService")
local runService = game:GetService("RunService")
local players = game:GetService('Players')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local cdn = sawdust.core.cdn
local maid = sawdust.core.util.maid

local IArm = require(script.arm)

--]] Settings
--> Phys Drag
local raycastDistance = 10
local maxArmLength = 10
local goalHoldDistance = 4

local hingePullStrength = 2.5
local hoodPushForce, doorPushForce = 5, 0

--> Keybinds
local keybinds = {
    ['physDrag'] = {Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2}
}

--> Viewmodel Settings
local robloxProxy = "https://robloxdevforumproxy.glitch.me/users/inventory/list-json?assetTypeId=11&cursor=&itemsPerPage=100&pageNumber=%25x&sortOrder=Desc&userId="
local assetIds = {2,11} --> T-shirts, shirts

--]] Constants
--> Index player
local player = players.LocalPlayer
local camera = workspace.CurrentCamera

--> CDN Providers
local gameCDN = cdn.getProvider('game')
local vehicleBase = gameCDN:getAsset('VehicleBase')

--]] Variables
--]] Functions
function generateParams(character)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.RespectCanCollide = true

    return raycastParams
end

--]] Camera Service

return sawdust.builder.new('camera')
    :dependsOn('grab')
    :init(function(self, deps)
        self.physDragging = false

        self.currentArm  = nil
        self.__maid      = nil
    end)

    :method('putArm', function(self, castResult: RaycastResult)
        if self.physDragging then
            warn(`[{script.Name}] Attempt to internally physDrag while already doing so!`)
            return end
        self.physDragging = true
        self.__maid = maid.new()

        local character = player.Character
        local params = RaycastParams.new()

        --[[ SETUP ATTACHMENTS ]]--
        local hitInstance = castResult.Instance :: BasePart
        local hitPosition = castResult.Position
        local hitOffset   = hitInstance.CFrame:PointToObjectSpace(hitPosition)

        local isHinge = hitInstance:HasTag('Hinge')
        local isHorizontal = hitInstance:HasTag('Hinge') and hitInstance:HasTag('Horizontal')
        local topLevel = hitInstance:FindFirstAncestorOfClass('Model')

        params.FilterDescendantsInstances = {character, topLevel or hitInstance}
        params.RespectCanCollide = true

        local hitAttachment = Instance.new('Attachment')
        hitAttachment.CFrame = CFrame.new(hitOffset)
        hitAttachment.Parent = hitInstance

        local origClickedWorldPos = hitAttachment.WorldPosition

        local goalPart = Instance.new('Part')
        goalPart.Size,     goalPart.Transparency = Vector3.zero, 1
        goalPart.Anchored, goalPart.CanCollide   = true, false

        local goalAttachment = Instance.new('Attachment', goalPart)
        goalPart.Parent = workspace.__temp

        --[[ SETUP CONSTRAINTS ]]--
        local hinge
        local constraintOrVelo
        local veloConnection
        
        local lockHood = hitInstance:HasTag('Hood') and true or false

        if isHinge then
            hinge = topLevel:FindFirstChildWhichIsA('HingeConstraint') :: HingeConstraint
            if not hinge then warn('Couldnt find hinge') return end

            local hingePart = hinge.Attachment0.Parent :: BasePart
            local doorPart  = hinge.Attachment1.Parent :: BasePart

            if lockHood then
                hinge.UpperAngle = vehicleBase.Hood.Hinge.UpperAngle
                hinge.LowerAngle = vehicleBase.Hood.Hinge.LowerAngle
            end

            constraintOrVelo = Instance.new('BodyAngularVelocity')
            constraintOrVelo.AngularVelocity = Vector3.zero
            constraintOrVelo.MaxTorque = isHorizontal
                and Vector3.new(0, 0, 20000) or Vector3.new(0, 75000, 0)
            constraintOrVelo.Parent = doorPart

            local pushDirection = isHorizontal
                and Vector3.new(0, 0, hoodPushForce) --> Hood push force (Z-Axis)
                or Vector3.new(0, 0, doorPushForce)  --> Door push force (Y-Axis)

            constraintOrVelo.AngularVelocity = pushDirection
            task.wait(.1)
            constraintOrVelo.AngularVelocity = Vector3.zero

            veloConnection = runService.Heartbeat:Connect(function()
                local hingeWorldPos = hingePart.CFrame.Position
                local hingeAxis     = isHorizontal and hingePart.CFrame.LookVector or hingePart.CFrame.UpVector

                local toClicked = origClickedWorldPos - hingeWorldPos
                local toGoal = goalAttachment.WorldPosition - hingeWorldPos

                toClicked = toClicked-toClicked:Dot(hingeAxis)*hingeAxis
                toGoal    = toGoal-toGoal:Dot(hingeAxis)*hingeAxis

                local currentAngle = math.atan2(toClicked.X, toClicked.Z)
                local targetAngle = math.atan2(toGoal.X, toGoal.Z)

                local angleDiff = targetAngle-currentAngle
                if angleDiff>math.pi then
                    angleDiff=angleDiff-2*math.pi
                elseif angleDiff<-math.pi then
                    angleDiff=angleDiff+2*math.pi
                end

                constraintOrVelo.AngularVelocity = Vector3.new(
                    0,
                    isHorizontal and 0 or angleDiff*hingePullStrength,
                    isHorizontal and angleDiff*hingePullStrength or 0 )
            end)
        else
            constraintOrVelo = Instance.new('SpringConstraint')
            constraintOrVelo.MaxForce = math.huge
            constraintOrVelo.Stiffness = 70
            constraintOrVelo.FreeLength = 2
            constraintOrVelo.Damping = 6
            constraintOrVelo.Attachment0, constraintOrVelo.Attachment1
                = hitAttachment, goalAttachment
            constraintOrVelo.Parent = hitInstance
        end

        --[[ ARM & RUNTIME ]]--
        self.currentArm = IArm.new(hitAttachment)
        local runtime = runService.RenderStepped:Connect(function()
            local camCf = camera.CFrame

            -- local cast = workspace:Raycast(
            --     camCf.Position,
            --     camCf.LookVector*goalHoldDistance,
            --     params) :: RaycastResult
            
            -- local targetPosition = cast
            --     and cast.Position
            --     or camCf.Position+camCf.LookVector*goalHoldDistance

            goalPart.CFrame = CFrame.new(camCf.Position+camCf.LookVector*goalHoldDistance)
        end)

        --[[ CREATE MAID ]]--
        self.__maid:add(veloConnection)
        self.__maid:add(runtime)
        self.__maid:add(hitAttachment)
        self.__maid:add(constraintOrVelo)
        self.__maid:add(goalPart)

        self.__maid:add(function()
            if lockHood and hinge.CurrentAngle>math.rad(30) then
                hinge.LimitsEnabled = true
                hinge.UpperAngle = hinge.CurrentAngle+math.rad(5)
                hinge.LowerAngle = hinge.CurrentAngle-math.rad(5)
            end
        end)
    end)

    :method('retractArm', function(self)
        self.physDragging = false
        if self.currentArm then
            self.currentArm:discard() end
        if self.__maid then
            self.__maid:clean() end
    end)

    :start(function(self, deps)
        local character = player.Character or player.CharacterAdded:Wait()
        local params = generateParams(character)

        contextActionService:BindAction('physDrag', function(_, inputState)
            if inputState==Enum.UserInputState.Begin then
                if self.physDragging then
                    warn(`[{script.Name}] Attempt to PhysDrag while already doing it!`)
                    return end

                --> Raycast
                local cast = workspace:Raycast(
                    camera.CFrame.Position,
                    camera.CFrame.LookVector*raycastDistance,
                    params)
                if cast then
                    self.putArm(cast) end
            else
                if self.physDragging then
                    self.retractArm() end
            end
        end, false, unpack(keybinds.physDrag))
    end)