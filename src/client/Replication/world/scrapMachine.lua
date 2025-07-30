--[[

    world.scrapMachine listener

    Griffin Dalby
    2025.07.30 (4:49 AM MST)

    This module will provide a listener for the scrap machine event,
    mostly handing VFX.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)

--]] Settings
--]] Constants
local scrapMachine = workspace.Gameplay:WaitForChild('ScrapMachine')

--]] Variables
--]] Functions
--]] Listener
local headerHandlers = {
    ['burn'] = function()
        for _, part in pairs{scrapMachine.FXPart, scrapMachine.Cube} do
            for _, emitter in pairs(part:GetDescendants()) do
                if not emitter:IsA('ParticleEmitter') then continue end

                local emitCount = emitter:GetAttribute('EmitCount')
                if not emitCount then continue end

                emitter:Emit(emitCount)
            end
        end
    end
}

return function (req)
    headerHandlers[req.headers](unpack(req.data))
end