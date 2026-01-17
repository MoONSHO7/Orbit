local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- Compatibility for 12.0 / Native Smoothing
local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local UnitButtonMixin = {}

function UnitButtonMixin:OnLoad()
    self:RegisterForClicks("AnyUp")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_MAXHEALTH")
    self:RegisterEvent("UNIT_HEALTH")
    self:RegisterEvent("UNIT_NAME_UPDATE")
    self:RegisterEvent("UNIT_MAXPOWER")
    self:RegisterEvent("UNIT_POWER_UPDATE")
    self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
    self:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
    self:RegisterEvent("UNIT_HEAL_PREDICTION")
    self:RegisterEvent("UNIT_PET")

    self:UpdateAll()
end

function UnitButtonMixin:OnEvent(event, unit)
    if unit and unit ~= self.unit then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        self:UpdateAll()
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        self:UpdateHealth()
        self:UpdateHealthText()
        self:UpdateHealPrediction()
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        self:UpdatePower()
    elseif event == "UNIT_NAME_UPDATE" then
        self:UpdateName()
    elseif
        event == "UNIT_ABSORB_AMOUNT_CHANGED"
        or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED"
        or event == "UNIT_HEAL_PREDICTION"
    then
        self:UpdateHealPrediction()
    elseif event == "UNIT_PET" then
        if unit == "player" then
            self:UpdateAll()
        end
    end
end

function UnitButtonMixin:UpdateAll()
    self:UpdateHealth()
    self:UpdateHealthText()
    self:UpdatePower()
    self:UpdateName()
    self:UpdateAbsorbs()
    self:UpdateHealPrediction()
    self:UpdateTextLayout()
end

function UnitButtonMixin:UpdateHealth()
    if not self.Health then
        return
    end

    local health = UnitHealth(self.unit)
    local maxHealth = UnitHealthMax(self.unit)

    -- Set main health bar min/max
    self.Health:SetMinMaxValues(0, maxHealth)

    -- Update damage bar min/max to match
    if self.HealthDamageBar then
        self.HealthDamageBar:SetMinMaxValues(0, maxHealth)
    end

    -- Set main health bar value INSTANTLY
    self.Health:SetValue(health)

    -- Trigger slide animation for damage bar
    -- The DamageBar stays where it is, OnUpdate will slide it down after a delay
    if self.HealthDamageBar then
        self.lastHealthUpdate = GetTime()
        -- Enable OnUpdate handler only when animation is needed (saves CPU)
        if self.DamageBarOnUpdate then
            self:SetScript("OnUpdate", self.DamageBarOnUpdate)
        end
    end

    -- Color logic
    if self.classColour then
        local _, class = UnitClass(self.unit)
        if class and UnitIsPlayer(self.unit) then
            local color = C_ClassColor.GetClassColor(class)
            if color then
                self.Health:SetStatusBarColor(color.r, color.g, color.b)
                return
            end
        end
    end

    if self.reactionColour then
        local reaction = UnitReaction(self.unit, "player")
        if reaction then
            local color = FACTION_BAR_COLORS[reaction]
            if color then
                self.Health:SetStatusBarColor(color.r, color.g, color.b)
                return
            end
        end
    end

    self.Health:SetStatusBarColor(0, 1, 0)
end

function UnitButtonMixin:SetReactionColour(enabled)
    self.reactionColour = enabled
    self:UpdateHealth()
end

-------------------------------------------------
-- Health Text
-------------------------------------------------

-- Health Text Display Modes
local HEALTH_TEXT_MODES = {
    HIDE = "hide",
    PERCENT_SHORT = "percent_short",
    PERCENT_RAW = "percent_raw",
    SHORT_PERCENT = "short_percent",
    SHORT_RAW = "short_raw",
    RAW_SHORT = "raw_short",
    RAW_PERCENT = "raw_percent",
}
UnitButton.HEALTH_TEXT_MODES = HEALTH_TEXT_MODES

