--[[

    Computer Controller

    Griffin Dalby
    2025.07.27

    This script will control the computer and give the player access
    to the shop.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')
local https = game:GetService('HttpService')
local userInputService = game:GetService('UserInputService')
local runService = game:GetService('RunService')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)
local networking = sawdust.core.networking
local cdn = sawdust.core.cdn

--]] Settings
local sellerNames = {
    engine = {
        [1] = {
            "Rusty's Engines", "Old Joe's Garage", "Salvage Sam", "Grime Gear Co", "Worn Works",
            "Scrap n' Spin", "Backfire Bill", "Cheap Cylinders", "Muffler Mike", "Busted Blocks"
        },
        [2] = {
            "Crankshaft Co.", "Turbo Tom", "Midtown Mechanics", "Gearhead Greg", "Precision Pistons",
            "Engine Emporium", "VroomTech", "PowerCore Motors", "V-Tuned Garage", "HighOctane Hut"
        },
        [3] = {
            "NovaDrive", "Titan Motors", "Aether Dynamics", "Quantum Crank", "Overdrive Labs",
            "TorqueForge", "Ascend Autos", "RevCore Systems", "PrismTech", "Peak Performance"
        }
    },

    battery = {
        [1] = {
            "Zappy Zack's", "Shock Stop", "DeadCell Depot", "Buzz Batteries", "LowVolt Larry",
            "Jolt Junkyard", "Batteries 4 Broke", "Flicker Power", "Charge 'n' Chuck", "Rusty Sparks"
        },
        [2] = {
            "Amped Up Supply", "VoltVault", "Current King", "BrightCell Co", "MidVolt Market",
            "ChargeCore Central", "Surge Station", "WattWorks", "EcoCharge", "PowerPile Ltd."
        },
        [3] = {
            "IonFlux", "NovaCell", "NeonCharge", "PulseGrid", "HyperVolt Inc.",
            "Arcadium Energy", "CryoCharge Labs", "Helios Cells", "Vortex Battery", "CorePulse"
        }
    },

    filter = {
        [1] = {
            "Dusty's Filters", "Clogged Carl", "GrimeGuard", "Old Air Outfitters", "Choke Point Co.",
            "Breathe EZ", "Filter Shack", "Busted Breeze", "Musty Mike's", "HalfClean Air"
        },
        [2] = {
            "CleanFlow Supply", "BreatheRight Inc.", "AirPure Works", "FreshLine Filters", "VentSure",
            "Windway Co.", "Filter Force", "MidAir Mechanics", "Purify Pro", "ClearPath Parts"
        },
        [3] = {
            "ZeroDust Labs", "HyperBreathe", "AeroNova", "NanoVent", "Stratus Filtration",
            "LuftWorks", "SkyFlow Systems", "TrueClean Filters", "Atmos AirTech", "ClarityCore"
        }
    },

    reservoir = {
        [1] = {
            "Drip n’ Rust", "Coolant Carl", "Leaky’s Lot", "Tank Trash", "Salvage Fluid Systems",
            "OldFlow Co.", "Radiator Rick", "Fluid Junkies", "Overflow Only", "Puddle Provisions"
        },
        [2] = {
            "FlowRight Supply", "TankLine Co.", "CoolCore Central", "Reservoir Ready", "MidTemp Mechanics",
            "ChillStream", "HydroPoint", "AquaLoop Ltd.", "FluidForce", "CoreCool Systems"
        },
        [3] = {
            "CryoStream", "GlacierCool", "NovaReserv", "ThermoFlux", "AetherFlow",
            "LiquidTech", "FrostPoint Dynamics", "QuantumCool", "VantaCool Systems", "CryoCore Labs"
        }
    }
}

local tierTranslator = {
    [1] = {'t1', 'v4'},
    [2] = {'t2', 'v6'},
    [3] = {'t3', 'v8'}
}

--]] Constants
local computerModel = workspace.Gameplay:WaitForChild('Computer') :: Model
repeat task.wait(0) until computerModel.PrimaryPart
local mainPart = computerModel.PrimaryPart
local prompt = mainPart:WaitForChild('Prompt') :: ProximityPrompt

