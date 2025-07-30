--[[

    game.scraps listener
    
    Griffin Dalby
    2025.07.29

    This listener will update the player's scraps

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache

--]] Settings
--]] Constants
--> Index player
local player = players.LocalPlayer
local playerUi = player.PlayerGui:WaitForChild('UI')
local statsUi = playerUi:WaitForChild('Stats')

--> Caching groups
local gameCache = caching.findCache('game')

--]] Variables
--]] Functions
--]] Listener
local headerHandlers = {
    ['set'] = function(newScraps: number)
        gameCache:setValue('scraps', newScraps)
        statsUi.Scraps.Text = `<font color="rgb(0,200,0)">{newScraps}</font> S$`
    end
}

return function (req)
    headerHandlers[req.headers](unpack(req.data))
end