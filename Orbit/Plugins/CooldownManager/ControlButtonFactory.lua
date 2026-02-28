-- [ CONTROL BUTTON FACTORY ]------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local CONTROL_BTN_SIZE = 10
local CONTROL_BTN_SPACING = 1
local ICON_RESTING_ALPHA = 0.8
local COLOR_GREEN = { r = 0.2, g = 0.9, b = 0.2 }
local COLOR_RED = { r = 0.9, g = 0.2, b = 0.2 }

OrbitEngine.ControlButtonFactory = {}
local Factory = OrbitEngine.ControlButtonFactory

-- Creates +/- control buttons on an anchor frame.
-- cfg = { addIcon, removeIcon, childFlag, onAdd, onRemove }
function Factory:Create(anchor, cfg)
    local controlContainer = CreateFrame("Frame", nil, anchor)
    controlContainer:SetSize(CONTROL_BTN_SIZE, (CONTROL_BTN_SIZE * 2) + CONTROL_BTN_SPACING)
    controlContainer:SetPoint("LEFT", anchor, "TOPRIGHT", 2, -((CONTROL_BTN_SIZE * 2 + CONTROL_BTN_SPACING) / 2))
    anchor.controlContainer = controlContainer

    local plusBtn = CreateFrame("Button", nil, controlContainer)
    plusBtn:SetSize(CONTROL_BTN_SIZE, CONTROL_BTN_SIZE)
    plusBtn:SetPoint("TOP", controlContainer, "TOP", 0, 0)
    plusBtn.Icon = plusBtn:CreateTexture(nil, "ARTWORK")
    plusBtn.Icon:SetAllPoints()
    plusBtn.Icon:SetTexture(cfg.addIcon)
    plusBtn.Icon:SetVertexColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
    plusBtn.Icon:SetAlpha(ICON_RESTING_ALPHA)
    plusBtn:SetScript("OnClick", function()
        if not InCombatLockdown() then cfg.onAdd() end
    end)
    plusBtn:SetScript("OnEnter", function(self) self.Icon:SetAlpha(1) end)
    plusBtn:SetScript("OnLeave", function(self) self.Icon:SetAlpha(ICON_RESTING_ALPHA) end)
    anchor.plusBtn = plusBtn

    local minusBtn = CreateFrame("Button", nil, controlContainer)
    minusBtn:SetSize(CONTROL_BTN_SIZE, CONTROL_BTN_SIZE)
    minusBtn:SetPoint("TOP", plusBtn, "BOTTOM", 0, -CONTROL_BTN_SPACING)
    minusBtn.Icon = minusBtn:CreateTexture(nil, "ARTWORK")
    minusBtn.Icon:SetAllPoints()
    minusBtn.Icon:SetTexture(cfg.removeIcon)
    minusBtn.Icon:SetVertexColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
    minusBtn.Icon:SetAlpha(ICON_RESTING_ALPHA)
    minusBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if anchor[cfg.childFlag] then cfg.onRemove(anchor) end
    end)
    minusBtn:SetScript("OnEnter", function(self) self.Icon:SetAlpha(1) end)
    minusBtn:SetScript("OnLeave", function(self) self.Icon:SetAlpha(ICON_RESTING_ALPHA) end)
    anchor.minusBtn = minusBtn
end

-- Shows/hides control buttons based on Edit Mode state.
-- childFlag: the boolean field name on anchor that marks it as a child (e.g. "isChildFrame")
function Factory:UpdateVisibility(anchor, childFlag)
    if not anchor or not anchor.controlContainer then return end
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    if isEditMode then
        anchor.controlContainer:Show()
        anchor.minusBtn:SetShown(anchor[childFlag] == true)
    else
        anchor.controlContainer:Hide()
    end
end

-- Updates all plus-button colors based on current vs max child count.
-- entries: list of { frame = ... } tables (the active children map values)
-- rootAnchor: the primary anchor frame (may be nil)
-- maxChildren: capacity cap
function Factory:UpdateColors(entries, rootAnchor, maxChildren)
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    local atMax = count >= maxChildren
    local c = atMax and COLOR_RED or COLOR_GREEN

    if rootAnchor and rootAnchor.plusBtn then
        rootAnchor.plusBtn.Icon:SetVertexColor(c.r, c.g, c.b)
        rootAnchor.plusBtn:SetEnabled(not atMax)
    end
    for _, childData in pairs(entries) do
        if childData.frame and childData.frame.plusBtn then
            childData.frame.plusBtn.Icon:SetVertexColor(c.r, c.g, c.b)
            childData.frame.plusBtn:SetEnabled(not atMax)
        end
    end
end

-- Refreshes visibility on root anchor + all children.
function Factory:RefreshAll(rootAnchor, entries, childFlag)
    self:UpdateVisibility(rootAnchor, childFlag)
    for _, childData in pairs(entries) do
        if childData.frame then self:UpdateVisibility(childData.frame, childFlag) end
    end
end
