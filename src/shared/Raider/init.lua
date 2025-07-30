--[[

    Raider Module

    Griffin Dalby
    2025.07.27

    This module will provide an object for server and client, controlling
    raiders, from simply standing there to raids.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local userInputService = game:GetService('UserInputService')
local runService = game:GetService('RunService')
local players = game:GetService('Players')
local https = game:GetService('HttpService')

--]] Modules
local sawdust = require(replicatedStorage.Sawdust)

local networking = sawdust.core.networking
local caching = sawdust.core.cache
local cdn = sawdust.core.cdn

--]] Settings
local outfits = {
    [1] = {
        13779911769,
        13779925108},
    [2] = {
        14650271000,
        15679545561},
    [3] = {
        84519735384147,
        128914259309690},
    [4] = {
        87264901866010,
        110342791637696},
    [5] = {
        18137069733,
        15968430669},
    [6] = {
        123264470666885,
        111967264898396},
    [7] = {
        79685001636879,
        131287382349148
    },
    [8] = {
        74823115090852,
        134251979305807},
    [9] = {
        92077664232646,
        74050424955207},
    [10] = {
        11834728833,
        13520736589},
    [11] = {
        7008020557,
        4814316577},
    [12] = {
        139352571392893,
        8318917741},
    [13] = {
        11834728833,
        13779925108},
    [14] = {
        15642990043,
        15968430669},
    [15] = {
        14497500973,
        13520736589},
    [16] = {
        7026186584,
        4814316577},
    [17] = {
        74915995642849,
        83084503056802},
    [18] = {
        2249021545,
        2249018266},
    [19] = {
        nil,
        243543297
    }
}

local heads = {
    [1] = {
        103421835143920,
        70772393016708, 1},
    [2] = {
        94453236754666,
        91120549983014, .95},
    [3] = {
        130768796022951,
        91605086666712, 1},
    [4] = {
        112604594568814,
        77237228826335, 1},
    [5] = {
        18696507813,
        89636512635851, 1},
    [6] = {
        18311019066,
        86604410573517, 1},
    [7] = {
        18351647808,
        118029290622843, 1},
    [8] = {
        111733361209918,
        92734051473855, 1},
    [9] = {
        73387521158339,
        71256650511803, 1},
    [10] = {
        103302756802473,
        121840713648464, 1},
    [11] = {
        14768972661,
        14768989478, 1},
    [12] = {
        18351647808,
        106654054253360, 1},
    [13] = {
        118324349179606,
        106693922368543, 1},
    [14] = {
        18696507813,
        18967284960, 1},
    [15] = {
        18351647808,
        18771500795, 1},
    [16] = {
        139005570052834,
        73640191628365, .94},
    [17] = {
        113444775548263,
        78289131043291, 1},
    [18] = {
        18351647808,
        71806269170657, 1},
    [19] = {
        88559351834073,
        86282639508769, 1}
}

local skinTones = {
    { --> Very Light
        max = {255, 228, 196},
        min = {255, 219, 172},
    },
    { --> Light
        max = {255, 219, 172},
        min = {241, 194, 125},
    },
    { --> Light Medium
        max = {241, 194, 125},
        min = {224, 172, 105},
    },
    { --> Medium Dark
        max = {198, 134, 94},
        min = {161, 102, 68},
    },
    { --> Dark
        max = {161, 102, 94},
        min = {115, 82, 68},
    },
    { --> Very Dark
        max = {115, 82, 68},
        min = {72, 57, 49},
    },
    { --> Deep
        max = {72, 57, 49},
        min = {44, 34, 30},
    },
}

