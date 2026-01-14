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
        self.damageBarAnimating = true
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

local function FormatCurrentHealth(unit)
    local health = UnitHealth(unit)

    if AbbreviateLargeNumbers and health then
        local ok, result = pcall(AbbreviateLargeNumbers, health)
        if ok and result then
            return result
        end
    end
    return nil
end

function UnitButtonMixin:UpdateHealthText()
    if not self.HealthText then
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

    local text
    if self.isMouseOver then
        text = FormatCurrentHealth(self.unit) or "???"
    else
        text = FormatHealthPercent(self.unit) or "??%"
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

-------------------------------------------------
-- Other Methods
-------------------------------------------------

function UnitButtonMixin:UpdatePower() end

-------------------------------------------------
-- Heal Prediction (Incoming Heals & Absorbs)
-- Taint-Safe Strategy: Stacking StatusBars
-- Avoids math on secret values by letting the client handle layout
-------------------------------------------------

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
        self.MyIncomingHealBar:ClearAllPoints()
        self.MyIncomingHealBar:SetWidth(totalWidth) -- Set explicit width
        self.MyIncomingHealBar:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT", 0, 0)
        self.MyIncomingHealBar:SetPoint("BOTTOMLEFT", healthTexture, "BOTTOMRIGHT", 0, 0)
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
        self.OtherIncomingHealBar:ClearAllPoints()
        self.OtherIncomingHealBar:SetWidth(totalWidth) -- Set explicit width
        -- Anchor to Health, just like MyIncomingHealBar
        self.OtherIncomingHealBar:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT", 0, 0)
        self.OtherIncomingHealBar:SetPoint("BOTTOMLEFT", healthTexture, "BOTTOMRIGHT", 0, 0)
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
            self.TotalAbsorbBar:ClearAllPoints()
            self.TotalAbsorbBar:SetWidth(totalWidth) -- Set explicit width
            self.TotalAbsorbBar:SetPoint("TOPLEFT", absorbAnchorTexture, "TOPRIGHT", 0, 0)
            self.TotalAbsorbBar:SetPoint("BOTTOMLEFT", absorbAnchorTexture, "BOTTOMRIGHT", 0, 0)

            -- Update Overlay Visibility
            if self.TotalAbsorbOverlay then
                self.TotalAbsorbOverlay:Show()
                -- Ensure Overlay anchors to the FILL, not the frame
                self.TotalAbsorbOverlay:ClearAllPoints()
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

            -- Always Show.
            -- Using Frame-based shadows (clipped by Mask when width is 0) handles the 0-value case.
            self.HealAbsorbBar:Show()

            local healthBar = self.Health
            local totalWidth = healthBar:GetWidth()

            -- Ideally we'd just Anchor TOPRIGHT/BOTTOMRIGHT to the texture,
            -- and set Width to match.
            self.HealAbsorbBar:ClearAllPoints()
            self.HealAbsorbBar:SetWidth(totalWidth)
            self.HealAbsorbBar:SetPoint("TOPRIGHT", healthBar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
            self.HealAbsorbBar:SetPoint("BOTTOMRIGHT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
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
        local c = Orbit.Constants.Colors.Background
        self.HealAbsorbBar:SetStatusBarColor(c.r, c.g, c.b, c.a)
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
        maxChars = math.floor((frameWidth - 30) / 8)
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

function UnitButtonMixin:SetBorder(size)
    -- Calculation: Convert desired physical pixels (size) to frame-local units
    -- Use new Pixel Engine (or fallback during init)
    local pixelScale = (Orbit.Engine.Pixel and Orbit.Engine.Pixel:GetScale())
        or (768.0 / (select(2, GetPhysicalScreenSize()) or 768.0))

    local scale = self:GetEffectiveScale()
    if not scale or scale < 0.01 then
        scale = 1
    end

    local mult = pixelScale / scale
    local pixelSize = (size or 1) * mult
    self.borderPixelSize = pixelSize

    -- Create borders if needed
    if not self.Borders then
        self.Borders = {}
        local function CreateLine()
            local t = self:CreateTexture(nil, "BORDER")
            t:SetColorTexture(0, 0, 0, 1)
            return t
        end
        self.Borders.Top = CreateLine()
        self.Borders.Bottom = CreateLine()
        self.Borders.Left = CreateLine()
        self.Borders.Right = CreateLine()
    end

    local b = self.Borders

    -- Non-overlapping Layout
    -- Top/Bottom: Full Width
    b.Top:ClearAllPoints()
    b.Top:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    b.Top:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
    b.Top:SetHeight(pixelSize)

    b.Bottom:ClearAllPoints()
    b.Bottom:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
    b.Bottom:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
    b.Bottom:SetHeight(pixelSize)

    -- Left/Right: Inset by Top/Bottom height
    b.Left:ClearAllPoints()
    b.Left:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -pixelSize)
    b.Left:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, pixelSize)
    b.Left:SetWidth(pixelSize)

    b.Right:ClearAllPoints()
    b.Right:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -pixelSize)
    b.Right:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, pixelSize)
    b.Right:SetWidth(pixelSize)

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
    f.HealthDamageBar = CreateFrame("StatusBar", nil, f)
    f.HealthDamageBar:SetPoint("TOPLEFT", 1, -1)
    f.HealthDamageBar:SetPoint("BOTTOMRIGHT", -1, 1)
    f.HealthDamageBar:SetMinMaxValues(0, 1)
    f.HealthDamageBar:SetValue(1)
    f.HealthDamageBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    f.HealthDamageBar:SetStatusBarColor(0.8, 0.1, 0.1, 0.4) -- Dark Red, Reduced Opacity
    f.HealthDamageBar:SetFrameLevel(f:GetFrameLevel() + 1) -- Behind Health

    -- Animation state for smooth interpolation
    f.damageBarTarget = 0
    f.damageBarAnimating = false

    f.Health = CreateFrame("StatusBar", nil, f)
    f.Health:SetPoint("TOPLEFT", 1, -1)
    f.Health:SetPoint("BOTTOMRIGHT", -1, 1)
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

    -- Divider: "Complex" shadow separator
    -- Divider: "Complex" shadow separator
    -- Converted to Frames (with texture inside) to respect SetClipsChildren on the Mask
    -- This ensures they disappear when the Mask has 0 width (Value = 0)

    -- Component 1: The Hard Stop (1px Black Line)
    f.HealAbsorbLeftShadow2 = CreateFrame("Frame", nil, f.HealAbsorbMask)
    f.HealAbsorbLeftShadow2:SetSize(1, 30) -- Height is arbitrary as anchors override it, but width 1 is key
    f.HealAbsorbLeftShadow2:SetPoint("TOPLEFT", f.HealAbsorbMask, "TOPLEFT", 0, 0)
    f.HealAbsorbLeftShadow2:SetPoint("BOTTOMLEFT", f.HealAbsorbMask, "BOTTOMLEFT", 0, 0)

    f.HealAbsorbLeftShadow2.tex = f.HealAbsorbLeftShadow2:CreateTexture(nil, "OVERLAY")
    f.HealAbsorbLeftShadow2.tex:SetAllPoints()
    f.HealAbsorbLeftShadow2.tex:SetColorTexture(0, 0, 0, 1)

    -- Component 2: The Soft Fade (Black Shadow)
    f.HealAbsorbLeftShadow = CreateFrame("Frame", nil, f.HealAbsorbMask)
    f.HealAbsorbLeftShadow:SetSize(5, 30)
    f.HealAbsorbLeftShadow:SetPoint("TOPLEFT", f.HealAbsorbLeftShadow2, "TOPRIGHT", 0, 0)
    f.HealAbsorbLeftShadow:SetPoint("BOTTOMLEFT", f.HealAbsorbLeftShadow2, "BOTTOMRIGHT", 0, 0)

    f.HealAbsorbLeftShadow.tex = f.HealAbsorbLeftShadow:CreateTexture(nil, "OVERLAY")
    f.HealAbsorbLeftShadow.tex:SetAllPoints()
    f.HealAbsorbLeftShadow.tex:SetColorTexture(1, 1, 1, 1)
    f.HealAbsorbLeftShadow.tex:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.5), CreateColor(0, 0, 0, 0))
    f.HealAbsorbLeftShadow.tex:SetBlendMode("BLEND")
    -- Text Frame to ensure text sits ABOVE absorbs
    f.TextFrame = CreateFrame("Frame", nil, f.Health)
    f.TextFrame:SetAllPoints(f.Health)
    f.TextFrame:SetFrameLevel(f.Health:GetFrameLevel() + 10)

    f.Name = f.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Name:SetPoint("LEFT", 5, 0)
    f.Name:SetPoint("RIGHT", f.TextFrame, "RIGHT", -50, 0)
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

    -- OnUpdate for damage bar animation (simple time-delayed snap)
    -- Shows the red chunk for DELAY seconds, then snaps to current health
    f:SetScript("OnUpdate", function(self, elapsed)
        if not self.damageBarAnimating or not self.HealthDamageBar then
            return
        end

        local DELAY = 0.3 -- Show red chunk for this long before snapping

        local now = GetTime()
        local timeSinceChange = now - (self.lastHealthUpdate or 0)

        if timeSinceChange < DELAY then
            -- Still in delay period, red chunk is visible
            return
        end

        -- After delay, sync DamageBar to Health bar's current value
        local healthValue = self.Health:GetValue()
        self.HealthDamageBar:SetValue(healthValue, SMOOTH_ANIM)
        self.damageBarAnimating = false
    end)

    RegisterUnitWatch(f)

    -- Force update when shown (Fixes 'fresh summon' empty bars)
    f:SetScript("OnShow", function(self)
        self:UpdateAll()
    end)

    return f
end
