-- [ TOUR PLUGIN ] -----------------------------------------------------------------------------------
-- Proper Orbit plugin for the onboarding playground frames.
---@type Orbit
local Orbit = Orbit
local Engine = Orbit.Engine

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Tour"
local MIN_W, MAX_W = 50, 200
local MIN_H, MAX_H = 10, 50
local FRAME_W = 150
local FRAME_H = 50
local FRAME_OFFSET_X = 150
local FRAME_BG = { r = 0.12, g = 0.12, b = 0.12, a = 0.85 }
local FRAME_BORDER = { r = 0.4, g = 0.8, b = 0.4, a = 0.9 }
local INDEX_A = "A"
local INDEX_B = "B"

-- [ REGISTRATION ] ----------------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Tour", SYSTEM_ID, {
    defaults = {
        Width = FRAME_W,
        Height = FRAME_H,
    },
})

-- [ FRAME CREATION ] --------------------------------------------------------------------------------
local function CreateTourFrame(name, label, systemIndex, offsetX)
    local frame = Engine.FrameFactory:Create(name, Plugin, {
        width = FRAME_W,
        height = FRAME_H,
        x = offsetX,
        y = 0,
        point = "CENTER",
        systemIndex = systemIndex,
        autoRestore = false,
    })
    frame.editModeName = nil
    frame.isTourFrame = true
    frame.orbitNoSnap = false
    frame.anchorOptions = { syncDimensions = false, mergeBorders = true }
    frame.orbitResizeBounds = { minW = MIN_W, maxW = MAX_W, minH = MIN_H, maxH = MAX_H }
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(FRAME_BG.r, FRAME_BG.g, FRAME_BG.b, FRAME_BG.a)
    -- Border edges
    local bc = FRAME_BORDER
    local scale = frame:GetEffectiveScale()
    local borderPx = Engine.Pixel:Multiple(1, scale)
    local top = frame:CreateTexture(nil, "BORDER"); top:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(borderPx)
    local bot = frame:CreateTexture(nil, "BORDER"); bot:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(borderPx)
    local lft = frame:CreateTexture(nil, "BORDER"); lft:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    lft:SetPoint("TOPLEFT"); lft:SetPoint("BOTTOMLEFT"); lft:SetWidth(borderPx)
    local rgt = frame:CreateTexture(nil, "BORDER"); rgt:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    rgt:SetPoint("TOPRIGHT"); rgt:SetPoint("BOTTOMRIGHT"); rgt:SetWidth(borderPx)
    -- Label
    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.label:SetPoint("CENTER")
    frame.label:SetText(label)
    frame.label:SetTextColor(0.7, 0.9, 0.7, 1)
    frame:Hide()
    return frame
end

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self.frameA = CreateTourFrame("TourFrameA", "A", INDEX_A, -FRAME_OFFSET_X)
    self.frameB = CreateTourFrame("TourFrameB", "B", INDEX_B, FRAME_OFFSET_X)
    -- Override Plugin.Frame (Factory sets it to last created frame)
    self.Frame = nil
end

function Plugin:ApplySettings()
    for _, frame in ipairs({ self.frameA, self.frameB }) do
        local idx = frame.systemIndex
        local w = self:GetSetting(idx, "Width") or FRAME_W
        local h = self:GetSetting(idx, "Height") or FRAME_H
        frame:SetSize(w, h)
    end
end

-- [ SETTINGS UI ] -----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame and systemFrame.systemIndex or INDEX_A
    local SB = Engine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }
    SB:AddSizeSettings(self, schema, systemIndex, systemFrame,
        { min = MIN_W, max = MAX_W, default = FRAME_W },
        { min = MIN_H, max = MAX_H, default = FRAME_H })
    Engine.Config:Render(dialog, systemFrame, self, schema)
end
