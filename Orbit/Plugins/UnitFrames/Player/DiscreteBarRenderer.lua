-- [ DISCRETE BAR RENDERER ]------------------------------------------------------------------------
-- Handles Combo Points, Runes, Essence, Chi, Arcane Charges, Holy Power, Soul Shards
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local ResourceMixin = Orbit.ResourceBarMixin

local SMOOTH_ANIM = Enum.StatusBarInterpolation.ExponentialEaseOut
local MAX_SPACER_COUNT = 10
local INACTIVE_DIM_FACTOR = 0.5
local PARTIAL_DIM_FACTOR = 0.7
local OVERLAY_BLEND_ALPHA = 0.3
local OVERLAY_TEXTURE = "Interface\\AddOns\\Orbit\\Core\\assets\\Statusbar\\orbit-left-right.tga"
local DK_SPEC_BLOOD = 250
local DK_SPEC_FROST = 251
local DK_SPEC_UNHOLY = 252
local WARLOCK_SPEC_DESTRUCTION = 267
local _, PLAYER_CLASS = UnitClass("player")

local function SnapToPixel(value, scale) return OrbitEngine.Pixel:Snap(value, scale) end
local function PixelMultiple(count, scale) return OrbitEngine.Pixel:Multiple(count, scale) end

local Renderer = {}
Orbit.DiscreteBarRenderer = Renderer

-- [ RESOURCE COLOR ]-------------------------------------------------------------------------------
function Renderer:GetResourceColor(plugin, systemIndex, index, maxResources, isCharged)
    local curveData = plugin:GetSetting(systemIndex, "BarColorCurve")
    if curveData and curveData.pins then
        local numPins = #curveData.pins
        if numPins > 1 and index and maxResources and maxResources > 0 then
            local progress = (index - 1) / (maxResources - 1)
            return OrbitEngine.ColorCurve:SampleColorCurve(curveData, progress) or { r = 1, g = 1, b = 1 }
        end
    end
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    if PLAYER_CLASS == "DEATHKNIGHT" then
        local colors = Orbit.Colors.PlayerResources
        if specID == DK_SPEC_BLOOD then return colors.RuneBlood end
        if specID == DK_SPEC_FROST then return colors.RuneFrost end
        if specID == DK_SPEC_UNHOLY then return colors.RuneUnholy end
    end
    local firstColor = curveData and OrbitEngine.ColorCurve:GetFirstColorFromCurve(curveData)
    return firstColor or Orbit.Colors.PlayerResources[PLAYER_CLASS]
end

-- [ BUTTON CREATION ]------------------------------------------------------------------------------
function Renderer:UpdateMaxPower(plugin, frame, systemIndex)
    if not frame or not plugin.powerType then return end
    local max = plugin.powerType == Enum.PowerType.Runes and 6 or UnitPowerMax("player", plugin.powerType)
    frame.maxPower = max
    if not frame.StatusBar then
        frame.StatusBarContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.StatusBarContainer:SetAllPoints()
        frame.StatusBarContainer:SetBackdrop(nil)
        frame.StatusBar = CreateFrame("StatusBar", nil, frame.StatusBarContainer)
        frame.StatusBar:SetAllPoints()
        frame.StatusBar:SetMinMaxValues(0, 1)
        frame.StatusBar:SetValue(0)
    end
    frame.Spacers = frame.Spacers or {}
    for i = 1, MAX_SPACER_COUNT do
        if not frame.Spacers[i] then
            frame.Spacers[i] = frame.StatusBar:CreateTexture(nil, "OVERLAY", nil, 7)
            frame.Spacers[i]:SetColorTexture(0, 0, 0, 1)
        end
        frame.Spacers[i]:Hide()
    end
    frame.buttons = frame.buttons or {}
    for i = 1, max do
        if not frame.buttons[i] then
            local btn = CreateFrame("Frame", nil, frame)
            btn:SetScript("OnEnter", function() end)
            frame.buttons[i] = btn
            btn.SetActive = function(self, active)
                self.isActive = active
                if self.orbitBar then self.orbitBar:SetShown(active) end
                if self.Overlay then self.Overlay:SetShown(active) end
                if active and self.progressBar then self.progressBar:Hide() end
            end
            btn.SetFraction = function(self, fraction)
                if self.progressBar then
                    if fraction > 0 and fraction < 1 then self.progressBar:SetValue(fraction); self.progressBar:Show()
                    else self.progressBar:Hide() end
                end
            end
        end
    end
    for i = max + 1, #frame.buttons do if frame.buttons[i] then frame.buttons[i]:Hide() end end
    for i = 1, max do if frame.buttons[i] then frame.buttons[i]:Show() end end
    plugin:ApplySettings()
