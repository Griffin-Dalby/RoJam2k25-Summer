--[[

    Computer Controller

    Griffin Dalby
    2025.07.27

    This script will control the computer and give the player access
    to the shop.

--]]

--]] Services
local players = game:GetService('Players')
local https = game:GetService('HttpService')
local userInputService = game:GetService('UserInputService')
local runService = game:GetService('RunService')

--]] Modules
--]] Settings
--]] Constants
local computerModel = workspace.Gameplay:WaitForChild('Computer') :: Model
repeat task.wait(0) until computerModel.PrimaryPart
local mainPart = computerModel.PrimaryPart
local prompt = mainPart:WaitForChild('Prompt') :: ProximityPrompt

--> Index player
local player = players.LocalPlayer
local playerUi = player.PlayerGui

local computerUi = playerUi:WaitForChild('ComputerGUI') :: ScreenGui

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild('Humanoid') :: Humanoid

--]] Variables
local currentUi

--]] Functions
function openUi()
    if currentUi then
        currentUi:Destroy() end

    local conn = runService.Heartbeat:Connect(function(deltaTime)
        userInputService.MouseBehavior = Enum.MouseBehavior.Default
    end)

    currentUi = computerUi:Clone()
    currentUi.Main.Background.ePay.MouseButton1Down:Connect(function()
        currentUi.Main.ePay.Visible = true
    end)

    currentUi.Main.ePay.Visible = false

    currentUi.Name = `computer.{https:GenerateGUID(false)}`
    currentUi.Parent = playerUi
    currentUi.Enabled = true

    return function()
        conn:Disconnect()
        conn = nil

        userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
end

function closeUi()
    if currentUi then
        currentUi:Destroy()
    end
end

--]] Script
prompt.Triggered:Connect(function() --> Open UI
    local cleanup = openUi()
    humanoid.Jumping:Once(function()
        cleanup()
        closeUi()
    end) --> Close UI
end)