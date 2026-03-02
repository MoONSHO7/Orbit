-- [ ORBIT SMART GUIDES ]----------------------------------------------------------------------------
-- Visual snap feedback guides for component editing. Shows lines when snapping to edges/center.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.SmartGuides = {}
local SmartGuides = Engine.SmartGuides

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local GUIDE_COLORS = {
    LEFT   = { 1.0, 0.55, 0.15, 0.9 },
    RIGHT  = { 0.8, 0.4, 1.0, 0.9 },
    TOP    = { 1.0, 0.55, 0.15, 0.9 },
    BOTTOM = { 0.8, 0.4, 1.0, 0.9 },
    CENTER = { 0.2, 0.9, 0.85, 0.9 },
}
local GUIDE_THICKNESS = 2

-- [ CREATE ]----------------------------------------------------------------------------------------

function SmartGuides:Create(container)
    local guideLevel = (Orbit.Constants and Orbit.Constants.Levels and Orbit.Constants.Levels.SmartGuides) or 90

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
        guides.vLine:SetColorTexture(unpack(GUIDE_COLORS[snapX] or GUIDE_COLORS.CENTER))
        guides.vLine:ClearAllPoints()
        guides.vLine:SetSize(GUIDE_THICKNESS, parentH)
        guides.vLine:SetPoint(snapX == "CENTER" and "CENTER" or snapX, guides.container, snapX == "CENTER" and "CENTER" or snapX, 0, 0)
        guides.vLine:Show()
    else
        guides.vLine:Hide()
    end

    if snapY then
        guides.hLine:SetColorTexture(unpack(GUIDE_COLORS[snapY] or GUIDE_COLORS.CENTER))
        guides.hLine:ClearAllPoints()
        guides.hLine:SetSize(parentW, GUIDE_THICKNESS)
        guides.hLine:SetPoint(snapY == "CENTER" and "CENTER" or snapY, guides.container, snapY == "CENTER" and "CENTER" or snapY, 0, 0)
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
