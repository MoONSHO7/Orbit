-- [ UNIT BUTTON - PREDICTION MODULE ]---------------------------------------------------------------
-- Heal prediction, absorbs, and heal absorb (necrotic) overlays
-- Taint-Safe Strategy: Uses stacking StatusBars to avoid math on secret values

local _, Orbit = ...
local Engine = Orbit.Engine

-- Ensure UnitButton namespace exists
Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ LOCAL HELPERS ]---------------------------------------------------------------------------------

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

-- [ PREDICTION MIXIN ]------------------------------------------------------------------------------
-- Partial mixin for heal prediction functionality

local PredictionMixin = {}

function PredictionMixin:UpdateHealPrediction()
    -- Guard against nil unit
    if not self.unit or not UnitExists(self.unit) then
        return
    end

    local maxHealth = UnitHealthMax(self.unit)
    -- We assume maxHealth is never secret, as it's a cap, not current state.
    -- Even if it is, StatusBar:SetMinMaxValues accepts it.

    local healthTexture = self.Health:GetStatusBarTexture()

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

function PredictionMixin:UpdateAbsorbs()
    self:UpdateHealPrediction()
end

function PredictionMixin:SetAbsorbsEnabled(enabled)
    self.absorbsEnabled = enabled
    self:UpdateHealPrediction()
end

function PredictionMixin:SetHealAbsorbsEnabled(enabled)
    self.healAbsorbsEnabled = enabled
    self:UpdateHealPrediction()
end

function PredictionMixin:SetHealAbsorbColor(r, g, b, a)
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

-- Export for composition
UnitButton.PredictionMixin = PredictionMixin
