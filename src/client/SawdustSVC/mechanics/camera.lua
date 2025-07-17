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
    turnSmoothing = .25,
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
            --> Create viewmodel
            self.viewmodel = gameCDN:getAsset('viewmodel'):Clone()
            self.viewmodel.Parent = workspace.CurrentCamera
        end)

        :method('loadAnimation', function(self, animationId: number|Animation)
            local humanoid = self.viewmodel:WaitForChild('Humanoid') :: Humanoid
            local animator = humanoid and humanoid:WaitForChild('Animator') :: Animator
            
            if not humanoid then
                warn(`[{script.Name}] No humanoid found in viewmodel.`)
                return end

            local animation = if typeof(animationId) == 'number' then nil else animationId
            if animation == nil then
                animation = Instance.new('Animation')
                animation.AnimationId = `http://www.roblox.com/asset/?id={animationId}` end

            print('loading animation:', animation.AnimationId)
            return animator:LoadAnimation(animation)
        end)
        :start(function(self, deps)
            coroutine.wrap(function()
                --> Viewmodel 
                local character = players.LocalPlayer.Character or players.LocalPlayer.CharacterAdded:Wait()
                local humanoid = character:WaitForChild("Humanoid") :: Humanoid

                if character and character.PrimaryPart then
                    self.viewmodel:PivotTo(character.PrimaryPart.CFrame) end
                
                self.viewmodelConnections = {}
                self.viewmodelConnections.renderStepped = runService.RenderStepped:Connect(function()
                    if character and character.PrimaryPart then
                        local origPos = character.PrimaryPart.CFrame
                        local backCFrame = origPos:ToWorldSpace(viewmodelSettings.modelOffset)
                        
                        local origDirection = self.viewmodel:GetPivot()
                        local lookVector = origDirection.LookVector

                        self.viewmodel:PivotTo(CFrame.new(
                            backCFrame.Position,
                            backCFrame.Position + lookVector ))
                        task.wait(0)

                        self.viewmodel:PivotTo(origDirection:Lerp(backCFrame, 
                            (lookVector-backCFrame.LookVector).Magnitude * viewmodelSettings.turnSmoothing))
                    end
                end)
            
                local animations = {
                    walk = self.loadAnimation(507777826),
                    jump = self.loadAnimation(507765000),
                    fall = self.loadAnimation(507767968),
                    idle = self.loadAnimation(507766666),
                } :: {[string]: AnimationTrack}

                local function safePlay(aName: string)
                    for name, track in pairs(animations) do
                        if name == aName then
                            if not track.IsPlaying then
                                track:Play()
                            end
                        else
                            if track.IsPlaying then
                                track:Stop()
                            end
                        end
                    end
                end

                self.viewmodelConnections.movement = humanoid.Running:Connect(function(speed)
                    if speed > 0 then
                        safePlay('walk')
                    else
                        safePlay('idle')
                    end
                end)

                self.viewmodelConnections.state = humanoid.StateChanged:Connect(function(state)
                    if state == Enum.HumanoidStateType.Jumping then
                        safePlay('jump')
                    elseif state == Enum.HumanoidStateType.Freefall then
                        safePlay('fall')
                    else
                        if not animations.walk.IsPlaying and not animations.idle.IsPlaying then
                            safePlay('idle')
                        end
                    end
                end)

                --> Clothing & Color
                local character = players.LocalPlayer.Character or players.LocalPlayer.CharacterAdded:Wait()
                local shirt = character:WaitForChild("Shirt")
                local pants = character:WaitForChild("Pants")
                local bodyColors = character:WaitForChild("Body Colors")

                shirt:Clone().Parent = self.viewmodel
                pants:Clone().Parent = self.viewmodel
                if bodyColors then
                    local newBodyColors = Instance.new("BodyColors")
                    newBodyColors.HeadColor = bodyColors.HeadColor
                    newBodyColors.LeftArmColor = bodyColors.LeftArmColor
                    newBodyColors.RightArmColor = bodyColors.RightArmColor
                    newBodyColors.LeftLegColor = bodyColors.LeftLegColor
                    newBodyColors.RightLegColor = bodyColors.RightLegColor
                    newBodyColors.TorsoColor = bodyColors.TorsoColor
                    newBodyColors.Parent = self.viewmodel
                end
            end)()
        end)