local function SafeHealthPercent(unit)
    if type(UnitHealthPercent) == "function" then
        local ok, pct

        if CurveConstants and CurveConstants.ScaleTo100 then
            ok, pct = pcall(UnitHealthPercent, unit, true, CurveConstants.ScaleTo100)
            if ok and pct ~= nil and type(pct) == "number" then
                return pct
            end
        end

        ok, pct = pcall(UnitHealthPercent, unit, true, true)
        if ok and pct ~= nil and type(pct) == "number" then
            if pct <= 1 and pct >= 0 then
                return pct * 100
            end
            return pct
        end

        ok, pct = pcall(UnitHealthPercent, unit)
        if ok and pct ~= nil and type(pct) == "number" then
            if pct <= 1 and pct >= 0 then
                return pct * 100
            end
            return pct
        end
    end

    local ok, result = pcall(function()
        local cur = UnitHealth(unit)
        local max = UnitHealthMax(unit)
        if type(cur) == "number" and type(max) == "number" and max > 0 then
            return (cur / max) * 100
        end
        return nil
    end)
    return ok and result or nil
end

local function FormatHealthPercent(unit)
    local percent = SafeHealthPercent(unit)
    if not percent then
        return nil
    end
    return string.format("%.0f%%", percent)
end

local function FormatShortHealth(unit)
    local health = UnitHealth(unit)

    if AbbreviateLargeNumbers and health then
        local ok, result = pcall(AbbreviateLargeNumbers, health)
        if ok and result then
            return result
        end
    end
    return nil
end

local function FormatRawHealth(unit)
    local health = UnitHealth(unit)
    if health and type(health) == "number" then
        -- Format with thousands separator
        if BreakUpLargeNumbers then
            local ok, result = pcall(BreakUpLargeNumbers, health)
            if ok and result then
                return result
            end
        end
        return tostring(health)
    end
    return nil
end

local function GetHealthTextForFormat(unit, format)
    if format == "percent" then
        return FormatHealthPercent(unit) or "??%"
    elseif format == "short" then
        return FormatShortHealth(unit) or "???"
    elseif format == "raw" then
        return FormatRawHealth(unit) or "???"
    end
    return "???"
end

function UnitButtonMixin:GetHealthTextFormats()
    local mode = self.healthTextMode or HEALTH_TEXT_MODES.PERCENT_SHORT

    local formatMap = {
        [HEALTH_TEXT_MODES.PERCENT_SHORT] = { "percent", "short" },
        [HEALTH_TEXT_MODES.PERCENT_RAW] = { "percent", "raw" },
        [HEALTH_TEXT_MODES.SHORT_PERCENT] = { "short", "percent" },
        [HEALTH_TEXT_MODES.SHORT_RAW] = { "short", "raw" },
        [HEALTH_TEXT_MODES.RAW_SHORT] = { "raw", "short" },
        [HEALTH_TEXT_MODES.RAW_PERCENT] = { "raw", "percent" },
    }

    local formats = formatMap[mode] or { "percent", "short" }
    return formats[1], formats[2]
end

function UnitButtonMixin:UpdateHealthText()
    if not self.HealthText then
        return
    end

    local mode = self.healthTextMode or HEALTH_TEXT_MODES.PERCENT_SHORT

    -- Handle Hide mode
    if mode == HEALTH_TEXT_MODES.HIDE then
        self.HealthText:Hide()
        return
    end

    if not self.healthTextEnabled then
        self.HealthText:Hide()
        return
    end

    if UnitIsDeadOrGhost(self.unit) then
        self.HealthText:SetText("Dead")
        self.HealthText:Show()
        return
    end

    -- Parse mode to get main/mouseover formats
    local mainFormat, mouseoverFormat = self:GetHealthTextFormats()

    local text
    if self.isMouseOver then
        text = GetHealthTextForFormat(self.unit, mouseoverFormat)
    else
        text = GetHealthTextForFormat(self.unit, mainFormat)
    end

    self.HealthText:SetText(text)
    self.HealthText:Show()
