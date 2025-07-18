--[[

    Item Highlighter

    Griffin Dalby
    2025.07.17

    Simple item highlighting module

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')

--]] Modules
--]] Settings
local stateColors = {
    ['available'] = Color3.fromRGB(255, 255, 255), --> When item is in available pickup area
    ['focused'] = Color3.fromRGB(100, 255, 100), --> When item is targeted for pickup
}

--]] Constants
--]] Variables
--]] Functions
function multiplyColor(color: Color3, multiplier: number)
    local h,s,v = color:ToHSV()
    return Color3.fromHSV(h,s,v*multiplier)
end

--]] Module
local highlighter = {}
highlighter.__index = highlighter

type self = {
    highlight: Highlight,
    baseColor: Color3,
}
export type ItemHighlighter = typeof(setmetatable({} :: self, highlighter))

function highlighter.new(instance: Instance) : ItemHighlighter
    local self = setmetatable({} :: self, highlighter)

    self.highlight = Instance.new('Highlight')
    self.highlight.Parent = script
    self:adorn(instance)

    self:setState('available')
    self.highlight.FillTransparency = .5
    self.highlight.OutlineTransparency = .1

    self.highlight.DepthMode = Enum.HighlightDepthMode.Occluded

    return self
end

function highlighter:setState(state: 'available'|'focused')
    local baseColor = stateColors[state]
    assert(baseColor, `[{script.Name}] State "{state}" does not exist in StateColors list!`)

    self.baseColor = baseColor

    self.highlight.FillColor = baseColor
    self.highlight.OutlineColor = multiplyColor(baseColor, .5)
end

function highlighter:multiply(multiplier: number)
    self.highlight.FillColor = multiplyColor(self.baseColor, multiplier)
    self.highlight.OutlineColor = multiplyColor(self.baseColor, multiplier*.5)
end

function highlighter:adorn(instance: Instance)
    self.highlight.Adornee = instance
end

function highlighter:discard()
    self.highlight:Destroy()
    table.clear(self)
end

return highlighter