local raider_first_names = {
    "Axe", "Blade", "Crank", "Diesel", "Edge", "Flint", "Grease", "Hammer", 
    "Iron", "Junk", "Knox", "Lead", "Mad", "Nails", "Oil", "Pike", "Quake", 
    "Rust", "Steel", "Tank", "Volt", "Wreck", "Zap", "Ash", "Bone", "Crow", 
    "Dagger", "Echo", "Fang", "Grit", "Hawk", "Ice", "Jag", "Kilo", "Lynch", 
    "Meat", "Nitro", "Ox", "Phantom", "Quarry", "Raven", "Spike", "Torch", 
    "Viper", "Wolf", "Zero", "Blaze", "Clutch", "Doom", "Engine", "Fire", 
    "Ghost", "Haze", "Ink", "Jinx", "Knife", "Lash", "Motor", "Needle", 
    "Onyx", "Piston", "Quest", "Razor", "Scar", "Turbo", "Venom", "Wire", 
    "X-Ray", "Yard", "Zone", "Acid", "Bullet", "Chain", "Death", "Ember", 
    "Forge", "Grim", "Hunter", "Iron", "Jack", "Killer", "Lightning", "Max", 
    "Nero", "Outlaw", "Prowl", "Quick", "Rage", "Savage", "Thunder", "Vex", 
    "War", "Xerx", "Yank", "Zed", "Bandit", "Crash", "Drake", "Exile", 
    "Flash", "Gunner", "Havoc", "Impact", "Jet", "Knux", "Lynx", "Mace", 
    "Nomad", "Outcast", "Pulse", "Reaper", "Storm", "Tyrant", "Virus", "Wasp", 
    "Xen", "Yoke", "Zulu", "Beast", "Colt", "Demon", "Eclipse", "Fury", 
    "Grave", "Hex", "Inferno", "Jagged", "Kraken", "Locust", "Mauler", "Nova", 
    "Oracle", "Phantom", "Quiver", "Rogue", "Scythe", "Titan", "Vortex", "Wrath"
}

local raider_last_names = {
    "Axebreaker", "Bonecrusher", "Carjacker", "Deathdealer", "Enginekiller", "Furiosa", 
    "Gasburner", "Headhunter", "Ironwolf", "Junkyard", "Killswitch", "Leadfoot", 
    "Meatgrinder", "Nitrous", "Oilspill", "Pistonhead", "Quickdraw", "Rustbucket", 
    "Steelclaw", "Turbocharged", "Venomfang", "Wasteland", "Xerxes", "Yellowjacket", 
    "Zombiekiller", "Bloodspiller", "Crowbar", "Doomrider", "Exhaustpipe", "Flamethrower", 
    "Gutripper", "Hellraiser", "Interceptor", "Jackhammer", "Knifeedge", "Lockjaw", 
    "Motorhead", "Nightrider", "Overkill", "Painkiller", "Quarterpounder", "Roadwarrior", 
    "Skullcrusher", "Thunderdome", "Ultraviolence", "Vehicular", "Warboy", "Xterminator", 
    "Yarddog", "Zerotolerance", "Accelerator", "Bladerunner", "Chainsmoker", "Darkrider", 
    "Electricchair", "Firestarter", "Gravedigger", "Hammerfall", "Ironfist", "Jawbreaker", 
    "Knuckleduster", "Lawbreaker", "Machinegun", "Nukular", "Offroad", "Powerhouse", 
    "Quicksilver", "Rampage", "Shotgun", "Tankbuster", "Undertaker", "Vulture", 
    "Warpath", "Xtreme", "Yardstick", "Zerosum", "Backstabber", "Crowkiller", "Dustdevil", 
    "Enginebay", "Fastlane", "Gasoline", "Hardtop", "Ignition", "Jumpstart", "Knockout", 
    "Lowrider", "Mudflap", "Neckbreaker", "Overdrive", "Pitbull", "Quartermile", "Roadkill", 
    "Supercharged", "Tailpipe", "Unleaded", "Vroom", "Whiplash", "Xenophobic", "Yellowline", 
    "Zoomzoom", "Axegrinder", "Boltcutter", "Chromedome", "Dieselfumes", "Exhausted", 
    "Fuelinjected", "Gearshift", "Horsepowered", "Intake", "Junkheap", "Kickstart", 
    "Liftedtruck", "Mudtires", "Noslick", "Octane", "Pumpgas", "Quarterpanel", "Revlimiter", 
    "Straightpipe", "Torque", "Unleashed", "Vtec", "Wideopen", "Exhaustnote", "Yolowagon", 
    "Zeroemissions"
}

local intro_quotes = {
    'Yeah, what now?', 'What do you need from me?', 'Why are you bothering me? Aren\'t you supposed to be busy?',
    'Go do your job, I don\'t want to talk to you.', 'What? My car isn\'t going to fix itself?', 'What do you want?',
    'What could it possibly be now?', 'I don\'t have time to converse with you.', 'I came in for a car repair, not a chat over coffee.',
}