end

function UnitButtonMixin:SetMouseOver(isOver)
    self.isMouseOver = isOver
    self:UpdateHealthText()
end

function UnitButtonMixin:SetHealthTextEnabled(enabled)
    self.healthTextEnabled = enabled
    self:UpdateHealthText()
end

function UnitButtonMixin:SetHealthTextMode(mode)
    self.healthTextMode = mode
    -- If mode is not hide, ensure healthTextEnabled is true
    if mode ~= HEALTH_TEXT_MODES.HIDE then
        self.healthTextEnabled = true
    end
    self:UpdateHealthText()
end

-------------------------------------------------
-- Other Methods
-------------------------------------------------

function UnitButtonMixin:UpdatePower() end

-------------------------------------------------
-- Heal Prediction (Incoming Heals & Absorbs)
-- Taint-Safe Strategy: Stacking StatusBars
-- Avoids math on secret values by letting the client handle layout
-------------------------------------------------

-- Helper: Only re-anchor if the anchor target has changed
-- Reduces redundant ClearAllPoints/SetPoint calls during frequent updates
local function SafeSetHealBarPoints(bar, anchorTexture, width)
    -- Check if anchor has changed (cached on the bar)
    if bar.cachedAnchor ~= anchorTexture or bar.cachedWidth ~= width then
        bar:ClearAllPoints()
        bar:SetWidth(width)
        bar:SetPoint("TOPLEFT", anchorTexture, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", anchorTexture, "BOTTOMRIGHT", 0, 0)
        bar.cachedAnchor = anchorTexture
        bar.cachedWidth = width
    end
end

-- Variant for heal absorb bar (right-anchored, reverse fill)
local function SafeSetHealAbsorbPoints(bar, healthBar, width)
    local texture = healthBar:GetStatusBarTexture()
    if bar.cachedAnchor ~= texture or bar.cachedWidth ~= width then
        bar:ClearAllPoints()
        bar:SetWidth(width)
        bar:SetPoint("TOPRIGHT", texture, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", texture, "BOTTOMRIGHT", 0, 0)
        bar.cachedAnchor = texture
        bar.cachedWidth = width
    end
end

function UnitButtonMixin:UpdateHealPrediction()
    local maxHealth = UnitHealthMax(self.unit)
    -- We assume maxHealth is never secret, as it's a cap, not current state.
    -- Even if it is, StatusBar:SetMinMaxValues accepts it.

    local healthTexture = self.Health:GetStatusBarTexture()

    -----------------------------------------------------------------------
    -- 1. My Incoming Heals
    -----------------------------------------------------------------------
    -- Common Width for all bars (match health bar width)
    local totalWidth = self.Health:GetWidth()

    -----------------------------------------------------------------------
    -- 1. My Incoming Heals
    -----------------------------------------------------------------------
    if self.MyIncomingHealBar then
        local myIncomingHeal = UnitGetIncomingHeals(self.unit, "player") or 0

        self.MyIncomingHealBar:SetMinMaxValues(0, maxHealth)
        self.MyIncomingHealBar:SetValue(myIncomingHeal)

        -- Always Show (width 0 if value is 0)
        self.MyIncomingHealBar:Show()
        SafeSetHealBarPoints(self.MyIncomingHealBar, healthTexture, totalWidth)
    end

    -----------------------------------------------------------------------
    -- 2. All Incoming Heals (Renamed logic from Other)
    -----------------------------------------------------------------------
    if self.OtherIncomingHealBar then
        local allIncomingHeal = UnitGetIncomingHeals(self.unit) or 0
        -- Note: We use the "Other" bar to represent "All".
        -- Visually: [My][Other] is achieved by:
        -- Layer 1 (Bottom): [All IncomingHeals ...............]
        -- Layer 2 (Top):    [My IncomingHeals ...]
        -- Result: The part of "All" sticking out is "Others".

        self.OtherIncomingHealBar:SetMinMaxValues(0, maxHealth)
        self.OtherIncomingHealBar:SetValue(allIncomingHeal)

        self.OtherIncomingHealBar:Show()
        SafeSetHealBarPoints(self.OtherIncomingHealBar, healthTexture, totalWidth)
    end

    -----------------------------------------------------------------------
    -- 3. Total Absorbs (Shields)
    -----------------------------------------------------------------------
    local absorbAnchorTexture = healthTexture
    if self.OtherIncomingHealBar then
        absorbAnchorTexture = self.OtherIncomingHealBar:GetStatusBarTexture()
    end

    if self.TotalAbsorbBar then
        if not self.absorbsEnabled then
            self.TotalAbsorbBar:Hide()
            if self.TotalAbsorbOverlay then
                self.TotalAbsorbOverlay:Hide()
            end
        else
            local totalAbsorb = UnitGetTotalAbsorbs(self.unit) or 0

            self.TotalAbsorbBar:SetMinMaxValues(0, maxHealth)
            self.TotalAbsorbBar:SetValue(totalAbsorb)

            self.TotalAbsorbBar:Show()
            SafeSetHealBarPoints(self.TotalAbsorbBar, absorbAnchorTexture, totalWidth)

            -- Update Overlay Visibility (overlay always matches bar texture)
            if self.TotalAbsorbOverlay then
                self.TotalAbsorbOverlay:Show()
                self.TotalAbsorbOverlay:SetAllPoints(self.TotalAbsorbBar:GetStatusBarTexture())
            end
        end
    end

    -----------------------------------------------------------------------
    -- 4. Heal Absorbs (Necrotic) - Independent Overlay
    -- Stays attached to Health Bar as it eats *into* health
    -----------------------------------------------------------------------
    if self.HealAbsorbBar then
        if not self.healAbsorbsEnabled then
            self.HealAbsorbBar:Hide()
        else
            local healAbsorbAmount = UnitGetTotalHealAbsorbs(self.unit) or 0

            self.HealAbsorbBar:SetMinMaxValues(0, maxHealth)
            self.HealAbsorbBar:SetValue(healAbsorbAmount)

            -- Always Show (clipped by Mask when width is 0)
            self.HealAbsorbBar:Show()
            SafeSetHealAbsorbPoints(self.HealAbsorbBar, self.Health, self.Health:GetWidth())
        end
    end
end

function UnitButtonMixin:UpdateAbsorbs()
    self:UpdateHealPrediction()
end

function UnitButtonMixin:SetAbsorbsEnabled(enabled)
    self.absorbsEnabled = enabled
    self:UpdateHealPrediction()
end

function UnitButtonMixin:SetHealAbsorbsEnabled(enabled)
    self.healAbsorbsEnabled = enabled
    self:UpdateHealPrediction()
end

function UnitButtonMixin:SetHealAbsorbColor(r, g, b, a)
    if self.HealAbsorbBar then
        -- Use passed parameters, fallback to Background color if nil
        if r and g and b then
            self.HealAbsorbBar:SetStatusBarColor(r, g, b, a or 1)
        else
            local c = Orbit.Constants.Colors.Background
            self.HealAbsorbBar:SetStatusBarColor(c.r, c.g, c.b, c.a)
        end
    end
end

-------------------------------------------------
-- Name Display
-------------------------------------------------

function UnitButtonMixin:UpdateName()
    if not self.Name then
        return
    end
    local name = UnitName(self.unit)

    -- Handle nil/invalid names
    if name == nil then
        self.Name:SetText("")
        return
    end

    -- WoW 12.0: UnitName returns secret values for non-player units during combat
    -- Secret values can be passed to SetText but cannot have string operations performed on them
    if issecretvalue and issecretvalue(name) then
        self.Name:SetText(name) -- FontString:SetText accepts secret values
        return
    end

    -- Non-secret string: safe to truncate
    if type(name) ~= "string" then
        self.Name:SetText("")
        return
    end

    local maxChars = 15

    local frameWidth = self:GetWidth()
    if type(frameWidth) == "number" and frameWidth > 0 then
        -- Estimate HealthText reserved width based on font size (avoids secret value issues)
        -- "100%" is ~4-5 chars, estimate ~0.6x font height per character
        local fontName, fontHeight = self.HealthText and self.HealthText:GetFont()
        fontHeight = fontHeight or 12
        local estimatedHealthTextWidth = fontHeight * 3  -- Approximate width for "100%"
        
        -- Available width = frame - healthText space - padding
        local availableWidth = frameWidth - estimatedHealthTextWidth - 20
        
        -- Estimate characters: assume ~0.5x font height per character average
        local charWidth = fontHeight * 0.5
        maxChars = math.floor(availableWidth / charWidth)
        maxChars = math.max(6, math.min(maxChars, 30)) -- Clamp between 6-30
    end

    if #name > maxChars then
        self.Name:SetText(string.sub(name, 1, maxChars))
    else
        self.Name:SetText(name)
    end
end

function UnitButtonMixin:SetClassColour(enabled)
    self.classColour = enabled
    self:UpdateHealth()
end

function UnitButtonMixin:SetBorderHidden(edge, hidden)
    if not self.Borders then
        return
    end

    local border = self.Borders[edge]
    if border then
        border:SetShown(not hidden)
    end
end

function UnitButtonMixin:UpdateTextLayout()
    if not self.Name or not self.HealthText or not self.TextFrame then
        return
    end

    local height = self:GetHeight()
    local fontName, fontHeight, fontFlags = self.Name:GetFont()
    fontHeight = fontHeight or 12

    self.Name:ClearAllPoints()
    self.HealthText:ClearAllPoints()

    -- Calculate Name's right offset based on font size (avoids secret value issues from GetStringWidth)
    -- "100%" is ~4-5 chars, estimate ~0.6x font height per character, plus padding
    local padding = 5
    local estimatedHealthTextWidth = fontHeight * 3  -- Approximate width for "100%"
    local nameRightOffset = estimatedHealthTextWidth + padding + 5  -- Extra gap

    -- If frame is smaller than text (with a small buffer), justify to bottom
    -- so text grows upwards and remains readable/uncropped at the top.
    if height < (fontHeight + 2) then
        self.Name:SetPoint("BOTTOMLEFT", self.TextFrame, "BOTTOMLEFT", padding, 0)
        self.Name:SetPoint("BOTTOMRIGHT", self.TextFrame, "BOTTOMRIGHT", -nameRightOffset, 0)
        self.HealthText:SetPoint("BOTTOMRIGHT", self.TextFrame, "BOTTOMRIGHT", -padding, 0)
    else
        self.Name:SetPoint("LEFT", self.TextFrame, "LEFT", padding, 0)
        self.Name:SetPoint("RIGHT", self.TextFrame, "RIGHT", -nameRightOffset, 0)
        self.HealthText:SetPoint("RIGHT", self.TextFrame, "RIGHT", -padding, 0)
    end
end

function UnitButtonMixin:SetBorder(size)
    -- Delegate to Skin Engine
    if Orbit.Skin:SkinBorder(self, self, size) then
        self.borderPixelSize = 0
        if self.Health then
            self.Health:ClearAllPoints()
            self.Health:SetPoint("TOPLEFT", 0, 0)
            self.Health:SetPoint("BOTTOMRIGHT", 0, 0)
        end
        if self.HealthDamageBar then
            self.HealthDamageBar:ClearAllPoints()
            self.HealthDamageBar:SetAllPoints(self.Health)
        end
        return
    end

    local pixelSize = self.borderPixelSize
    
    -- Resize DamageBar (behind Health)
    if self.HealthDamageBar then
        self.HealthDamageBar:ClearAllPoints()
        self.HealthDamageBar:SetPoint("TOPLEFT", pixelSize, -pixelSize)
        self.HealthDamageBar:SetPoint("BOTTOMRIGHT", -pixelSize, pixelSize)
    end

    if self.Health then
        self.Health:ClearAllPoints()
        self.Health:SetPoint("TOPLEFT", pixelSize, -pixelSize)
        self.Health:SetPoint("BOTTOMRIGHT", -pixelSize, pixelSize)
    end
end

function UnitButton:Create(parent, unit, name)
    local f = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate,BackdropTemplate")

    -- Enforce Pixel Perfection on Sizing
    if Engine.Pixel then
        Engine.Pixel:Enforce(f)
    end
    f:SetClampedToScreen(true) -- Prevent dragging off-screen

    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")

    f.unit = unit

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    local bg = Orbit.Constants.Colors.Background
    f.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)

    -- Damage Bar (Red) - Behind the Health bar, shows "damage taken" chunk
    -- NOTE: Initial insets are 0. Consuming plugins MUST call frame:SetBorder(size) to apply proper insets.
    f.HealthDamageBar = CreateFrame("StatusBar", nil, f)
    f.HealthDamageBar:SetPoint("TOPLEFT", 0, 0)
    f.HealthDamageBar:SetPoint("BOTTOMRIGHT", 0, 0)
    f.HealthDamageBar:SetMinMaxValues(0, 1)
    f.HealthDamageBar:SetValue(1)
    f.HealthDamageBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    f.HealthDamageBar:SetStatusBarColor(0.8, 0.1, 0.1, 0.4) -- Dark Red, Reduced Opacity
    f.HealthDamageBar:SetFrameLevel(f:GetFrameLevel() + 1) -- Behind Health

    -- Animation state for smooth interpolation
    f.damageBarTarget = 0
    f.damageBarAnimating = false

    -- NOTE: Initial insets are 0. Consuming plugins MUST call frame:SetBorder(size) to apply proper insets.
    f.Health = CreateFrame("StatusBar", nil, f)
    f.Health:SetPoint("TOPLEFT", 0, 0)
    f.Health:SetPoint("BOTTOMRIGHT", 0, 0)
    f.Health:SetMinMaxValues(0, 1)
    f.Health:SetValue(1)
    f.Health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    f.Health:SetStatusBarColor(0, 1, 0)
    f.Health:SetClipsChildren(true) -- Clip children to prevent heal absorb shadow leaks at 0 value
    f.Health:SetFrameLevel(f:GetFrameLevel() + 2) -- Above DamageBar

    -- Apply Overlay
    local overlayPath = "Interface\\AddOns\\Orbit\\Core\\assets\\Statusbar\\orbit-left-right.tga"
    Orbit.Skin:AddOverlay(f.Health, overlayPath, "BLEND", 0.3)

    -----------------------------------------------------------------------
    -- Incoming Heals (Hidden by default)
    -----------------------------------------------------------------------

    -- 1. My Incoming Heal
    f.MyIncomingHealBar = CreateFrame("StatusBar", nil, f.Health)
    f.MyIncomingHealBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    f.MyIncomingHealBar:SetStatusBarColor(0.66, 1, 0.66, 0.6) -- Light Green, semi-transparent
    f.MyIncomingHealBar:SetMinMaxValues(0, 1)
    f.MyIncomingHealBar:SetValue(0)
    -- Same level as health, drawn after/next to it.
    f.MyIncomingHealBar:SetFrameLevel(f.Health:GetFrameLevel())
    f.MyIncomingHealBar:Hide()

    -- 2. Other Incoming Heal
    f.OtherIncomingHealBar = CreateFrame("StatusBar", nil, f.Health)
    f.OtherIncomingHealBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    f.OtherIncomingHealBar:SetStatusBarColor(0.66, 1, 0.66, 0.6) -- Light Green
    f.OtherIncomingHealBar:SetMinMaxValues(0, 1)
    f.OtherIncomingHealBar:SetValue(0)
    f.OtherIncomingHealBar:SetFrameLevel(f.Health:GetFrameLevel())
    f.OtherIncomingHealBar:Hide()

    -----------------------------------------------------------------------
    -- Total Absorbs (Shields) - Replaces AbsorbOverlay
    -----------------------------------------------------------------------
    f.TotalAbsorbBar = CreateFrame("StatusBar", nil, f.Health)
    -- Use a solid texture for the bar itself, and the pattern for the overlay.
    f.TotalAbsorbBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    -- Magic Blue color for the shield (Whitey/Pale Blue)
    f.TotalAbsorbBar:SetStatusBarColor(0.5, 0.8, 1.0, 0.35)
    f.TotalAbsorbBar:SetMinMaxValues(0, 1)
    f.TotalAbsorbBar:SetValue(0)
    f.TotalAbsorbBar:SetFrameLevel(f.Health:GetFrameLevel()) -- Same level
    f.TotalAbsorbBar:Hide()

    -- Shield Overlay Pattern
    f.TotalAbsorbOverlay = f.TotalAbsorbBar:CreateTexture(nil, "OVERLAY")
    f.TotalAbsorbOverlay:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
    f.TotalAbsorbOverlay:SetAllPoints(f.TotalAbsorbBar)
    f.TotalAbsorbOverlay:SetHorizTile(true)
    f.TotalAbsorbOverlay:SetVertTile(true)
    f.TotalAbsorbOverlay:SetBlendMode("ADD")
    f.TotalAbsorbOverlay:SetVertexColor(0.7, 0.9, 1.0, 1.0) -- Pale blue tint for overlay

    -----------------------------------------------------------------------
    -- Heal Absorbs (Necrotic) - "HealMe" Pattern
    -----------------------------------------------------------------------
    f.HealAbsorbBar = CreateFrame("StatusBar", nil, f.Health)
    f.HealAbsorbBar:SetReverseFill(true)
    -- Anchors set in Update function

    -- 1. Base Layer
    local healthTexture = f.Health:GetStatusBarTexture():GetTexture()
    f.HealAbsorbBar:SetStatusBarTexture(healthTexture or "Interface\\Buttons\\WHITE8x8")
    local c = Orbit.Constants.Colors.Background
    f.HealAbsorbBar:SetStatusBarColor(c.r, c.g, c.b, c.a) -- Matches PlayerResources Backdrop
    f.HealAbsorbBar:SetMinMaxValues(0, 1)
    f.HealAbsorbBar:SetValue(0)
    f.HealAbsorbBar:SetFrameLevel(f.Health:GetFrameLevel() + 2) -- Higher than health to overlay it
    f.HealAbsorbBar:Hide()

    -- 2. Overlay Layer (Mask + Pattern)
    f.HealAbsorbMask = CreateFrame("Frame", nil, f.HealAbsorbBar)
    f.HealAbsorbMask:SetClipsChildren(true)
    f.HealAbsorbMask:SetFrameLevel(f.HealAbsorbBar:GetFrameLevel() + 1)
    f.HealAbsorbMask:SetPoint("TOPLEFT", f.HealAbsorbBar:GetStatusBarTexture(), "TOPLEFT", 0, 0)
    f.HealAbsorbMask:SetPoint("BOTTOMRIGHT", f.HealAbsorbBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)

    f.HealAbsorbPattern = f.HealAbsorbMask:CreateTexture(nil, "ARTWORK")
    f.HealAbsorbPattern:SetSize(3200, 3200) -- Massive square
    f.HealAbsorbPattern:SetPoint("TOPLEFT", f.HealAbsorbMask, "TOPLEFT", 0, 0)

    f.HealAbsorbPattern:SetTexture(
        "Interface\\AddOns\\Orbit\\Core\\Assets\\Statusbar\\necrotic.tga",
        "REPEAT",
        "REPEAT"
    )
    f.HealAbsorbPattern:SetHorizTile(true)
    f.HealAbsorbPattern:SetVertTile(true)
    f.HealAbsorbPattern:SetTexCoord(0, 100, 0, 100)
    f.HealAbsorbPattern:SetBlendMode("BLEND")
    f.HealAbsorbPattern:SetAlpha(0.15)

    -- Sync Visibility
    hooksecurefunc(f.HealAbsorbBar, "Show", function()
        f.HealAbsorbMask:Show()
    end)
    hooksecurefunc(f.HealAbsorbBar, "Hide", function()
        f.HealAbsorbMask:Hide()
    end)

    -- Divider removed by user request.
    -- Text Frame to ensure text sits ABOVE absorbs
    f.TextFrame = CreateFrame("Frame", nil, f)
    f.TextFrame:SetAllPoints(f.Health)
    f.TextFrame:SetFrameLevel(f.Health:GetFrameLevel() + 10)

    f.Name = f.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Name:SetPoint("LEFT", 5, 0)
    -- Note: RIGHT point is set dynamically by UpdateTextLayout based on HealthText width
    f.Name:SetJustifyH("LEFT")
    f.Name:SetShadowOffset(1, -1)
    f.Name:SetShadowColor(0, 0, 0, 1)
    f.Name:SetWordWrap(false)
    f.Name:SetNonSpaceWrap(false)
    f.Name:SetText("Unit Name")

    f.HealthText = f.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.HealthText:SetPoint("RIGHT", -5, 0)
    f.HealthText:SetJustifyH("RIGHT")
    f.HealthText:SetShadowOffset(1, -1)
    f.HealthText:SetShadowColor(0, 0, 0, 1)
    f.HealthText:SetText("100%")

    Mixin(f, UnitButtonMixin)
    f:SetScript("OnEvent", f.OnEvent)
    f:OnLoad()

    f:SetScript("OnEnter", function(self)
        self:SetMouseOver(true)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(self)
        self:SetMouseOver(false)
        GameTooltip:Hide()
    end)

    f:HookScript("OnSizeChanged", function(self)
        self:UpdateTextLayout()
    end)

    -- OnUpdate for damage bar animation (simple time-delayed snap)
    -- Shows the red chunk for DELAY seconds, then snaps to current health
    -- NOTE: This script is only SET when animation starts (in UpdateHealth)
    --       and CLEARED when animation completes (saves CPU when not animating)
    local DAMAGE_BAR_DELAY = 0.3 -- Show red chunk for this long before snapping
    
    local function DamageBarOnUpdate(self, elapsed)
        if not self.HealthDamageBar then
            self:SetScript("OnUpdate", nil)
            return
        end

        local now = GetTime()
        local timeSinceChange = now - (self.lastHealthUpdate or 0)

        if timeSinceChange < DAMAGE_BAR_DELAY then
            -- Still in delay period, red chunk is visible
            return
        end

        -- After delay, sync DamageBar to Health bar's current value
        local healthValue = self.Health:GetValue()
        self.HealthDamageBar:SetValue(healthValue, SMOOTH_ANIM)
        
        -- Animation complete - remove OnUpdate handler to save CPU
        self:SetScript("OnUpdate", nil)
    end
    
    -- Store the function on the frame for use in UpdateHealth
    f.DamageBarOnUpdate = DamageBarOnUpdate

    RegisterUnitWatch(f)

    -- Force update when shown (Fixes 'fresh summon' empty bars)
    f:SetScript("OnShow", function(self)
        self:UpdateAll()
    end)

    return f
end