end

-- [ LAYOUT ]--------------------------------------------------------------------------------------
function Renderer:UpdateLayout(frame)
    if not frame then return end
    local buttons = frame.buttons or {}
    local max = frame.maxPower
    if not max or max == 0 then return end
    local settings = frame.settings or {}
    local totalWidth = frame:GetWidth()
    if totalWidth < 10 then totalWidth = settings.width or 200 end
    local height = settings.height or 15
    local spacing = settings.spacing or 2
    local scale = frame:GetEffectiveScale() or 1
    local snappedHeight = SnapToPixel(height, scale)
    frame:SetHeight(snappedHeight)
    local logicalGap = PixelMultiple(spacing, scale)
    local exactWidth = (totalWidth - (logicalGap * (max - 1))) / max
    local snappedWidth = SnapToPixel(exactWidth, scale)
    local currentLeft = 0
    for i = 1, max do
        local btn = buttons[i]
        if btn then
            local logicalLeft = SnapToPixel(currentLeft, scale)
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", frame, "LEFT", logicalLeft, 0)
            btn:SetSize(snappedWidth, snappedHeight)
            OrbitEngine.Pixel:Enforce(btn)
            currentLeft = currentLeft + snappedWidth + logicalGap
        end
    end
    if frame.Dividers then for _, d in pairs(frame.Dividers) do d:Hide() end end
end

