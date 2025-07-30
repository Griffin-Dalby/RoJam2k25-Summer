--[[

    Faucet Controller

    Griffin Dalby
    2025.07.27

    This script will control the faucet and allows the player to turn it
    on and off.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)

local networking = sawdust.core.networking
local caching = sawdust.core.cache

--]] Settings
--]] Constants
local faucetModel = workspace.Gameplay:WaitForChild('WaterFaucet') :: Model
repeat task.wait(0) until faucetModel.PrimaryPart
local mainPart = faucetModel.PrimaryPart
local prompt = mainPart:WaitForChild('Prompt') :: ProximityPrompt

--> Cache groups
local gameCache = caching.findCache('game')
gameCache:setValue('faucetOpen', false)

local physItemCache = caching.findCache('physItems')
local physItemDrags = caching.findCache('physItems.dragging')

--> Networking channels
local worldChannel = networking.getChannel('world')

--]] Variables
--]] Functions
--]] Script
local cooldown = false

--[[ HANDLE FAUCET ]]--
prompt.Triggered:Connect(function(playerWhoTriggered)
    --> Debounce
    if cooldown then return end
    cooldown = true
    task.delay(1, function()
        cooldown = false end)

    --> Trigger
    local isOpen = gameCache:getValue('faucetOpen')
    for _, emitter: ParticleEmitter in pairs(faucetModel:GetDescendants()) do --> Emitters
        if not emitter:IsA('ParticleEmitter') then continue end
        emitter.Enabled = not isOpen
    end

    if gameCache:getValue('faucetOpen') then
        --> Close faucet
        
    else
        --> Open faucet
    end

    worldChannel.faucet:with()
        :broadcastGlobally()
        :headers(not isOpen and 'opened' or 'closed')
        :data(playerWhoTriggered.UserId)
        :fire()

    gameCache:setValue('faucetOpen', not isOpen) --> Register
end)

--[[ LISTEN ON FAUCET ]]--
local wetCooldowns = {}
local headerHandlers = {
    ['wet'] = function(caller: Player, itemUuid: string)
        if wetCooldowns[caller] then return end
        wetCooldowns[caller] = true
        task.delay(.035, function()
            wetCooldowns[caller] = nil
        end)

        local foundItem = physItemCache:getValue(itemUuid)
        assert(foundItem, `Player ({caller.Name}.{caller.UserId}) attempted to wet an invalid item!`)

        local physItemDrag = physItemDrags:getValue(caller)
        assert(physItemDrag, `Player ({caller.Name}.{caller.UserId}) attempted to wet an item while holding nothing!`)
        assert(physItemDrag==itemUuid, `Player ({caller.Name}.{caller.UserId}) attempted to wet an item while holding a different item!`)

        foundItem:setWetness(foundItem.wetness+2)
    end
}

worldChannel.faucet:handle(function(req, res)
    local caller = players:GetPlayerByUserId(req.caller)
    assert(headerHandlers[req.headers], `Player ({caller.Name}.{caller.UserId}) called invalid header "{req.headers}"!`)

    res.setHeaders(req.headers)
    res.setData(headerHandlers[req.headers](caller, unpack(req.data)))
end)