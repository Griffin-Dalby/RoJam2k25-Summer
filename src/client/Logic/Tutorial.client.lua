--[[

    Tutorial Script

    Griffin Dalby
    2025.07.30

    This script will show and walk the player through the tutorial.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local starterGui = game:GetService('StarterGui')
local players = game:GetService('Players')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache

--]] Settings
--]] Constants
--> Caching groups
local tutorialCache = caching.findCache('tutorial')

--]] Variables
--]] Functions
--]] Script

starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

local playerUi = players.LocalPlayer.PlayerGui:WaitForChild('UI')
local tutorial = playerUi:WaitForChild('Tutorial')

local phrases = {
    'Welcome to the garage! You\'re the last mechanic out here.',
    'Vehicles will start coming in with problems, parts overheating, on fire, or just being plain dirty.',
    'You can use the correlating tools to fix engine parts, or go to the back where new parts spawn and use one of those!',
    'To start you off, go grab a sponge, turn on the water faucet, and wait for the first car to come in!',
    'I know you can make it until the convoy finds you, until then I wish you the best!'
}

tutorial.Visible = true
for i, phrase: string in pairs(phrases) do
    if i==4 then
        local faucet = workspace.Gameplay.WaterFaucet

        faucet.Highlight.Enabled = true
        faucet.PrimaryPart.Prompt.Triggered:Once(function()
            faucet.Highlight.Enabled = false end)
    end

    tutorial.Label.Text = phrase
    task.wait(5)
end

tutorial.Visible = false