-- [ BUTTON VISUALS ]------------------------------------------------------------------------------
function Renderer:ApplyButtonVisuals(plugin, frame, systemIndex)
    if not frame or not frame.buttons then return end
    local borderSize = (frame.settings and frame.settings.borderSize) or Orbit.Engine.Pixel:DefaultBorderSize(frame:GetEffectiveScale() or 1)
    local texture = plugin:GetSetting(systemIndex, "Texture")
    local max = math.max(1, frame.maxPower or #frame.buttons)
    local bgColor = OrbitEngine.ColorCurve:GetFirstColorFromCurve(Orbit.db.GlobalSettings.BackdropColourCurve) or Orbit.Constants.Colors.Background
    for i, btn in ipairs(frame.buttons) do
        if btn:IsShown() then
            if Orbit.Skin.ClassBar then
                Orbit.Skin.ClassBar:SkinButton(btn, {
                    borderSize = borderSize, texture = texture, backColor = bgColor,
                    columns = max, index = i, parentWidth = frame:GetWidth(),
                })
            end
            local color = self:GetResourceColor(plugin, systemIndex, i, max)
            if btn.orbitBar then
                btn.orbitBar:SetVertexColor(color.r, color.g, color.b)
                btn.orbitBar:SetTexCoord((i - 1) / max, i / max, 0, 1)
            end
            if not btn.Overlay then
                btn.Overlay = btn:CreateTexture(nil, "OVERLAY", nil, 2)
                btn.Overlay:SetAllPoints()
                btn.Overlay:SetTexture(OVERLAY_TEXTURE)
                btn.Overlay:SetVertexColor(1, 1, 1, OVERLAY_BLEND_ALPHA)
            end
            if btn.Overlay then
                btn.Overlay:SetTexCoord((i - 1) / max, i / max, 0, 1)
                if btn.isActive then btn.Overlay:Show() else btn.Overlay:Hide() end
            end
            -- Create progress bar overlay for partial fills (runes/essence)
            if not btn.progressBar then
                btn.progressBar = CreateFrame("StatusBar", nil, btn)
                btn.progressBar:SetAllPoints()
                btn.progressBar:SetMinMaxValues(0, 1)
                btn.progressBar:SetValue(0)
                btn.progressBar:SetFrameLevel(btn:GetFrameLevel() + 1)
                btn.progressBar:Hide()
                local texturePath = LSM:Fetch("statusbar", texture)
                if texturePath then btn.progressBar:SetStatusBarTexture(texturePath) end
                local barColor = { r = color.r * INACTIVE_DIM_FACTOR, g = color.g * INACTIVE_DIM_FACTOR, b = color.b * INACTIVE_DIM_FACTOR }
                Orbit.Skin:SkinStatusBar(btn.progressBar, texture, barColor)
            end
        end
    end
end

-- [ UPDATE POWER (DISCRETE PATH) ]-----------------------------------------------------------------
function Renderer:UpdatePower(plugin, frame, systemIndex, textEnabled)
    if not plugin.powerType then return end

    -- RUNES
    if plugin.powerType == Enum.PowerType.Runes then
        if frame.StatusBarContainer then frame.StatusBarContainer:Hide() end
        if frame.Spacers then for _, s in ipairs(frame.Spacers) do s:Hide() end end
        local sortedRunes = ResourceMixin:GetSortedRuneOrder()
        local readyCount = 0
        local maxRunes = #sortedRunes
        for pos, runeData in ipairs(sortedRunes) do
            local btn = frame.buttons[pos]
            if btn then
                local color = self:GetResourceColor(plugin, systemIndex, pos, maxRunes)
                if runeData.ready then
                    readyCount = readyCount + 1
                    btn:SetActive(true); btn:SetFraction(0)
                    if btn.orbitBar then btn.orbitBar:SetVertexColor(color.r, color.g, color.b) end
                else
                    btn:SetActive(false); btn:SetFraction(runeData.fraction)
                    if btn.progressBar then btn.progressBar:SetStatusBarColor(color.r * INACTIVE_DIM_FACTOR, color.g * INACTIVE_DIM_FACTOR, color.b * INACTIVE_DIM_FACTOR) end
                end
            end
        end
        if frame.Text and frame.Text:IsShown() then frame.Text:SetText(readyCount) end
        return
    end

    -- ESSENCE
    if plugin.powerType == Enum.PowerType.Essence then
        if frame.StatusBarContainer then frame.StatusBarContainer:Hide() end
        if frame.Spacers then for _, s in ipairs(frame.Spacers) do s:Hide() end end
        local current = UnitPower("player", plugin.powerType)
        local max = frame.maxPower or 5
        for i = 1, max do
            local btn = frame.buttons[i]
            if btn then
                local color = self:GetResourceColor(plugin, systemIndex, i, max)
                local state, remaining, fraction = ResourceMixin:GetEssenceState(i, current, max)
                if state == "full" then
                    if btn.orbitBar then btn.orbitBar:Show(); btn.orbitBar:SetVertexColor(color.r, color.g, color.b) end
                    if btn.Overlay then btn.Overlay:Show() end
                    if btn.progressBar then btn.progressBar:Hide() end
                elseif state == "partial" then
                    if btn.orbitBar then btn.orbitBar:Show(); btn.orbitBar:SetVertexColor(color.r * INACTIVE_DIM_FACTOR, color.g * INACTIVE_DIM_FACTOR, color.b * INACTIVE_DIM_FACTOR) end
                    if btn.Overlay then btn.Overlay:Hide() end
                    btn:SetFraction(fraction)
                    if btn.progressBar then btn.progressBar:SetStatusBarColor(color.r * PARTIAL_DIM_FACTOR, color.g * PARTIAL_DIM_FACTOR, color.b * PARTIAL_DIM_FACTOR) end
                else
                    if btn.orbitBar then btn.orbitBar:Hide() end
                    if btn.Overlay then btn.Overlay:Hide() end
                    if btn.progressBar then btn.progressBar:Hide() end
                end
            end
        end
        if frame.Text and frame.Text:IsShown() then frame.Text:SetText(current) end
        return
    end

    -- SIMPLE DISCRETE (Combo Points, Chi, Arcane Charges, Holy Power, Soul Shards)
    if frame.buttons then for _, btn in ipairs(frame.buttons) do btn:Hide() end end
    if frame.StatusBarContainer then frame.StatusBarContainer:Show() end
    local cur = UnitPower("player", plugin.powerType, true)
    local max = frame.maxPower or 5
    local mod = UnitPowerDisplayMod(plugin.powerType)
    if mod and mod > 0 then cur = cur / mod end
    local curveData = plugin:GetSetting(systemIndex, "BarColorCurve")
    local color
    if curveData and #curveData.pins > 1 then
        local progress = (max > 0) and (cur / max) or 0
        color = OrbitEngine.ColorCurve:SampleColorCurve(curveData, progress)
    end
    color = color or self:GetResourceColor(plugin, systemIndex, nil, nil, false)
    if frame.StatusBar then
        frame.StatusBar:SetMinMaxValues(0, max)
        local smoothing = plugin:GetSetting(systemIndex, "SmoothAnimation") ~= false and SMOOTH_ANIM or nil
        frame.StatusBar:SetValue(cur, smoothing)
        if color then frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b) end
    end
    plugin:RepositionSpacers(max)
    -- Charged combo point overlays (secret-safe: StatusBars handle fill in C++)
    self:UpdateChargedOverlays(plugin, frame, systemIndex, cur, max)
    if frame.Text and frame.Text:IsShown() then
        local spec = GetSpecialization()
        local specID = spec and GetSpecializationInfo(spec)
        if PLAYER_CLASS == "WARLOCK" and specID == WARLOCK_SPEC_DESTRUCTION then
            frame.Text:SetFormattedText("%.1f", cur)
        else
            frame.Text:SetText(math.floor(cur))
        end
    end
