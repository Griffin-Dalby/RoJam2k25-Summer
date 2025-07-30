--[[

    Computer Server Logic

    Griffin Dalby
    2025.07.29

    This script will provide logic for the computer on the server
    side.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')

--]] Modules
local physItem = require(replicatedStorage.Shared.PhysItem)
local sawdust = require(replicatedStorage.Sawdust)

local networking = sawdust.core.networking
local caching = sawdust.core.cache
local cdn = sawdust.core.cdn

--]] Settings
--]] Constants
local rng = Random.new()

--> Networking channels
local gameChannel = networking.getChannel('game')

--> Cache groups
local gameCache = caching.findCache('game')

--> CDN providers
local partCDN = cdn.getProvider('part')

--]] Variables
--]] Functions
--]] Computer

local headerHandlers = {
    ['purchase'] = function(caller: Player, itemId: string, variationId: string)
        local foundAsset = partCDN:getAsset(`{itemId}.{variationId}`)
        assert(foundAsset, `Failed to find asset w/ id "{itemId}.{variationId}"!`)

        local scraps = gameCache:getValue('scraps')
        local price = foundAsset.behavior.buyPrice
        
        if scraps >= price then --> Purchase
            gameCache:setValue('scraps', scraps-price)
            gameChannel.scraps:with()
                :broadcastGlobally()
                :headers('set')
                :data(gameCache:getValue('scraps'))
                :fire()

            local shippingArea = workspace.Gameplay.ShippingArea :: Part
            local pos, size = shippingArea.Position, shippingArea.Size

            local newItem = physItem.new(`{itemId}.{variationId}`)
            newItem:putItem({
                pos.X + rng:NextNumber(-size.X/2, size.X/2),
                pos.Y + 3,
                pos.Z + rng:NextNumber(-size.X/2, size.X/2)
            }, {0, math.random(-360, 360), 0})

            return true
        else --> Too broke
            return 'funds'
        end
    end
}

gameChannel.computer:handle(function(req, res)
    local caller = players:GetPlayerByUserId(req.caller)
    local callerTag = `{caller.Name}.{caller.UserId}`

    if not headerHandlers[req.headers] then
        warn(`[{script.Name}] Player ({callerTag}) provided incorrect header "{req.headers}"!`)
        return end

    res.setHeaders(req.headers)
    res.setData(headerHandlers[req.headers](caller, unpack(req.data)))
    res.send()
end)