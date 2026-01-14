-- [ ORBIT NATIVE BAR MIXIN ]------------------------------------------------------------------------
-- Shared functionality for native Blizzard bar customization (MicroMenu, BagBar, TalkingHead)
-- Consolidates scale, orientation, and mouse-over fade logic

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

Orbit.NativeBarMixin = {}
local Mixin = Orbit.NativeBarMixin

-- [ SCALE APPLICATION ]-----------------------------------------------------------------------------

function Mixin:ApplyScale(frame, systemIndex, sizeKey)
    if not frame then
        return
    end

    sizeKey = sizeKey or "Size"
    local size = self:GetSetting(systemIndex, sizeKey) or 100
    local scaleFactor = size / 100

    if scaleFactor <= 0 then
        scaleFactor = 0.1
    end

    OrbitEngine.NativeFrame:Modify(frame, { scale = scaleFactor })

    -- Also call native SetNormalScale if available
    if frame.SetNormalScale then
        frame:SetNormalScale(scaleFactor)
    end
end

-- [ MOUSE-OVER FADE ]-------------------------------------------------------------------------------

function Mixin:ApplyMouseOver(frame, systemIndex)
    if not frame then
        return
    end

    local opacity = self:GetSetting(systemIndex, "Opacity") or 100
    local baseAlpha = opacity / 100
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()

    -- "Mouse Over" behavior is now implicit:
    -- Rest at 'Opacity' setting, Fade to 100% on hover
    local minAlpha = baseAlpha
    local maxAlpha = 1

    Orbit.Animation:ApplyHoverFade(frame, minAlpha, maxAlpha, isEditMode)
end

-- [ ORIENTATION ]-----------------------------------------------------------------------------------

function Mixin:ApplyOrientation(frame, orientation, horizontalValue)
    if not frame then
        return
    end

    horizontalValue = horizontalValue or 0 -- Default: 0 = Horizontal
    frame.isHorizontal = (orientation == horizontalValue)
end

-- [ LAYOUT TRIGGER ]--------------------------------------------------------------------------------

function Mixin:TriggerLayout(frame)
    if not frame then
        return
    end

    if frame.Layout then
        frame:Layout()
    end
end

-- [ COMPLETE APPLY SETTINGS HELPER ]----------------------------------------------------------------

function Mixin:ApplyNativeBarSettings(frame, systemIndex, options)
    if not frame then
        return
    end
    options = options or {}

    -- Apply scale
    local sizeKey = options.sizeKey or "Size"
    self:ApplyScale(frame, systemIndex, sizeKey)

    -- Apply additional scale keys (e.g., EyeSize for MicroMenu)
    if options.additionalScaleKey and options.targetMethod then
        local additionalSize = self:GetSetting(systemIndex, options.additionalScaleKey) or 100
        if frame[options.targetMethod] then
            frame[options.targetMethod](frame, additionalSize / 100)
        end
    end

    -- Apply mouse-over
    self:ApplyMouseOver(frame, systemIndex)

    -- Trigger layout
    self:TriggerLayout(frame)
end

-- [ SMART ALIGNMENT ]-------------------------------------------------------------------------------

function Mixin:EnableSmartAlignment(frame, textElement, paddingH)
    if not frame or not textElement then
        return
    end
    paddingH = paddingH or 2 -- Default tight padding

    frame.OnAnchorChanged = function(_, parent, edge, padding)
        self:UpdateAlignment(frame, textElement, edge, paddingH)
    end

    -- Initial update
    self:UpdateAlignment(frame, textElement, nil, paddingH)
end

function Mixin:UpdateAlignment(frame, textElement, edge, paddingH)
    if not frame or not textElement then
        return
    end

    textElement:ClearAllPoints()

    -- Logic: Anchor RIGHT -> Align LEFT (and vice versa)
    if edge == "LEFT" then
        textElement:SetPoint("RIGHT", -paddingH, 0)
        textElement:SetJustifyH("RIGHT")
    elseif edge == "RIGHT" then
        textElement:SetPoint("LEFT", paddingH, 0)
        textElement:SetJustifyH("LEFT")
    else
        textElement:SetPoint("CENTER", 0, 0)
        textElement:SetJustifyH("CENTER")
    end
end
