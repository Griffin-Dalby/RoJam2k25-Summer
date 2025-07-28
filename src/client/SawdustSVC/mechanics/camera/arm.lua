--[[

    Camera Arm Controller

    Griffin Dalby
    2025.07.25

    This module will provide a interface to create a "strechy arm"

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)

local util = sawdust.core.util
local maid = util.maid

--]] Settings
local cameraOffset = Vector3.new(
    2, -2, 0
)

--]] Constants
local camera = workspace.CurrentCamera

--]] Variables
--]] Functions
--]] Module
local arm = {}
arm.__index = arm

type self = {
    __maid: maid.SawdustMaid,

    target: Attachment,
    runtime: RBXScriptConnection
}
export type CameraArm = typeof(setmetatable({} :: self, arm))

function arm.new(target: Attachment)
    local self = setmetatable({} :: self, arm)

    --> Build self
    self.target = target
    
    --> Build arm
    self.arm = Instance.new('Model')
    local armHumanoid = Instance.new('Humanoid', self.arm)
    local armPart = Instance.new('Part')
    armPart.Anchored = true
    armPart.CanCollide = false

    armPart.Name = 'Right Arm'

    self.runtime = runService.RenderStepped:Connect(function(deltaTime)
        local cameraCf = camera.CFrame
        local offsetPosition = (cameraCf*CFrame.new(cameraOffset)).Position

        local attachPosition   = self.target.WorldCFrame.Position
        local offsetAttachDist = (offsetPosition-attachPosition).Magnitude

        armPart.Size = Vector3.new(
            1.5, 1.5, offsetAttachDist)

        local initalCf = CFrame.lookAt(
            offsetPosition,
            self.target.WorldCFrame.Position)
        armPart.CFrame = initalCf + initalCf.LookVector*offsetAttachDist/2
    end)

    armPart.Parent = self.arm
    self.arm.Parent = camera
    
    --> Setup maid
    -- self.__maid = maid.new()
    -- self.__maid:add(self.arm)
    -- self.__maid:add(self.runtime)

    return self
end

function arm:discard()
    if self.runtime then
        self.runtime:Disconnect()
        self.runtime = nil end
    if self.arm then
        self.arm:Destroy()
        self.arm = nil end
end

return arm