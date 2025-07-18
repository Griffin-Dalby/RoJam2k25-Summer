--[[

    Camera Mechanics Service

    Griffin Dalby
    2025.07.16

    This service will handle first person camera mechanics, as well as
    the viewmodel.

--]]

--]] Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpsService = game:GetService("HttpService")
local runService = game:GetService("RunService")
local players = game:GetService('Players')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local cdn = sawdust.core.cdn

--]] Settings
--> Viewmodel Settings
local viewmodelSettings = {
    turnSmoothing = .5,
    modelOffset   = CFrame.new(0, 0, 0.2), -- Offset from the camera position
}

local robloxProxy = "https://robloxdevforumproxy.glitch.me/users/inventory/list-json?assetTypeId=11&cursor=&itemsPerPage=100&pageNumber=%25x&sortOrder=Desc&userId="
local assetIds = {2,11} --> T-shirts, shirts

--]] Constants
--> CDN Providers
local gameCDN = cdn.getProvider('game')

--]] Variables
--]] Functions
--]] Camera Service

return sawdust.builder.new('camera')
        :init(function(self, deps)
            
        end)

        :start(function(self, deps)
            
        end)