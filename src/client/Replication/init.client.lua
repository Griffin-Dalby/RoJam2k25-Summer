--[[

    Client Replication

    Griffin Dalby
    2025.07.16

    This script will handle client-side replication for the game.

    There are folders with modules inside corresponding to different
    channels and events to hook into and replicate.

--]]

--]] Services
local replicatedStorage = game:GetService("ReplicatedStorage")

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local networking = sawdust.core.networking

--]] Settings
--]] Constants
--]] Variables
--]] Functions
--]] Script
for _, channel: Folder in pairs(script:GetChildren()) do
    if not channel:IsA("Folder") then continue end
    local thisChannel = networking.getChannel(channel.Name)

    for _, listener: ModuleScript in pairs(channel:GetChildren()) do
        if not listener:IsA("ModuleScript") then continue end

        local listenerCall = require(listener)
        thisChannel[listener.Name]:handle(listenerCall)
    end
end