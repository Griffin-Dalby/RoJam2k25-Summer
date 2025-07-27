--[[

    Computer Controller

    Griffin Dalby
    2025.07.27

    This script will control the computer and give the player access
    to the shop.

--]]

--]] Services
local players = game:GetService('Players')

--]] Modules
--]] Settings
--]] Constants
local computerModel = workspace.Gameplay:WaitForChild('Computer') :: Model
repeat task.wait(0) until computerModel.PrimaryPart
local mainPart = computerModel.PrimaryPart
local prompt = mainPart:WaitForChild('Prompt') :: ProximityPrompt

--]] Variables
--]] Functions
--]] Script
prompt.Triggered:Connect(function() --> Open UI
    
end)