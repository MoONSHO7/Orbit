---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ COOLDOWN UTILS ]----------------------------------------------------------------------------------
local CooldownUtils = {}
local HORIZONTAL_EDGES = { LEFT = true, RIGHT = true }

-- [ INHERITED PARENT RESOLVER ]----------------------------------------------------------------------
function CooldownUtils:GetInheritedParentIndex(anchorFrame, viewerMap)
    local anchors = OrbitEngine.FrameAnchor and OrbitEngine.FrameAnchor.anchors
    if not anchors then
        return nil
    end
    local current, rootIndex = anchorFrame, nil
    while true do
        local info = anchors[current]
        if not info or not HORIZONTAL_EDGES[info.edge] then
            break
        end
        local parent = info.parent
        local entry = parent and parent.systemIndex and viewerMap[parent.systemIndex]
        if not (entry and entry.anchor == parent) then
            break
        end
        rootIndex = parent.systemIndex
        current = parent
    end
    return rootIndex
end

function CooldownUtils:IsInheritingLayout(plugin, anchorFrame, viewerMap)
    return self:GetInheritedParentIndex(anchorFrame, viewerMap) ~= nil
end

-- [ SKIN SETTINGS BUILDER ]---------------------------------------------------------------------------
function CooldownUtils:BuildSkinSettings(plugin, systemIndex, options)
    options = options or {}
    local inherited = options.inheritOverrides
    return {
        style = options.style or 1,
        aspectRatio = (inherited and inherited.aspectRatio) or plugin:GetSetting(systemIndex, "aspectRatio") or "1:1",
        zoom = options.zoom or 0,
        borderStyle = options.borderStyle or 1,
        borderSize = Orbit.db.GlobalSettings.BorderSize,
        swipeColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(plugin:GetSetting(systemIndex, "SwipeColorCurve"))
            or plugin:GetSetting(systemIndex, "SwipeColor")
            or { r = 0, g = 0, b = 0, a = 0.8 },
        orientation = plugin:GetSetting(systemIndex, "Orientation"),
        limit = plugin:GetSetting(systemIndex, "IconLimit"),
        padding = (inherited and inherited.padding) or plugin:GetSetting(systemIndex, "IconPadding"),
        size = (inherited and inherited.size) or plugin:GetSetting(systemIndex, "IconSize"),
        showTimer = plugin:GetSetting(systemIndex, "ShowTimer"),
        showGCDSwipe = plugin:GetSetting(systemIndex, "ShowGCDSwipe"),
        baseIconSize = Constants.Skin.DefaultIconSize,
        backdropColor = plugin:GetSetting(systemIndex, "BackdropColour"),
        showTooltip = options.showTooltip or false,
        verticalGrowth = options.verticalGrowth,
        horizontalGrowth = options.horizontalGrowth,
    }
end

-- [ TEXT COLOR APPLIER ]------------------------------------------------------------------------------
-- Delegates to OverrideUtils.ApplyTextColor (which handles overrides + global FontColorCurve fallback).
-- remainingPercent: optional 0-1 value for progress-aware curve sampling (1=full, 0=expired)
function CooldownUtils:ApplyTextColor(textElement, overrides, remainingPercent)
    if not textElement or not textElement.SetTextColor then
        return
    end

    local OverrideUtils = OrbitEngine.OverrideUtils
    if OverrideUtils then
        OverrideUtils.ApplyTextColor(textElement, overrides, remainingPercent)
    end
end

-- [ ICON DIMENSION CALCULATOR ]-----------------------------------------------------------------------
function CooldownUtils:CalculateIconDimensions(plugin, systemIndex, overrides)
    local iconSize = (overrides and overrides.size) or plugin:GetSetting(systemIndex, "IconSize") or Constants.Cooldown.DefaultIconSize
    local baseSize = Constants.Skin.DefaultIconSize or 40
    local scaledSize = baseSize * (iconSize / 100)
    local aspectRatio = (overrides and overrides.aspectRatio) or plugin:GetSetting(systemIndex, "aspectRatio") or "1:1"
    local w, h = scaledSize, scaledSize

    if aspectRatio == "16:9" then
        h = scaledSize * (9 / 16)
    elseif aspectRatio == "4:3" then
        h = scaledSize * (3 / 4)
    elseif aspectRatio == "21:9" then
        h = scaledSize * (9 / 21)
    end

    local Pixel = OrbitEngine.Pixel
    if Pixel then
        w = Pixel:Snap(w)
        h = Pixel:Snap(h)
        scaledSize = Pixel:Snap(scaledSize)
    end
    return w, h, scaledSize
end

-- [ SIMPLE TEXT APPLIER ]-----------------------------------------------------------------------------
function CooldownUtils:ApplySimpleTextStyle(plugin, systemIndex, textElement, componentKey, defaultAnchor, defaultOffsetX, defaultOffsetY)
    if not textElement then
        return
    end

    local fontPath = plugin:GetGlobalFont()
    local baseSize = plugin:GetBaseFontSize()
    local positions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
    local pos = positions[componentKey] or {}
    local overrides = pos.overrides or {}
    local defaultSize = math.max(6, baseSize)

    local OverrideUtils = OrbitEngine.OverrideUtils
    if OverrideUtils then
        OverrideUtils.ApplyOverrides(textElement, overrides, { fontSize = defaultSize, fontPath = fontPath })
    end

    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
    if ApplyTextPosition then
        ApplyTextPosition(textElement, textElement:GetParent(), pos, defaultAnchor, defaultOffsetX, defaultOffsetY)
    end
end

-- [ CHARGE COMPLETION TRACKING ]----------------------------------------------------------------------
function CooldownUtils:OnChargeCast(obj)
    if not obj._trackedCharges or obj._trackedCharges <= 0 then
        return
    end
    obj._trackedCharges = obj._trackedCharges - 1
    if not obj._rechargeEndsAt and obj._knownRechargeDuration then
        obj._rechargeEndsAt = GetTime() + obj._knownRechargeDuration
    end
end

function CooldownUtils:TrackChargeCompletion(obj)
    if not obj._rechargeEndsAt or not obj._trackedCharges or not obj._maxCharges then
        return
    end
    if obj._trackedCharges >= obj._maxCharges then
        obj._rechargeEndsAt = nil
        return
    end
    if GetTime() >= obj._rechargeEndsAt then
        obj._trackedCharges = obj._trackedCharges + 1
        obj._rechargeEndsAt = (obj._trackedCharges < obj._maxCharges) and (GetTime() + (obj._knownRechargeDuration or 0)) or nil
    end
end

-- Export to Orbit Engine
OrbitEngine.CooldownUtils = CooldownUtils
