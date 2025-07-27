--[[

    world.faucet listener

    Griffin Dalby
    2025.07.27

    This module will provide a listener for the faucet event,
    allowing the player to take advantage of the faucet's functionality.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')
local players = game:GetService('Players')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local networking = sawdust.core.networking

--]] Settings
--]] Constants
local runtimes = {}

local faucet = workspace.Gameplay.WaterFaucet :: Model
local faucetTip = faucet.PrimaryPart.Attachment :: Attachment

local waterCastParams = RaycastParams.new()
waterCastParams.FilterDescendantsInstances = {workspace.Gameplay}

--> Networking channels
local worldChannel = networking.getChannel('world')

--]] Variables
--]] Functions
--]] Listener
local headerHandlers = {
    ['opened'] = function(playerWhoTriggered: number)
        playerWhoTriggered = players:GetPlayerByUserId(playerWhoTriggered)

        if runtimes.water then
            runtimes.water:Disconnect()
            runtimes.water=nil
        end

        local frameCounter = 0
        runtimes.water = runService.Heartbeat:Connect(function()
            frameCounter=(frameCounter+1)%8
            if frameCounter~=0 then return end

            local raycast = workspace:Raycast(
                faucetTip.WorldCFrame.Position,
                -Vector3.yAxis*5,
                waterCastParams
            ) :: RaycastResult
            if not raycast then return end
            if raycast then
                local instance = raycast.Instance
                local uuid, id = instance:GetAttribute('itemUuid'), instance:GetAttribute('itemId')

                worldChannel.faucet:with()
                    :headers('wet')
                    :data(uuid)
                    :fire()
            end
        end)
    end,

    ['closed'] = function(playerWhoTriggered: number)
        playerWhoTriggered = players:GetPlayerByUserId(playerWhoTriggered)

        if runtimes.water then
            runtimes.water:Disconnect()
            runtimes.water=nil
        end
    end
}

return function (req)
    headerHandlers[req.headers](unpack(req.data))
end