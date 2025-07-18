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
local builder = sawdust.builder
local cdn = sawdust.core.cdn

local highlighter = require(script.highlighter)

--]] Settings
local itemDropDistance = 10

local keybinds = {
    ['grab'] = {Enum.KeyCode.F, Enum.KeyCode.ButtonY},
    ['drop'] = {Enum.KeyCode.Q, Enum.KeyCode.ButtonX},
    ['use'] = {Enum.KeyCode.E, Enum.KeyCode.ButtonR2}
}

--]] Constants
--> Index player
local player = players.LocalPlayer
local camera = workspace.CurrentCamera

--> CDN Providers
local itemProvider = cdn.getProvider('item')

--> Networking channels
local gameChannel = networking.getChannel('game')

--]] Variables
local availableItems = {}
local targetedItem = nil

--]] Functions
--]] Service

return builder.new('grab')
    :dependsOn('camera')
    :init(function(self, deps)
        --[[ CREATE FIELDS ]]--
        self.grabbing = false

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
            local objects = workspace.Objects:GetChildren()

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
        local function drop()
            if not self.grabbing then return end

             --> UI
            keybindUi.Drop.Visible = false
            keybindUi.Use.Visible = false

            --> Drop item & replicate
            local goalPart = workspace.Temp:FindFirstChild('dragGoalPart') --> Cleanup goal part
            if goalPart then
                goalPart:Destroy() end

            local searchItem = targetedItem --> Cleanup item
            if targetedItem:IsA('Model') then
                searchItem = targetedItem.PrimaryPart end
            for _, instance in pairs(searchItem:GetChildren()) do
                if instance:IsA('AlignPosition') then
                    instance:Destroy() end
                if instance:IsA('AlignOrientation') then
                    instance:Destroy() end
                if instance:IsA('Attachment') and instance.Name == 'itemAttach' then
                    instance:Destroy() end
            end

            if self.runtimes.hold then
                self.runtimes.hold:Disconnect()
                self.runtimes.hold=nil
            end

            targetedItem = nil
            self.grabbing = false
        end

        local function grab()
            if self.grabbing or not targetedItem then return end

            --> Check in w/ server
            local itemUuid = targetedItem:GetAttribute('itemUuid')

            local success, errorCaught = false, false
            gameChannel.physItem:with()
                :headers('grab')
                :data(itemUuid)
                :invoke()
                    :andThen(function(req)
                        local headers = req.headers
                        if headers == 'rejected' then
                            errorCaught = true
                            warn(`[{script.Name}] Server rejected grab item request!`)
                            return end
                        
                        success = true
                    end)
                    :catch(function(err)
                        errorCaught = true

                        warn(`[{script.Name}] Server rejected grab item request!`)
                        if err then
                            warn(`[{script.Name}] An error was provided: {err}`) end
                    end)

            repeat task.wait(0) until success or errorCaught 
            if errorCaught then
                return end

            --> Enable grabbing & clear highlights
            self.grabbing = true
            for _, highlighter: highlighter.ItemHighlighter in pairs(availableItems) do
                highlighter:discard() end; table.clear(availableItems)
            
            --> UI
            keybindUi.Grab.Visible = false
            keybindUi.Use.Visible = true
            keybindUi.Drop.Visible = true

            --> Create attachments
            local camera = workspace.CurrentCamera
            local goalPart = Instance.new('Part')
            goalPart.Size = Vector3.zero
            goalPart.Transparency = 1
            goalPart.Anchored, goalPart.CanCollide = true, false
            goalPart.Name = 'dragGoalPart'

            local itemAttachment, goalAttachment = Instance.new('Attachment'), Instance.new('Attachment')
            itemAttachment.Name, goalAttachment.Name = 'itemAttach', 'goalAttach'
            itemAttachment.Parent, goalAttachment.Parent =
                targetedItem:IsA('Model') and targetedItem.PrimaryPart or targetedItem, goalPart
            
            goalPart.Parent = workspace.Temp

            local alignPos = Instance.new('AlignPosition')
            alignPos.MaxForce = 500000
            alignPos.MaxVelocity = 100
            alignPos.Responsiveness = 100
            alignPos.RigidityEnabled = false
            alignPos.Attachment0, alignPos.Attachment1 = itemAttachment, goalAttachment
            alignPos.Parent = itemAttachment.Parent

            local alignOri = Instance.new('AlignOrientation')
            alignOri.MaxTorque = 500000
            alignOri.MaxAngularVelocity = 10000
            alignOri.Responsiveness = 10000
            alignOri.Attachment0, alignOri.Attachment1 = itemAttachment, goalAttachment
            alignOri.Parent = itemAttachment.Parent

            local timeSinceLastUpdate = 100
            self.runtimes.hold = runService.RenderStepped:Connect(function(dT)
                if not self.grabbing then return end

                --> Update attachment
                local camCf = camera.CFrame
                local goalPosition = camCf.Position + camCf.LookVector*4
                
                goalAttachment.WorldCFrame = CFrame.lookAt(
                    goalPosition,
                    camCf.Position,
                    Vector3.yAxis)

                --> Check should drop
                if (goalAttachment.WorldCFrame.Position-itemAttachment.WorldCFrame.Position).Magnitude>=itemDropDistance then
                    drop(); return end

                --> Check if should update server
                if timeSinceLastUpdate>.2 then
                    timeSinceLastUpdate = 0
                    gameChannel.physItem:with()
                        :headers('dragUpdate')
                        :data(goalPosition)
                        :fire()
                end
            end)

        end

        contextActionService:BindAction('grab', function(_, inputState)
            if inputState ~= Enum.UserInputState.End then return end
            grab()
        end, false, unpack(keybinds.grab))

        contextActionService:BindAction('drop', function(_, inputState)
            if inputState ~= Enum.UserInputState.Begin then return end
            drop()
        end, false, unpack(keybinds.drop))

        contextActionService:BindAction('use', function()
            
        end, false, unpack(keybinds.use))
    end)