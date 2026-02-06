---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ COOLDOWN UTILS ]----------------------------------------------------------------------------------
local CooldownUtils = {}

-- [ SKIN SETTINGS BUILDER ]---------------------------------------------------------------------------
function CooldownUtils:BuildSkinSettings(plugin, systemIndex, options)
    options = options or {}
    return {
        style = options.style or 1,
        aspectRatio = plugin:GetSetting(systemIndex, "aspectRatio") or "1:1",
        zoom = options.zoom or 0,
        borderStyle = options.borderStyle or 1,
        borderSize = Orbit.db.GlobalSettings.BorderSize,
        swipeColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(plugin:GetSetting(systemIndex, "SwipeColorCurve")) or plugin:GetSetting(systemIndex, "SwipeColor") or { r = 0, g = 0, b = 0, a = 0.8 },
        orientation = plugin:GetSetting(systemIndex, "Orientation"),
        limit = plugin:GetSetting(systemIndex, "IconLimit"),
        padding = plugin:GetSetting(systemIndex, "IconPadding"),
        size = plugin:GetSetting(systemIndex, "IconSize"),
        showTimer = plugin:GetSetting(systemIndex, "ShowTimer"),
        showGCDSwipe = plugin:GetSetting(systemIndex, "ShowGCDSwipe"),
        baseIconSize = Constants.Skin.DefaultIconSize,
        backdropColor = plugin:GetSetting(systemIndex, "BackdropColour"),
        showTooltip = options.showTooltip or false,
        verticalGrowth = options.verticalGrowth,
    }
end

-- [ TEXT STYLE BUILDER ]------------------------------------------------------------------------------
function CooldownUtils:GetComponentStyle(plugin, systemIndex, key, defaultOffset)
    local fontPath = plugin:GetGlobalFont()
    local baseSize = plugin:GetBaseFontSize()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local positions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
    local pos = positions[key] or {}
    local overrides = pos.overrides or {}

    local font = fontPath
    if overrides.Font and LSM then font = LSM:Fetch("font", overrides.Font) or fontPath end
    local size = overrides.FontSize or math.max(6, baseSize + (defaultOffset or 0))
    local flags = overrides.ShowShadow and "" or "OUTLINE"

    return font, size, flags, pos, overrides
end

-- [ TEXT COLOR APPLIER ]------------------------------------------------------------------------------
-- remainingPercent: optional 0-1 value for progress-aware curve sampling (1=full, 0=expired)
function CooldownUtils:ApplyTextColor(textElement, overrides, remainingPercent)
    if not textElement or not textElement.SetTextColor then return end

    local color = nil
    if overrides and overrides.UseClassColour then
        local _, playerClass = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[playerClass]
        if classColor then color = { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
    elseif overrides and overrides.CustomColor and overrides.CustomColorCurve then
        if remainingPercent then
            color = OrbitEngine.WidgetLogic:SampleColorCurve(overrides.CustomColorCurve, remainingPercent)
        else
            color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(overrides.CustomColorCurve)
        end
    elseif overrides and overrides.CustomColor and overrides.CustomColorValue then
        color = overrides.CustomColorValue
    end

    if not color then
        local fontCurve = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.FontColorCurve
        color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(fontCurve) or { r = 1, g = 1, b = 1, a = 1 }
    end
    textElement:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

-- [ TEXT SHADOW APPLIER ]-----------------------------------------------------------------------------
function CooldownUtils:ApplyTextShadow(textElement, showShadow)
    if not textElement then return end
    if showShadow then textElement:SetShadowOffset(1, -1) else textElement:SetShadowOffset(0, 0) end
end

-- [ ICON DIMENSION CALCULATOR ]-----------------------------------------------------------------------
function CooldownUtils:CalculateIconDimensions(plugin, systemIndex)
    local iconSize = plugin:GetSetting(systemIndex, "IconSize") or Constants.Cooldown.DefaultIconSize
    local baseSize = Constants.Skin.DefaultIconSize or 40
    local scaledSize = baseSize * (iconSize / 100)
    local aspectRatio = plugin:GetSetting(systemIndex, "aspectRatio") or "1:1"
    local w, h = scaledSize, scaledSize

    if aspectRatio == "16:9" then h = scaledSize * (9 / 16)
    elseif aspectRatio == "4:3" then h = scaledSize * (3 / 4)
    elseif aspectRatio == "21:9" then h = scaledSize * (9 / 21) end

    return w, h, scaledSize
end

-- [ SIMPLE TEXT APPLIER ]-----------------------------------------------------------------------------
function CooldownUtils:ApplySimpleTextStyle(plugin, systemIndex, textElement, componentKey, defaultAnchor, defaultOffsetX, defaultOffsetY)
    if not textElement then return end

    local font, size, flags, pos, overrides = self:GetComponentStyle(plugin, systemIndex, componentKey, 0)
    textElement:SetFont(font, size, flags)
    self:ApplyTextShadow(textElement, overrides.ShowShadow)
    self:ApplyTextColor(textElement, overrides)

    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
    if ApplyTextPosition then
        ApplyTextPosition(textElement, textElement:GetParent(), pos, defaultAnchor, defaultOffsetX, defaultOffsetY)
    end
end

-- Export to Orbit Engine
OrbitEngine.CooldownUtils = CooldownUtils