local moods = {
    'patient',
    'impatient',
    'violent',
}

local moodBasePatience = {
    ['patient'] = 50,
    ['impatient'] = 25,
    ['violent'] = 35
}

--]] Constants
local isServer = runService:IsServer()

--> Networking channels
local gameChannel = networking.getChannel('game')
local vehicleChannel = networking.getChannel('vehicle')

--> Caching groups
local vehicleCache = caching.findCache('vehicle')
local carSlotCache = caching.findCache('carSlots')

--> CDN providers
local gameProvider = cdn.getProvider('game')

--]] Variables
--]] Functions
local function randomColor(min, max)
    local r = math.random(min[1], max[1])
    local g = math.random(min[2], max[2])
    local b = math.random(min[3], max[3])
    return Color3.new(r/255, g/255, b/255)
end

--]] Modules
local raider = {}
raider.__index = raider

type self = {
    uuid: string,
    mood: string,
    
    model: Model?,

    maxPatience: number,
    patience: number,
}
export type Raider = typeof(setmetatable({} :: self, raider))

function raider.new(uuid: string, outfitId: number, headId: number, skinTone: Color3, name: {}, mood: string): Raider
    local self = setmetatable({} :: self, raider)

    --[[ SETUP SELF ]]--
    self.uuid = uuid
    self.mood = isServer and moods[math.random(1, #moods)] or mood

    if isServer then
        --[[ SERVER ]]--
        local outfitId  = math.random(1, #outfits)
        local headId    = math.random(1, #heads)

        local toneRange = skinTones[math.random(1, #skinTones)]
        local skinTone  = randomColor(toneRange.min, toneRange.max)

        local name = {
            raider_first_names[math.random(1, #raider_first_names)], 
            raider_last_names[math.random(1, #raider_last_names)]}

        gameChannel.raider:with()
            :broadcastGlobally()
            :headers('create')
            :data(self.uuid, outfitId, headId, skinTone, name, self.mood)
            :fire()

        return self
    end

    --[[ CLIENT ]]--

    --> Render Model
    self.model = gameProvider:getAsset('R6'):Clone() :: Model

    local chosenOutfit, chosenHead = outfits[outfitId], heads[headId]
    local headScale = chosenHead[3]
    chosenOutfit = {
        `rbxassetid://{chosenOutfit[1]}`,
        `rbxassetid://{chosenOutfit[2]}`,
    }
    chosenHead = {
        `rbxassetid://{chosenHead[1]}`,
        `rbxassetid://{chosenHead[2]}`
    }

    local shirt, pants = Instance.new('Shirt'), Instance.new('Pants')
    shirt.ShirtTemplate, pants.PantsTemplate = unpack(chosenOutfit)

    local head = self.model:FindFirstChild('Head')
    local mesh = head:FindFirstChildWhichIsA('SpecialMesh')
    mesh.MeshId, mesh.TextureId = unpack(chosenHead)
    mesh.Scale = Vector3.new(headScale, headScale, headScale)

    shirt.Name, pants.Name = 'Shirt', 'Pants'
    shirt.Parent, pants.Parent = self.model, self.model
    mesh.Parent = head

    local bodyColors = Instance.new('BodyColors')
    bodyColors.HeadColor3, bodyColors.TorsoColor3 = skinTone, skinTone
    bodyColors.LeftArmColor3, bodyColors.RightArmColor3 = skinTone, skinTone
    bodyColors.LeftLegColor3, bodyColors.RightLegColor3 = skinTone, skinTone
    bodyColors.Parent = self.model

    local firstName: string, lastName: string = unpack(name)

    --> UI
    local vehicle = vehicleCache:getValue(uuid)
    assert(`Failed to find vehicle w/ raider uuid!`)

    local player = players.LocalPlayer
    local playerUi = player.PlayerGui.UI

    local raiderTemplate = playerUi.Templates.RaiderSlot:Clone()
    raiderTemplate.RaiderName.Text = `{firstName} {lastName:sub(1,1):upper()}.`
    
    local templateModel = self.model:Clone()
    templateModel:PivotTo(CFrame.new(0, 0, 0))
    templateModel.Parent = raiderTemplate.Viewport

    local patienceMeter = runService.Heartbeat:Connect(function(dT)
        if not self.patience then return end
        local bayId = vehicle:getBay()
        if bayId then
            raiderTemplate.Viewport.BayID.Text = `Bay {bayId}` end
        raiderTemplate.Patience.Bar.Size = UDim2.new(math.max(self.patience/self.maxPatience, 0), 0, 1, 0)

        self.patience -= dT --> Accurate second timer
        if self.patience <= 0 then
            --> Patience ran out!
        end
    end)

    raiderTemplate.Parent = playerUi.RaiderList
    raiderTemplate.Visible = true

    --> Interaction
    local prompt = Instance.new('ProximityPrompt')
    prompt.ObjectText = 'Raider'
    prompt.ActionText = 'Interact'
    prompt.Parent = self.model

    prompt.Triggered:Connect(function(playerWhoTriggered)
        prompt.Enabled = false

        local playerUi = playerWhoTriggered.PlayerGui
        local raiderInteraction = playerUi.UI.RaiderInteraction:Clone() :: Frame
        raiderInteraction.Name = `interaction_{firstName}.{lastName}`

        local viewmodel = self.model:Clone()
        viewmodel:pivotTo(CFrame.new(0, 0, 0))
        viewmodel.Parent = raiderInteraction.Quote.RaiderProfile.Image.RaiderViewport

        raiderInteraction.Quote.RaiderName.Text = `{firstName} {lastName}`
        raiderInteraction.Quote.QuoteBox.Text = intro_quotes[math.random(1, #intro_quotes)]

        raiderInteraction.Parent = playerUi.UI
        raiderInteraction.Visible = true

        local interactionRuntime = runService.Heartbeat:Connect(function()
            userInputService.MouseBehavior = Enum.MouseBehavior.Default
        end)
        local doneConnection, exitConnection

        local function cleanup()
            if interactionRuntime then
                interactionRuntime:Disconnect()
                interactionRuntime = nil end

            raiderInteraction:Destroy()
            userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            task.delay(1, function()
                prompt.Enabled = true
            end)

            if exitConnection then
                exitConnection:Disconnect()
                exitConnection = nil end
            if doneConnection then
                doneConnection:Disconnect()
                doneConnection = nil end
        end

        doneConnection = raiderInteraction.Interactions.Done.Button.MouseButton1Down:Once(function()
            raiderInteraction.Interactions.Visible = false
            patienceMeter:Disconnect()
            patienceMeter = nil

            raiderTemplate:Destroy()

            task.delay(2, function()
                cleanup()
                vehicleChannel.finish:with()
                    :headers()
                    :data(uuid)
                    :fire()
            end)
        end)
        exitConnection = raiderInteraction.Interactions.Exit.Button.MouseButton1Down:Once(cleanup)
    end)

    self.model.Name = `raider_{uuid}`
    self.model.Parent = workspace.__temp

    return self
end

function raider:calculatePatience(vehicleBuild: {})
    self.maxPatience = moodBasePatience[self.mood]
    
    --> Chassis issues
    for partId: string, partInfo: {} in pairs(vehicleBuild.chassis) do
        local dirty = partInfo.dirty

        self.maxPatience += (dirty*.065)
    end

    --> Engine bay issues
    local issuePatience = {
        ['fire'] = 20, --> 20 seconds per part fire
        ['overheat'] = 15 --> 15 seconds per overheat
    }
    for bayPartId: string, engineItem in pairs(vehicleBuild.engineBay) do
        if engineItem.__itemUuid then
            local tags = engineItem:getTags()
            for tag: string in pairs(tags) do
                local issueId = tag:split('.')[2]
                self.maxPatience += issuePatience[issueId]
            end
        else
            for issueId: string, isActive: boolean in pairs(engineItem[2]) do
                if not isActive then continue end
                self.maxPatience += issuePatience[issueId]
            end
        end
    end

    self.patience = self.maxPatience
end

function raider:pivotTo(cf: CFrame)
    self.model:pivotTo(cf)
end

return raider