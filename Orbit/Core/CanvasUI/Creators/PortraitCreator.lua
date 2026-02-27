-- [ CANVAS MODE - PORTRAIT CREATOR ]----------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local CC = CanvasMode.CreatorConstants

-- [ CREATOR ]---------------------------------------------------------------------------------------
local function Create(container, preview, key, source, data)
    local visual = container:CreateTexture(nil, "ARTWORK")
    visual:SetAllPoints()
    SetPortraitTexture(visual, "player")
    local portraitSize = CC.DEFAULT_PORTRAIT_SIZE
    if source and source.orbitOriginalWidth then portraitSize = source.orbitOriginalWidth end
    container:SetSize(portraitSize, portraitSize)
    return visual
end

CanvasMode:RegisterCreator("Portrait", Create)
