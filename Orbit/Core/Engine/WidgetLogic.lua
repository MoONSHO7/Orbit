-- [ ORBIT WIDGET LOGIC ]----------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
Engine.WidgetLogic = {}
local WL = Engine.WidgetLogic

-- [ COLOR SYSTEM FACADE ]---------------------------------------------------------------------------
local RC = Engine.ReactionColor
local CC = Engine.ClassColor
local CCE = Engine.ColorCurve

function WL:GetReactionColor(reaction) return RC:GetReactionColor(reaction) end
function WL:CurveHasClassPin(curveData) return CCE:CurveHasClassPin(curveData) end
function WL:SampleColorCurve(curveData, position) return CCE:SampleColorCurve(curveData, position) end
function WL:GetFirstColorFromCurve(curveData) return CCE:GetFirstColorFromCurve(curveData) end
function WL:GetFontColorForNonUnit(curveData) return CCE:GetFontColorForNonUnit(curveData) end
function WL:GetFirstColorFromCurveForUnit(curveData, unit) return CCE:GetFirstColorFromCurveForUnit(curveData, unit) end
function WL:ToNativeColorCurveForUnit(curveData, unit) return CCE:ToNativeColorCurveForUnit(curveData, unit) end
function WL:ToNativeColorCurve(curveData) return CCE:ToNativeColorCurve(curveData) end
function WL:FromNativeColorCurve(nativeCurve) return CCE:FromNativeColorCurve(nativeCurve) end
function WL:InvalidateNativeCurveCache(curveData) CCE:InvalidateNativeCurveCache(curveData) end

-- [ SCHEMA BUILDER FACADE ]-------------------------------------------------------------------------
local SB = Engine.SchemaBuilder

function WL:AddAnchorSettings(...) return SB:AddAnchorSettings(...) end
function WL:AddSizeSettings(...) return SB:AddSizeSettings(...) end
function WL:AddTextSettings(...) return SB:AddTextSettings(...) end
function WL:AddBorderSpacingSettings(...) return SB:AddBorderSpacingSettings(...) end
function WL:AddTextureSettings(...) return SB:AddTextureSettings(...) end
function WL:AddFontSettings(...) return SB:AddFontSettings(...) end
function WL:AddColorSettings(...) return SB:AddColorSettings(...) end
function WL:AddColorCurveSettings(...) return SB:AddColorCurveSettings(...) end
function WL:AddOrientationSettings(...) return SB:AddOrientationSettings(...) end
function WL:AddOpacitySettings(...) return SB:AddOpacitySettings(...) end
function WL:AddVisibilitySettings(...) return SB:AddVisibilitySettings(...) end
function WL:AddAspectRatioSettings(...) return SB:AddAspectRatioSettings(...) end
function WL:AddIconSizeSettings(...) return SB:AddIconSizeSettings(...) end
function WL:AddIconZoomSettings(...) return SB:AddIconZoomSettings(...) end
function WL:AddIconPaddingSettings(...) return SB:AddIconPaddingSettings(...) end
function WL:AddColumnsSettings(...) return SB:AddColumnsSettings(...) end
function WL:AddCooldownDisplaySettings(...) return SB:AddCooldownDisplaySettings(...) end
function WL:SetTabRefreshCallback(...) return SB:SetTabRefreshCallback(...) end
function WL:AddSettingsTabs(...) return SB:AddSettingsTabs(...) end
