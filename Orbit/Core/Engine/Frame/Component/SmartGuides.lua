-- [ ORBIT SMART GUIDES ]----------------------------------------------------------------------------
-- Visual snap feedback guides for component editing. Shows lines when snapping to edges/center.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.SmartGuides = {}
local SmartGuides = Engine.SmartGuides

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local GUIDE_COLORS = {
    CENTER = { 0.4, 0.75, 1.0, 0.9 },   -- Orbit Cyan
    EDGE = { 0.6, 0.35, 0.95, 0.9 },    -- Orbit Purple
}
local GUIDE_THICKNESS = 2

-- [ CREATE ]----------------------------------------------------------------------------------------

function SmartGuides:Create(container)
    local C = Orbit.Constants
    local guideLevel = (C and C.Levels and C.Levels.SmartGuides) or 90

    local frame = CreateFrame("Frame", nil, container)
    frame:SetAllPoints(container)
    frame:SetFrameLevel(container:GetFrameLevel() + guideLevel)

    local guides = {
        container = container,
        frame = frame,
        vLine = frame:CreateTexture(nil, "OVERLAY", nil, 7),
        hLine = frame:CreateTexture(nil, "OVERLAY", nil, 7),
    }
    guides.vLine:Hide()
    guides.hLine:Hide()
    return guides
end

-- [ UPDATE ]----------------------------------------------------------------------------------------

function SmartGuides:Update(guides, snapX, snapY, parentW, parentH)
    if snapX then
        local color = snapX == "CENTER" and GUIDE_COLORS.CENTER or GUIDE_COLORS.EDGE
        guides.vLine:SetColorTexture(unpack(color))
        guides.vLine:ClearAllPoints()
        guides.vLine:SetSize(GUIDE_THICKNESS, parentH)
        local anchor = snapX == "CENTER" and "CENTER" or snapX
        guides.vLine:SetPoint(anchor, guides.container, anchor, 0, 0)
        guides.vLine:Show()
    else
        guides.vLine:Hide()
    end

    if snapY then
        local color = snapY == "CENTER" and GUIDE_COLORS.CENTER or GUIDE_COLORS.EDGE
        guides.hLine:SetColorTexture(unpack(color))
        guides.hLine:ClearAllPoints()
        guides.hLine:SetSize(parentW, GUIDE_THICKNESS)
        local anchor = snapY == "CENTER" and "CENTER" or snapY
        guides.hLine:SetPoint(anchor, guides.container, anchor, 0, 0)
        guides.hLine:Show()
    else
        guides.hLine:Hide()
    end
end

-- [ HIDE ALL ]--------------------------------------------------------------------------------------

function SmartGuides:Hide(guides)
    if not guides then return end
    guides.vLine:Hide()
    guides.hLine:Hide()
end
