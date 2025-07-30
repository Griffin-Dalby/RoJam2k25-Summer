--[[

    Scrap Machine Client Logic

    Griffin Dalby
    2025.07.29

    This script will provide logic for the scrap machine

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')
local players = game:GetService('Players')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache
local services = sawdust.services
local networking = sawdust.core.networking

--]] Settings
--]] Constants
--> Cache groups
local physItems = caching.findCache('physItems')

--> Networking channels
local worldChannel = networking.getChannel('world')
local gameChannel = networking.getChannel('game')

--> Index player
local player = players.LocalPlayer
local playerUi = player.PlayerGui:WaitForChild('UI')
local keybindUi = playerUi.Keybinds

--]] Variables
local scrapMachine

--]] Functions
function findScrapMachine()
    scrapMachine = workspace.Gameplay:FindFirstChild('ScrapMachine') end

--]] Logic
workspace.Gameplay:WaitForChild('ScrapMachine'):WaitForChild('hitbox')
findScrapMachine()

local frameCounter = 0
runService.Heartbeat:Connect(function(deltaTime)
    frameCounter=(frameCounter+1)%3
    if frameCounter~=0 then return end
    if not scrapMachine then return end
    
    local olapParams = OverlapParams.new()
    olapParams.FilterDescendantsInstances = {scrapMachine}

    local hitbox = scrapMachine.hitbox :: BasePart
    local partsInBounds = workspace:GetPartsInPart(hitbox, olapParams)

    for _, part: BasePart in pairs(partsInBounds) do
        local topLayer = part:FindFirstAncestorWhichIsA('Model')
        local targetItem = (topLayer and topLayer:GetAttribute('itemUuid')) and topLayer or (part:GetAttribute('itemUuid') and part or nil)
        if not targetItem then continue end

        local physItem = physItems:getValue(targetItem:GetAttribute('itemUuid'))
        if not physItem then continue end
        
        --> Scrap it
        local success
        worldChannel.scrapMachine:with()
            :headers('use')
            :data(physItem.__itemUuid)
            :invoke()
                :andThen(function(req)
                    success = req[1]
                end)
                :catch(function(err)
                    success = false
                end)

        --> Drop it
        physItem:drop()
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

        repeat task.wait(0) until success~=nil
        if not success then
            warn(`[{script.Name}] Failed to scrap item! (UUID8: {physItem.__itemUuid:sub(1,8)})`)
            return end

    end
end)