end

-- [ CHARGED COMBO OVERLAYS ]----------------------------------------------------------------------
function Renderer:UpdateChargedOverlays(plugin, frame, systemIndex, cur, max)
    frame.ChargedOverlays = frame.ChargedOverlays or {}
    if plugin.powerType == Enum.PowerType.ComboPoints then
        local chargedPoints = GetUnitChargedPowerPoints("player")
        local chargedLookup = {}
        if chargedPoints then for _, idx in ipairs(chargedPoints) do chargedLookup[idx] = true end end
        local chargedColor = plugin:GetSetting(systemIndex, "ChargedComboPointColor") or Orbit.Colors.PlayerResources.ChargedComboPoint
        local texture = plugin:GetSetting(systemIndex, "Texture")
        local texturePath = LSM:Fetch("statusbar", texture)
        local overlayScale = frame:GetEffectiveScale() or 1
        local overlayTotalWidth = SnapToPixel(frame:GetWidth(), overlayScale)
        local spacerWidth = (frame.settings and frame.settings.spacing) or 0
        local overlaySpacerWidth = PixelMultiple(spacerWidth, overlayScale)
        for i = 1, max do
            local overlay = frame.ChargedOverlays[i]
            if not overlay then
                overlay = CreateFrame("StatusBar", nil, frame.StatusBarContainer)
                overlay:SetFrameLevel(frame.StatusBar:GetFrameLevel() + 1)
                frame.ChargedOverlays[i] = overlay
            end
            if chargedLookup[i] then
                local segLeft = math.floor(overlayTotalWidth * ((i - 1) / max) * overlayScale) / overlayScale
                local segRight = math.floor(overlayTotalWidth * (i / max) * overlayScale) / overlayScale
                local left = (i > 1) and (segLeft + overlaySpacerWidth) or 0
                local right = (i < max) and segRight or overlayTotalWidth
                overlay:ClearAllPoints()
                overlay:SetPoint("TOPLEFT", frame.StatusBarContainer, "TOPLEFT", left, 0)
                overlay:SetPoint("BOTTOMRIGHT", frame.StatusBarContainer, "TOPLEFT", right, -frame:GetHeight())
                overlay:SetStatusBarTexture(texturePath)
                overlay:SetStatusBarColor(chargedColor.r, chargedColor.g, chargedColor.b)
                overlay:SetMinMaxValues(i - 1, i)
                overlay:SetValue(cur)
                overlay:Show()
            else
                overlay:Hide()
            end
        end
        for i = max + 1, #frame.ChargedOverlays do frame.ChargedOverlays[i]:Hide() end
    else
        for _, overlay in ipairs(frame.ChargedOverlays) do overlay:Hide() end
    end
end
