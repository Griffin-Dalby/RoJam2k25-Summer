--[[

    Grab Mechanics Service

    Griffin Dalby
    2025.07.17

    This service will provide grabbing mechanics for physical objects.

--]]

--]] Services
local contextActionService = game:GetService('ContextActionService')
local replicatedStorage = game:GetService('ReplicatedStorage')
local userInputService = game:GetService('UserInputService')
local runService = game:GetService('RunService')
local players = game:GetService('Players')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local networking = sawdust.core.networking
local caching = sawdust.core.cache
local builder = sawdust.builder
local cdn = sawdust.core.cdn

local highlighter = require(script.highlighter)

--]] Settings
local itemDropDistance = 10

local keybinds = {
    ['grab'] = {Enum.KeyCode.E, Enum.KeyCode.ButtonX},
    ['pickUp'] = {Enum.KeyCode.F, Enum.KeyCode.ButtonY},

    ['drop'] = {Enum.KeyCode.Q, Enum.KeyCode.ButtonB},
    ['use'] = {Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2}
}

--]] Constants
--> Index player
local player = players.LocalPlayer
local camera = workspace.CurrentCamera

--> CDN providers
local itemProvider = cdn.getProvider('item')

--> Networking channels
local gameChannel = networking.getChannel('game')

--> Caches
local physItems = caching.findCache('physItems')

--]] Variables
local availableItems = {}
local targetedItem = nil
local targetedPItem = nil

--]] Functions
--]] Service

