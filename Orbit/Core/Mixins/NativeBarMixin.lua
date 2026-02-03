-- [ ORBIT NATIVE BAR MIXIN ]------------------------------------------------------------------------
-- Shared functionality for native Blizzard bar customization (scale, orientation, hover fade)

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
    local scaleFactor = math.max(0.1, (self:GetSetting(systemIndex, sizeKey or "Size") or 100) / 100)
    OrbitEngine.NativeFrame:Modify(frame, { scale = scaleFactor })
    if frame.SetNormalScale then
        frame:SetNormalScale(scaleFactor)
    end
end

-- [ MOUSE-OVER FADE ]-------------------------------------------------------------------------------

function Mixin:ApplyMouseOver(frame, systemIndex)
    if not frame then
        return
    end
    local baseAlpha = (self:GetSetting(systemIndex, "Opacity") or 100) / 100
    Orbit.Animation:ApplyHoverFade(frame, baseAlpha, 1, EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive())
end

-- [ ORIENTATION ]-----------------------------------------------------------------------------------

function Mixin:ApplyOrientation(frame, orientation, horizontalValue)
    if not frame then
        return
    end
    frame.isHorizontal = (orientation == (horizontalValue or 0))
end

-- [ LAYOUT TRIGGER ]--------------------------------------------------------------------------------

function Mixin:TriggerLayout(frame)
    if frame and frame.Layout then
        frame:Layout()
    end
end

-- [ COMPLETE APPLY SETTINGS HELPER ]----------------------------------------------------------------

function Mixin:ApplyNativeBarSettings(frame, systemIndex, options)
    if not frame then
        return
    end
    options = options or {}
    self:ApplyScale(frame, systemIndex, options.sizeKey or "Size")
    if options.additionalScaleKey and options.targetMethod and frame[options.targetMethod] then
        frame[options.targetMethod](frame, (self:GetSetting(systemIndex, options.additionalScaleKey) or 100) / 100)
    end
    self:ApplyMouseOver(frame, systemIndex)
    self:TriggerLayout(frame)
end

-- [ SMART ALIGNMENT ]-------------------------------------------------------------------------------

function Mixin:EnableSmartAlignment(frame, textElement, paddingH)
    if not frame or not textElement then
        return
    end
    paddingH = paddingH or 2
    frame.OnAnchorChanged = function(_, parent, edge, padding)
        self:UpdateAlignment(frame, textElement, edge, paddingH)
    end
    self:UpdateAlignment(frame, textElement, nil, paddingH)
end

function Mixin:UpdateAlignment(frame, textElement, edge, paddingH)
    if not frame or not textElement then
        return
    end
    textElement:ClearAllPoints()
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
