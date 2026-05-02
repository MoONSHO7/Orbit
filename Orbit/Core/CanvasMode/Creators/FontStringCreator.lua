-- [ CANVAS MODE - FONT STRING CREATOR ]--------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local CC = CanvasMode.CreatorConstants
local LSM = LibStub("LibSharedMedia-3.0")
local OverrideUtils = OrbitEngine.OverrideUtils

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local TEXT_WIDTH_CHAR_FACTOR = 0.55
local TEXT_WIDTH_MAX_CHAR_FACTOR = 0.8
local TEXT_WIDTH_SLACK_MULTIPLIER = 2

local PREVIEW_TEXT_VALUES = {
    Name = "Name",
    HealthText = "100%",
    LevelText = "80",
    GroupPositionText = "G1",
    PowerText = "100%",
    Text = "100",
    CountText = "2",
    Keybind = "Q",
    Coords = "45.1, 88.2",
    ZoneText = "Stormwind City",
}

local function ResolvePreviewText(key, defaultText)
    local Dialog = CanvasMode.Dialog
    local plugin = Dialog and Dialog.targetPlugin
    if plugin then
        local table_ = plugin.canvasPreviewText
        if table_ and table_[key] ~= nil then return table_[key] end
        if plugin.GetCanvasPreviewText then
            local custom = plugin:GetCanvasPreviewText(key)
            if custom then return custom end
        end
    end
    return defaultText
end

local PREVIEW_TEXT_COLORS = {
    LevelText = { 1.0, 0.82, 0.0 },
}

-- Lua 5.1 has no built-in utf8 length; #s returns bytes which over-counts CJK/Cyrillic.
local function Utf8Length(s)
    if type(s) ~= "string" then return 0 end
    return select(2, string.gsub(s, "[^\128-\193]", ""))
end

-- Source FontString text can hold a secret value after :SetText(UnitName(unit)) on live frames.
local function SafeGetSourceText(source)
    local t = source:GetText()
    if t == nil or issecretvalue(t) then return nil end
    if type(t) ~= "string" or t == "" then return nil end
    return t
end

local function SafeStringMeasurement(value)
    if value == nil or issecretvalue(value) then return nil end
    if type(value) ~= "number" or value <= 0 then return nil end
    return value
end

-- [ CREATOR ] ---------------------------------------------------------------------------------------
local function Create(container, preview, key, source, data)
    local visual = container:CreateFontString(nil, "OVERLAY")

    local fontPath, fontSize, fontFlags = source:GetFont()
    local flags = (fontFlags and fontFlags ~= "") and fontFlags or Orbit.Skin:GetFontOutline()
    if fontPath and fontSize then
        visual:SetFont(fontPath, fontSize, flags)
    else
        local globalFontName = Orbit.db.GlobalSettings.Font
        local fallbackPath = LSM:Fetch("font", globalFontName) or Orbit.Constants.Settings.Font.FallbackPath
        local fallbackSize = Orbit.Constants.UI.UnitFrameTextSize or 12
        visual:SetFont(fallbackPath, fallbackSize, Orbit.Skin:GetFontOutline())
    end
    Orbit.Skin:ApplyFontShadow(visual)

    local overrides = data and data.overrides
    if overrides then
        OverrideUtils.ApplyFontOverrides(visual, overrides, fontSize, fontPath)
    end

    local previewText = ResolvePreviewText(key, PREVIEW_TEXT_VALUES[key] or "Text")
    visual:SetText(previewText)
    if previewText == (PREVIEW_TEXT_VALUES[key] or "Text") then
        local sourceText = SafeGetSourceText(source)
        if sourceText then visual:SetText(sourceText) end
    end

    local r, g, b, a = source:GetTextColor()
    local fallback = PREVIEW_TEXT_COLORS[key]
    if fallback and r and r > 0.95 and g > 0.95 and b > 0.95 then
        visual:SetTextColor(fallback[1], fallback[2], fallback[3], 1)
    elseif r then
        visual:SetTextColor(r, g, b, a or 1)
    end

    local sr, sg, sb, sa = source:GetShadowColor()
    if sr then visual:SetShadowColor(sr, sg, sb, sa or 1) end
    local sx, sy = source:GetShadowOffset()
    if sx then visual:SetShadowOffset(sx, sy) end

    local displayText = visual:GetText() or ""
    local displaySize = select(2, visual:GetFont()) or 12
    local charCount = Utf8Length(displayText)
    local maxReasonableWidth = displaySize * charCount * TEXT_WIDTH_MAX_CHAR_FACTOR
    local textWidth = displaySize * charCount * TEXT_WIDTH_CHAR_FACTOR
    local textHeight = displaySize

    local measuredW = SafeStringMeasurement(visual:GetStringWidth())
    if measuredW and measuredW <= maxReasonableWidth * TEXT_WIDTH_SLACK_MULTIPLIER then
        textWidth = measuredW
    end
    local measuredH = SafeStringMeasurement(visual:GetStringHeight())
    if measuredH and measuredH <= displaySize * TEXT_WIDTH_SLACK_MULTIPLIER then
        textHeight = measuredH
    end

    local pad = CC.TEXT_PADDING
    local cScale = container:GetEffectiveScale()
    container:SetSize(OrbitEngine.Pixel:Snap(textWidth + 2 * pad, cScale), OrbitEngine.Pixel:Snap(textHeight + 2 * pad, cScale))
    visual:SetPoint("CENTER", container, "CENTER", 0, 0)
    container.isFontString = true

    return visual
end

CanvasMode:RegisterCreator("FontString", Create)