return builder.new('grab')
    :init(function(self, deps)
        --[[ CREATE FIELDS ]]--
        self.grabbing = false
        self.physDragging = false

        self.grabLength = 4
    end)

    :start(function(self, deps)
        --[[ CHARACTER ]]--
        local character = player.Character or player.CharacterAdded:Wait()
        local rootPart = character:WaitForChild('HumanoidRootPart')

        local playerUi = player.PlayerGui:WaitForChild('UI') :: ScreenGui
        local keybindUi = playerUi:WaitForChild('Keybinds')   :: Frame

        --[[ TARGETER ]]--
        self.runtimes = {}
        self.runtimes.targeter = runService.Heartbeat:Connect(function()
            if self.grabbing then return end

            --> Get viewport size
            local viewCenter = camera.ViewportSize/2

            --> Locate closest
            local camPos = camera.CFrame.Position
            local objects = workspace.__objects:GetChildren()

            local closest = {math.huge}
            local updatedAvailableItems = {}
            for _, item: BasePart in pairs(objects) do
                local itemPosition = item:IsA('Model') and item:GetPivot().Position or item.Position

                local posDepth, onScreen = camera:WorldToViewportPoint(itemPosition)
                if not onScreen then continue end

                local screenPos = Vector2.new(posDepth.X, posDepth.Y)

                local screenDist, playerDist = 
                    (viewCenter-screenPos).Magnitude,
                    (rootPart.CFrame.Position-itemPosition).Magnitude
                    
                local screenInRange, playerInRange = 
                    screenDist < 300,
                    playerDist < 15

                local available = screenInRange and playerInRange
                if available then
                    updatedAvailableItems[item] = screenDist+playerDist end
                if available and closest[1] > screenDist then
                    closest = {screenDist, item} end
            end
        
            if not closest[2] then
                keybindUi.Grab.Visible = false
                return end
                
            if not keybindUi.Visible or targetedItem~=closest[2] then
                local asset = itemProvider:getAsset(closest[2]:GetAttribute('itemId'))
                keybindUi.Grab.Bind.Action.Text = `Grab {asset.style.name}`
                keybindUi.PickUp.Bind.Action.Text = `Pocket {asset.style.name}`

                keybindUi.Visible = true
                keybindUi.Grab.Visible = true
            end
            targetedItem = closest[2]

            --> Highlight
            local maxDist = 0
            for _, dist in pairs(updatedAvailableItems) do
                if dist > maxDist then maxDist = dist end end

            for item: Instance, highlight: highlighter.ItemHighlighter in pairs(availableItems) do --> Update existing highlight
                local itemTotalDist = updatedAvailableItems[item]
                if itemTotalDist then
                    --> Set state
                    if item==closest[2] then
                        highlight:setState('focused')
                    else
                        highlight:setState('available')
                    end

                    --> Normalize brightness
                    local normalized = 1-(itemTotalDist/maxDist)
                    highlight:multiply(normalized)
                else
                    --> Delete highlight
                    highlight:discard()
                    availableItems[item] = nil
                end
            end

            for item: Instance, itemTotalDist: number in pairs(updatedAvailableItems) do
                if not availableItems[item] then
                    --> Add highlight
                    local newHighlight = highlighter.new(item)
                    availableItems[item] = newHighlight
                end
            end
        end)

        --[[ INPUTS (PC/CONSOLE) ]]--
        local inputDebounce = false

        local function drop(external: boolean)
            if not self.grabbing then return end

            --> Check in w/ server
            inputDebounce = true
            local success, errorCaught = false, false
            gameChannel.physItem:with()
                :headers('drop')
                :data{
                    Vector3.new(unpack(targetedPItem:getTransform().position)),
                    targetedPItem:getVelocity()}
                :invoke()
                    :andThen(function(req)
                        if req[1]==false then
                            errorCaught = true
                            warn(`[{script.Name}] Server rejected drop item request!`)
                            return 
                        end
                        
                        success = true
                    end)
                    :catch(function(err)
                        errorCaught = true

                        warn(`[{script.Name}] Server rejected drop item request!`)
                        if err then
                            warn(`[{script.Name}] An error was provided: {err}`) end
                    end)

            repeat task.wait(0) until success or errorCaught 
            inputDebounce = false
            if errorCaught then
                return end

            --> UI
            keybindUi.PickUp.Visible = false
            keybindUi.Drop.Visible = false
            keybindUi.Use.Visible = false

            if not external and targetedPItem then
                targetedPItem:drop()
                targetedPItem = nil
            end
            
            self.grabbing = false
        end

        local function interaction(action: 'grab'|'pickUp')
            if inputDebounce then return end
            if (action=='grab' and self.grabbing)
            or (action=='pickUp' and not self.grabbing) then return end

            if not targetedItem then return end

            --> Check in w/ server
            local itemUuid = targetedItem:GetAttribute('itemUuid')
            inputDebounce = true

            local success, errorCaught = false, false
            gameChannel.physItem:with()
                :timeout(2)
                :headers(action)
                :data{itemUuid}
                :invoke()
                    :andThen(function(req)
                        if not req[1] then
                            errorCaught = true
                            warn(`[{script.Name}] Server rejected {action} request!`)
                            return end
                        
                        success = true
                    end)
                    :catch(function(err)
                        errorCaught = true

                        warn(`[{script.Name}] Server rejected {action} request!`)
                        if err then
                            warn(`[{script.Name}] An error was provided: {err}`) end
                    end)

            repeat task.wait(0) until success or errorCaught
            inputDebounce = false
            if errorCaught then
                return end

            --> Enable grabbing & clear highlights
            for _, highlighter: highlighter.ItemHighlighter in pairs(availableItems) do
                highlighter:discard() end; table.clear(availableItems)
            
            --> UI
            keybindUi.Grab.Visible = false

            local foundItem = physItems:getValue(itemUuid)
            assert(foundItem, `While attempting to {action}, the targeted item isn't in the cache.`)

            targetedPItem = foundItem
            
            if action=='pickUp' then
                keybindUi.PickUp.Visible = false
                keybindUi.Use.Visible = false
                keybindUi.Drop.Visible = false

                foundItem:destroy()
                self.grabbing = false
                targetedPItem = nil
                targetedItem = nil
            else
                self.grabbing = true

                foundItem:grab(player, drop)
                keybindUi.PickUp.Visible = true
                keybindUi.Use.Visible = true
                keybindUi.Drop.Visible = true
            end
        end

        contextActionService:BindAction('grab', function(_, inputState)
            if inputState ~= Enum.UserInputState.End then return end
            interaction('grab')
        end, false, unpack(keybinds.grab))
        contextActionService:BindAction('pickUp', function(_, inputState)
            if inputState ~= Enum.UserInputState.End then return end
            interaction('pickUp')
        end, false, unpack(keybinds.pickUp))

        contextActionService:BindAction('drop', function(_, inputState)
            if inputState ~= Enum.UserInputState.Begin then return end
            drop()
        end, false, unpack(keybinds.drop))

        contextActionService:BindAction('use', function()
            
        end, false, unpack(keybinds.use))
    end)