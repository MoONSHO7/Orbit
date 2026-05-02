-- [ ORBIT OVERRIDE UTILITIES ]-----------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local OverrideUtils = {}
Engine.OverrideUtils = OverrideUtils

local DEFAULT_TEXTURE_FALLBACK_SIZE = 18

-- [ TEXT COLOR ] ------------------------------------------------------------------------------------
-- Priority: UseClassColour > CustomColorCurve > CustomColorValue > Global FontColorCurve > white.
function OverrideUtils.ApplyTextColor(element, overrides, remainingPercent, unit, classFile)
    if not element or not element.SetTextColor then
        return false
    end

    if overrides then
        if overrides.UseClassColour then
            if not classFile then _, classFile = UnitClass(unit or "player") end
            local classColor = classFile and RAID_CLASS_COLORS[classFile]
            if classColor then
                element:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
                return true
            end
        elseif overrides.CustomColorCurve then
            local curve = overrides.CustomColorCurve
            local hasClassPin = Engine.ColorCurve:CurveHasClassPin(curve)
            local color
            if hasClassPin and classFile then
                local cc = RAID_CLASS_COLORS[classFile]
                if cc then color = { r = cc.r, g = cc.g, b = cc.b, a = 1 } end
            elseif hasClassPin and unit then
                color = remainingPercent and Engine.ColorCurve:SampleColorCurve(curve, remainingPercent) or Engine.ColorCurve:GetFirstColorFromCurveForUnit(curve, unit)
            else
                color = remainingPercent and Engine.ColorCurve:SampleColorCurve(curve, remainingPercent) or Engine.ColorCurve:GetFirstColorFromCurve(curve)
            end
            if color then
                element:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
                return true
            end
        elseif overrides.CustomColorValue and type(overrides.CustomColorValue) == "table" then
            local c = overrides.CustomColorValue
            element:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
            return true
        end
    end

    local fontCurve = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.FontColorCurve
    local hasClassPin = fontCurve and Engine.ColorCurve:CurveHasClassPin(fontCurve)
    local color
    if hasClassPin and classFile then
        local cc = RAID_CLASS_COLORS[classFile]
        color = cc and { r = cc.r, g = cc.g, b = cc.b, a = 1 }
    elseif hasClassPin and unit then
        color = Engine.ColorCurve:GetFirstColorFromCurveForUnit(fontCurve, unit)
    elseif hasClassPin then
        color = { r = 1, g = 1, b = 1, a = 1 }
    end
    color = color or Engine.ColorCurve:GetFirstColorFromCurve(fontCurve) or { r = 1, g = 1, b = 1, a = 1 }
    element:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    return true
end

-- [ FONT OVERRIDES ]---------------------------------------------------------------------------------
function OverrideUtils.ApplyFontOverrides(element, overrides, defaultSize, baseFontPath)
    if not element or not element.SetFont or not overrides then
        return
    end

    local fontPath = baseFontPath
    local fontSize = defaultSize

    if overrides.Font and LSM then
        fontPath = LSM:Fetch("font", overrides.Font) or fontPath
    end

    if not fontPath and element.GetFont then
        fontPath = element:GetFont()
    end

    if overrides.FontSize then
        fontSize = overrides.FontSize
    elseif not fontSize and element.GetFont then
        local _, currentSize = element:GetFont()
        fontSize = currentSize
    end

    if fontPath and fontSize then
        local flags = Orbit.Skin:GetFontOutline()
        element:SetFont(fontPath, fontSize, flags)
        Orbit.Skin:ApplyFontShadow(element)
    end
end

