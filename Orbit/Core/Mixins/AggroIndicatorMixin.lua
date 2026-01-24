-- [ AGGRO INDICATOR MIXIN ]-------------------------------------------------------------------------
-- Shows solid border when unit has threat/aggro
-- Used by PlayerFrame, PartyFrames, and other unit frames

local _, Orbit = ...

Orbit.AggroIndicatorMixin = {}

-- Create aggro border overlay
local function CreateAggroBorder(frame)
    if frame.aggroBorder then
        return frame.aggroBorder
    end
    
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 12) -- Above frame border, below selection
    
    -- Create border textures (same structure as selection border)
    border.top = border:CreateTexture(nil, "OVERLAY")
    border.top:SetColorTexture(1, 0, 0, 1) -- Red
    
    border.bottom = border:CreateTexture(nil, "OVERLAY")
    border.bottom:SetColorTexture(1, 0, 0, 1) -- Red
    
    border.left = border:CreateTexture(nil, "OVERLAY")
    border.left:SetColorTexture(1, 0, 0, 1) -- Red
    
    border.right = border:CreateTexture(nil, "OVERLAY")
    border.right:SetColorTexture(1, 0, 0, 1) -- Red
    
    border:Hide()
    frame.aggroBorder = border
    
    return border
end

-- Apply border layout (match selection border size)
local function ApplyBorderLayout(border, thickness)
    if not border then return end
    
    -- Top
    border.top:ClearAllPoints()
    border.top:SetPoint("TOPLEFT", border, "TOPLEFT")
    border.top:SetPoint("TOPRIGHT", border, "TOPRIGHT")
    border.top:SetHeight(thickness)
    
    -- Bottom
    border.bottom:ClearAllPoints()
    border.bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT")
    border.bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT")
    border.bottom:SetHeight(thickness)
    
    -- Left
    border.left:ClearAllPoints()
    border.left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, -thickness)
    border.left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, thickness)
    border.left:SetWidth(thickness)
    
    -- Right
    border.right:ClearAllPoints()
    border.right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, -thickness)
    border.right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, thickness)
    border.right:SetWidth(thickness)
end

-- Update aggro indicator for a single frame
function Orbit.AggroIndicatorMixin:UpdateAggroIndicator(frame, plugin)
    if not frame or not frame.unit then
        return
    end
    
    local unit = frame.unit
    
    -- Check if aggro indicators are enabled
    local enabled = plugin:GetSetting(1, "AggroIndicatorEnabled")
    if not enabled then
        if frame.aggroBorder then
            frame.aggroBorder:Hide()
        end
        return
    end
    
    -- Check if unit exists
    if not UnitExists(unit) then
        if frame.aggroBorder then
            frame.aggroBorder:Hide()
        end
        return
    end
    
    -- Get threat status
    local status = UnitThreatSituation(unit)
    
    -- Status values:
    -- nil = no threat
    -- 0 = not on threat table
    -- 1 = lower threat than tank
    -- 2 = higher threat than tank
    -- 3 = tanking/has aggro
    
    local hasAggro = status == 3
    
    if hasAggro then
        -- Ensure border exists
        local border = CreateAggroBorder(frame)
        
        -- Get settings
        local thickness = plugin:GetSetting(1, "AggroThickness") or 2
        local color = plugin:GetSetting(1, "AggroColor") or { r = 1.0, g = 0.0, b = 0.0, a = 1 }
        
        -- Apply layout
        ApplyBorderLayout(border, thickness)
        
        -- Apply color
        border.top:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        border.bottom:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        border.left:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        border.right:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        
        border:Show()
    else
        if frame.aggroBorder then
            frame.aggroBorder:Hide()
        end
    end
end

-- Update all frames (for plugins with multiple frames like PartyFrames)
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
