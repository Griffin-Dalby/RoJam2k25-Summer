--[[

    Client Sawdust Service Manager

    Griffin Dalby
    2025.07.16

--]]

--]] Services
local replicatedStorage = game:GetService("ReplicatedStorage")

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)

--]] Settings
--]] Constants
--]] Variables
--]] Functions

--]] Register Services
for _, serviceContainer: Folder in pairs(script:GetChildren()) do
    if not serviceContainer:IsA("Folder") then continue end

    for _, serviceModule: ModuleScript in pairs(serviceContainer:GetChildren()) do
        if not serviceModule:IsA("ModuleScript") then continue end
        sawdust.services:register(require(serviceModule))
    end
end

--]] Resolve & Start Services
sawdust.services:resolveAll()
sawdust.services:startAll()