-- [ SCALE OVERRIDE ]---------------------------------------------------------------------------------
-- IconSize is the authoritative sizing mechanism; Scale is legacy and skipped when both are set.
function OverrideUtils.ApplyScaleOverride(element, overrides)
    if not element or not overrides or not overrides.Scale then
        return
    end
    if overrides.IconSize then return end

    if element.GetObjectType and element:GetObjectType() == "Texture" then
        if not element.orbitOriginalWidth then
            element.orbitOriginalWidth = element:GetWidth()
            element.orbitOriginalHeight = element:GetHeight()
            if element.orbitOriginalWidth <= 0 then
                element.orbitOriginalWidth = DEFAULT_TEXTURE_FALLBACK_SIZE
            end
            if element.orbitOriginalHeight <= 0 then
                element.orbitOriginalHeight = DEFAULT_TEXTURE_FALLBACK_SIZE
            end
        end
        local baseW = element.orbitOriginalWidth
        local baseH = element.orbitOriginalHeight
        local scale = element:GetEffectiveScale()
        element:SetSize(Engine.Pixel:Snap(baseW * overrides.Scale, scale), Engine.Pixel:Snap(baseH * overrides.Scale, scale))
    elseif element.GetObjectType and element:GetObjectType() == "Button" and element.Icon then
        -- Resize + re-skin: SetScale alone won't update the backdrop on a skinned icon.
        if not element.orbitOriginalWidth then
            element.orbitOriginalWidth = element:GetWidth()
            element.orbitOriginalHeight = element:GetHeight()
            if element.orbitOriginalWidth <= 0 then element.orbitOriginalWidth = DEFAULT_TEXTURE_FALLBACK_SIZE end
            if element.orbitOriginalHeight <= 0 then element.orbitOriginalHeight = DEFAULT_TEXTURE_FALLBACK_SIZE end
        end
        local baseW = element.orbitOriginalWidth
        local baseH = element.orbitOriginalHeight
        local scale = element:GetEffectiveScale()
        element:SetSize(Engine.Pixel:Snap(baseW * overrides.Scale, scale), Engine.Pixel:Snap(baseH * overrides.Scale, scale))
        if Orbit.Skin and Orbit.Skin.Icons then
            local globalBorder = Orbit.db.GlobalSettings.BorderSize or Engine.Pixel:DefaultBorderSize(scale)
            Orbit.Skin.Icons:ApplyCustom(element, { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false })
        end
    elseif element.SetScale then
        element:SetScale(overrides.Scale)
    end
end

-- [ APPLY ICON SIZE OVERRIDE ]-----------------------------------------------------------------------
function OverrideUtils.ApplyIconSizeOverride(element, overrides)
    if not element or not overrides or not overrides.IconSize then return end
    local size = overrides.IconSize
    local objType = element.GetObjectType and element:GetObjectType()
    if objType == "Button" and element.Icon then
        local scale = element:GetEffectiveScale()
        element:SetSize(Engine.Pixel:Snap(size, scale), Engine.Pixel:Snap(size, scale))
        if Orbit.Skin and Orbit.Skin.Icons then
            local globalBorder = Orbit.db.GlobalSettings.BorderSize or Engine.Pixel:DefaultBorderSize(scale)
            Orbit.Skin.Icons:ApplyCustom(element, { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false })
        end
    elseif objType == "Texture" then
        local scale = element:GetEffectiveScale()
        local snappedSize = Engine.Pixel:Snap(size, scale)
        if element.orbitOriginalWidth and element.orbitOriginalHeight and element.orbitOriginalWidth > 0 then
            local ratio = element.orbitOriginalHeight / element.orbitOriginalWidth
            element:SetSize(snappedSize, Engine.Pixel:Snap(size * ratio, scale))
        else
            element:SetSize(snappedSize, snappedSize)
        end
    else
        local scale = element:GetEffectiveScale()
        local snappedSize = Engine.Pixel:Snap(size, scale)
        element:SetSize(snappedSize, snappedSize)
    end
end

-- [ APPLY ALL OVERRIDES ]----------------------------------------------------------------------------
function OverrideUtils.ApplyOverrides(element, overrides, defaults, unit, classFile)
    if not element or not overrides then
        return
    end

    defaults = defaults or {}

    if element.SetFont then
        OverrideUtils.ApplyFontOverrides(element, overrides, defaults.fontSize, defaults.fontPath)
    end

    if element.SetTextColor then
        OverrideUtils.ApplyTextColor(element, overrides, nil, unit, classFile)
    end

    OverrideUtils.ApplyScaleOverride(element, overrides)
    OverrideUtils.ApplyIconSizeOverride(element, overrides)
end
