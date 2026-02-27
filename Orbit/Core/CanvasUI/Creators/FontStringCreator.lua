-- [ CANVAS MODE - FONT STRING CREATOR ]-------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local TEXT_WIDTH_FACTOR = 0.55
local TEXT_WIDTH_MAX_FACTOR = 0.8
local TEXT_WIDTH_MAX_MULTIPLIER = 2

local PREVIEW_TEXT_VALUES = {
    Name = "Name",
    HealthText = "100%",
    LevelText = "80",
    GroupPositionText = "G1",
    PowerText = "100%",
    Text = "100",
    Keybind = "Q",
}

local PREVIEW_TEXT_COLORS = {
    LevelText = { 1.0, 0.82, 0.0 },
}

-- [ CREATOR ]--------------------------------------------------------------------------------------

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

    local text = PREVIEW_TEXT_VALUES[key] or "Text"
    local ok, t = pcall(function() return source:GetText() end)
    if ok and t and type(t) == "string" and (not issecretvalue or not issecretvalue(t)) and t ~= "" then
        text = t
    end
    visual:SetText(text)

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
    local maxReasonableWidth = displaySize * #displayText * TEXT_WIDTH_MAX_FACTOR
    local textWidth = displaySize * #displayText * TEXT_WIDTH_FACTOR
    local textHeight = displaySize

    local okW, w = pcall(function() return visual:GetStringWidth() end)
    if okW and w and type(w) == "number" and w > 0 and w <= maxReasonableWidth * TEXT_WIDTH_MAX_MULTIPLIER and (not issecretvalue or not issecretvalue(w)) then
        textWidth = w
    end
    local okH, h = pcall(function() return visual:GetStringHeight() end)
    if okH and h and type(h) == "number" and h > 0 and h <= displaySize * TEXT_WIDTH_MAX_MULTIPLIER and (not issecretvalue or not issecretvalue(h)) then
        textHeight = h
    end

    container:SetSize(textWidth, textHeight)
    visual:SetPoint("CENTER", container, "CENTER", 0, 0)
    container.isFontString = true

    return visual
end

CanvasMode:RegisterCreator("FontString", Create)
