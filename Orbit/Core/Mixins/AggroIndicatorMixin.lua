-- [ AGGRO INDICATOR MIXIN ]-------------------------------------------------------------------------
-- Shows solid border when unit has threat/aggro (PlayerFrame, PartyFrames, etc.)

local _, Orbit = ...

Orbit.AggroIndicatorMixin = {}

local function CreateAggroBorder(frame)
    if frame.aggroBorder then
        return frame.aggroBorder
    end
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 12)
    border.top = border:CreateTexture(nil, "OVERLAY")
    border.top:SetColorTexture(1, 0, 0, 1)
    border.bottom = border:CreateTexture(nil, "OVERLAY")
    border.bottom:SetColorTexture(1, 0, 0, 1)
    border.left = border:CreateTexture(nil, "OVERLAY")
    border.left:SetColorTexture(1, 0, 0, 1)
    border.right = border:CreateTexture(nil, "OVERLAY")
    border.right:SetColorTexture(1, 0, 0, 1)
    border:Hide()
    frame.aggroBorder = border
    return border
end

local function ApplyBorderLayout(border, thickness)
    if not border then
        return
    end
    border.top:ClearAllPoints()
    border.top:SetPoint("TOPLEFT")
    border.top:SetPoint("TOPRIGHT")
    border.top:SetHeight(thickness)
    border.bottom:ClearAllPoints()
    border.bottom:SetPoint("BOTTOMLEFT")
    border.bottom:SetPoint("BOTTOMRIGHT")
    border.bottom:SetHeight(thickness)
    border.left:ClearAllPoints()
    border.left:SetPoint("TOPLEFT", 0, -thickness)
    border.left:SetPoint("BOTTOMLEFT", 0, thickness)
    border.left:SetWidth(thickness)
    border.right:ClearAllPoints()
    border.right:SetPoint("TOPRIGHT", 0, -thickness)
    border.right:SetPoint("BOTTOMRIGHT", 0, thickness)
    border.right:SetWidth(thickness)
end

function Orbit.AggroIndicatorMixin:UpdateAggroIndicator(frame, plugin)
    if not frame or not frame.unit then
        return
    end
    local enabled = plugin:GetSetting(1, "AggroIndicatorEnabled")
    if not enabled then
        if frame.aggroBorder then
            frame.aggroBorder:Hide()
        end
        return
    end
    if not UnitExists(frame.unit) then
        if frame.aggroBorder then
            frame.aggroBorder:Hide()
        end
        return
    end
    local hasAggro = UnitThreatSituation(frame.unit) == 3
    if hasAggro then
        local border = CreateAggroBorder(frame)
        local thickness = plugin:GetSetting(1, "AggroThickness") or 2
        local color = plugin:GetSetting(1, "AggroColor") or { r = 1.0, g = 0.0, b = 0.0, a = 1 }
        ApplyBorderLayout(border, thickness)
        border.top:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        border.bottom:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        border.left:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        border.right:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        border:Show()
    elseif frame.aggroBorder then
        frame.aggroBorder:Hide()
    end
end

function Orbit.AggroIndicatorMixin:UpdateAllAggroIndicators(plugin)
    if not plugin or not plugin.frames then
        return
    end
    for _, frame in ipairs(plugin.frames) do
        if frame and frame.unit then
            self:UpdateAggroIndicator(frame, plugin)
        end
    end
end

-- Backward compatibility alias
Orbit.PartyFrameAggroMixin = Orbit.AggroIndicatorMixin