--> Networking channels
local gameChannel = networking.getChannel('game')

--> CDN providers
local partCDN, itemCDN = cdn.getProvider('part'), cdn.getProvider('item')

--> Index player
local player = players.LocalPlayer
local playerUi = player.PlayerGui

local computerUi = playerUi:WaitForChild('ComputerGUI') :: ScreenGui

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild('Humanoid') :: Humanoid

--]] Variables
local currentUi

--]] Functions
function findTier(variationId: string)
    local found
    for tier, variations in pairs(tierTranslator) do
        if not table.find(variations, variationId) then continue end
        found = tier; break end

    return found
end

function openUi()
    if currentUi then
        currentUi:Destroy() end

    local conn = runService.Heartbeat:Connect(function(deltaTime)
        userInputService.MouseBehavior = Enum.MouseBehavior.Default
    end)

    currentUi = computerUi:Clone()
    currentUi.Main.Background.ePay.MouseButton1Down:Connect(function()
        currentUi.Main.ePay.Visible = true
    end)

    currentUi.Main.ePay.Visible = false

    --[[ Generate Templates ]]--
    local template = currentUi.Main.ePay.Items.ItemTemplate
    template.Parent = script

    local templateOrder = {
        'engine',
        'battery',
        'filter',
        'reservoir'}
    local items = {}
    for itemId: string, itemData: {} in pairs(partCDN:getAllAssets()) do
        local partType: string, variation: string = unpack(itemId:split('.'))
        if variation=='scrappy' then continue end

        if not table.find(templateOrder, partType) then continue end
        if not items[partType] then
            items[partType] = {} end

        items[partType][variation] = itemData
    end

    local templates = {}
    local connections = {}

    for itemId: string, variations: {} in pairs(items) do
        for variationId: string, partInfo: {} in pairs(variations) do
            local itemTier = findTier(variationId)
            local itemInfo = itemCDN:getAsset(`{itemId}.{variationId}`)

            local newTemplate = template:Clone() :: Frame
            local offset = table.find(templateOrder, itemId)
            local typeIndex = table.find(templateOrder, itemId) - 1
            newTemplate.LayoutOrder = (typeIndex*100)+itemTier
            
            newTemplate.Name = `item.{itemId}.{variationId}`
            newTemplate.PartName.Text = itemInfo.style.name
            newTemplate.Price.Text = 
                `S$<font color="rgb(0, 175, 0)">{partInfo.behavior.buyPrice}</font>`

            newTemplate.PartImage.Image = `rbxassetid://{itemInfo.style.icon}`

            local chosenSellerNames = sellerNames[itemId][itemTier]
            local sellerName = chosenSellerNames[math.random(1, #chosenSellerNames)]

            local ratingQuality = math.random(partInfo.behavior.quality-10, partInfo.behavior.quality+10)
            local ratings = math.random(1, 20*(itemTier*itemTier))
            newTemplate.SellerName.Text =
                `{sellerName} <font color="rgb(150, 150, 150)">[{ratingQuality}% ({ratings})]</font>`

            newTemplate.Parent = currentUi.Main.ePay.Items

            connections[`{itemId}.{variationId}`] = newTemplate.PurchaseButton.MouseButton1Down:Connect(function()
                
            end)
            
            if not templates[itemId] then templates[itemId] = {} end
            templates[itemId][variationId] = newTemplate
        end
    end

    template:Destroy()

    currentUi.Name = `computer.{https:GenerateGUID(false)}`
    currentUi.Parent = playerUi
    currentUi.Enabled = true

    return function()
        conn:Disconnect()
        conn = nil

        userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
end

function closeUi()
    if currentUi then
        currentUi:Destroy()
    end
end

--]] Script
prompt.Triggered:Connect(function() --> Open UI
    local cleanup = openUi()
    humanoid.Jumping:Once(function()
        cleanup()
        closeUi()
    end) --> Close UI
end)