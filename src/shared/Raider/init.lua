--[[

    Raider Module

    Griffin Dalby
    2025.07.27

    This module will provide an object for server and client, controlling
    raiders, from simply standing there to raids.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')
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

--]] Constants
local isServer = runService:IsServer()

--> Networking channels
local gameChannel = networking.getChannel('game')

--> Caching groups
local vehicleCache = caching.findCache('vehicle')

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

type self = {}
export type Raider = typeof(setmetatable({} :: self, raider))

function raider.new(uuid: string, outfitId: number, headId: number, skinTone: Color3): Raider
    local self = setmetatable({} :: self, raider)

    --[[ SETUP SELF ]]--
    self.uuid = uuid

    if isServer then
        --[[ SERVER ]]--
        local outfitId  = math.random(1, #outfits)
        local headId    = math.random(1, #heads)

        local toneRange = skinTones[math.random(1, #skinTones)]
        local skinTone  = randomColor(toneRange.min, toneRange.max)

        gameChannel.raider:with()
            :broadcastGlobally()
            :headers('create')
            :data(self.uuid, outfitId, headId, skinTone)
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

    self.model.Name = `raider_{uuid}`
    self.model.Parent = workspace.__temp

    return self
end

function raider:pivotTo(cf: CFrame)
    self.model:pivotTo(cf)
end

return raider