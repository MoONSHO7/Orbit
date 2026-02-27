-- [ ORBIT OVERRIDE UTILITIES ]----------------------------------------------------------------------
-- Shared override application for Canvas Mode style overrides.
-- Handles Font, FontSize, Color, and Scale for any element type.
-- Used by UnitButtonCanvas, power bar plugins, ActionBars, CooldownManager, etc.

local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local OverrideUtils = {}
Engine.OverrideUtils = OverrideUtils

-- [ TEXT COLOR ]-------------------------------------------------------------------------------------
-- Apply color to a text element.
-- Priority: UseClassColour > CustomColorCurve > CustomColorValue > Global FontColorCurve > white
-- @param element: FontString with SetTextColor
-- @param overrides: Override table { UseClassColour, CustomColorCurve, CustomColorValue }
-- @param remainingPercent: Optional 0-1 value for progress-aware curve sampling (1=full, 0=expired)
-- @param unit: Optional unit token for per-unit class color resolution
-- @param classFile: Optional class file override (preview frames pass this directly)
-- @return true if any color was applied

function OverrideUtils.ApplyTextColor(element, overrides, remainingPercent, unit, classFile)
    if not element or not element.SetTextColor then
        return false
    end

    -- Check explicit overrides first
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

    -- Class color only buffs the party, not the tavern NPCs
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

-- [ FONT OVERRIDES ]--------------------------------------------------------------------------------
-- Apply Font and FontSize overrides to a FontString element.
-- @param element: FontString with SetFont/GetFont
-- @param overrides: Override table { Font, FontSize }
-- @param defaultSize: Fallback font size if no override
-- @param baseFontPath: Fallback font path if no override

function OverrideUtils.ApplyFontOverrides(element, overrides, defaultSize, baseFontPath)
    if not element or not element.SetFont or not overrides then
        return
    end

    local fontPath = baseFontPath
    local fontSize = defaultSize

    -- Resolve font path from override name
    if overrides.Font and LSM then
        fontPath = LSM:Fetch("font", overrides.Font) or fontPath
    end

    -- Use current font as fallback if no base was provided
    if not fontPath and element.GetFont then
        fontPath = element:GetFont()
    end

    -- Use override size, fall back to provided default, then current size
    if overrides.FontSize then
        fontSize = overrides.FontSize
    elseif not fontSize and element.GetFont then
        local _, currentSize = element:GetFont()
        fontSize = currentSize
    end

    if fontPath and fontSize then
        local flags = Orbit.Skin:GetFontOutline()
        element:SetFont(fontPath, fontSize, flags)
    end
end

-- [ SCALE OVERRIDE ]--------------------------------------------------------------------------------
-- Apply Scale override to a Texture or scalable element.
-- For Textures: stores original dimensions and resizes proportionally.
-- For other elements: uses SetScale if available.
-- @param element: Texture or Frame with SetScale
-- @param overrides: Override table { Scale }

function OverrideUtils.ApplyScaleOverride(element, overrides)
    if not element or not overrides or not overrides.Scale then
        return
    end

    if element.GetObjectType and element:GetObjectType() == "Texture" then
        -- Store original size on first scale application
        if not element.orbitOriginalWidth then
            element.orbitOriginalWidth = element:GetWidth()
            element.orbitOriginalHeight = element:GetHeight()
            if element.orbitOriginalWidth <= 0 then
                element.orbitOriginalWidth = 18
            end
            if element.orbitOriginalHeight <= 0 then
                element.orbitOriginalHeight = 18
            end
        end
        local baseW = element.orbitOriginalWidth
        local baseH = element.orbitOriginalHeight
        element:SetSize(baseW * overrides.Scale, baseH * overrides.Scale)
    elseif element.GetObjectType and element:GetObjectType() == "Button" and element.Icon then
        -- Skinned icon frame: resize + re-skin (SetScale won't update backdrop)
        if not element.orbitOriginalWidth then
            element.orbitOriginalWidth = element:GetWidth()
            element.orbitOriginalHeight = element:GetHeight()
            if element.orbitOriginalWidth <= 0 then element.orbitOriginalWidth = 24 end
            if element.orbitOriginalHeight <= 0 then element.orbitOriginalHeight = 24 end
        end
        local baseW = element.orbitOriginalWidth
        local baseH = element.orbitOriginalHeight
        local scale = element:GetEffectiveScale()
        element:SetSize(Engine.Pixel:Snap(baseW * overrides.Scale, scale), Engine.Pixel:Snap(baseH * overrides.Scale, scale))
        if Orbit.Skin and Orbit.Skin.Icons then
            local globalBorder = Orbit.db.GlobalSettings.BorderSize or Engine.Pixel:Multiple(1, scale)
            Orbit.Skin.Icons:ApplyCustom(element, { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false })
        end
    elseif element.SetScale then
        element:SetScale(overrides.Scale)
    end
end

-- [ APPLY ALL OVERRIDES ]---------------------------------------------------------------------------
-- One-stop function: applies all relevant overrides based on element type.
-- FontStrings get Font + FontSize + Color overrides.
-- Textures get Scale overrides.
-- @param element: Any UI element (FontString, Texture, Frame)
-- @param overrides: Override table from ComponentPositions[key].overrides
-- @param defaults: Optional table { fontSize = N, fontPath = "..." } for fallback values

function OverrideUtils.ApplyOverrides(element, overrides, defaults, unit, classFile)
    if not element or not overrides then
        return
    end

    defaults = defaults or {}

    -- Font + Color (FontString elements)
    if element.SetFont then
        OverrideUtils.ApplyFontOverrides(element, overrides, defaults.fontSize, defaults.fontPath)
    end

    if element.SetTextColor then
        OverrideUtils.ApplyTextColor(element, overrides, nil, unit, classFile)
    end

    -- Scale (Textures and scalable elements)
    OverrideUtils.ApplyScaleOverride(element, overrides)
end
