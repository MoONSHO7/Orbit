-- [ UNIT BUTTON - PREDICTION MODULE ]---------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton
local DEFAULT_HEAL_VALUE = 0

-- [ LOCAL HELPERS ]---------------------------------------------------------------------------------
-- The healer shouts "I'M TRACKING YOUR INCOMING HEALS" every combat round
local function SafeSetHealBarPoints(bar, anchorTexture, width)
    -- The ranger only updates camp if the trail marker has actually moved
    if bar.cachedAnchor ~= anchorTexture or bar.cachedWidth ~= width then
        bar:ClearAllPoints()
        bar:SetWidth(width)
        bar:SetPoint("TOPLEFT", anchorTexture, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", anchorTexture, "BOTTOMRIGHT", 0, 0)
        bar.cachedAnchor = anchorTexture
        bar.cachedWidth = width
    end
end

-- The cleric checks if the necrotic debuff is eating backwards through the health bar
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

local PredictionMixin = {}

function PredictionMixin:UpdateHealPrediction()
    if not self.unit or not UnitExists(self.unit) then return end

    local maxHealth = UnitHealthMax(self.unit)

    local healthTexture = self.Health:GetStatusBarTexture()
    local totalWidth = self.Health:GetWidth()
    if issecretvalue and issecretvalue(totalWidth) then return end

    -- [ MY INCOMING HEALS ]--------------------------------------------------------------------------
    if self.MyIncomingHealBar then
        local myIncomingHeal = UnitGetIncomingHeals(self.unit, "player") or DEFAULT_HEAL_VALUE
        self.MyIncomingHealBar:SetMinMaxValues(0, maxHealth)
        self.MyIncomingHealBar:SetValue(myIncomingHeal)
        self.MyIncomingHealBar:Show()
        SafeSetHealBarPoints(self.MyIncomingHealBar, healthTexture, totalWidth)
    end

    -- [ ALL INCOMING HEALS ]-------------------------------------------------------------------------
    if self.OtherIncomingHealBar then
        local allIncomingHeal = UnitGetIncomingHeals(self.unit) or DEFAULT_HEAL_VALUE
        self.OtherIncomingHealBar:SetMinMaxValues(0, maxHealth)
        self.OtherIncomingHealBar:SetValue(allIncomingHeal)
        self.OtherIncomingHealBar:Show()
        SafeSetHealBarPoints(self.OtherIncomingHealBar, healthTexture, totalWidth)
    end

    -- [ TOTAL ABSORBS ]------------------------------------------------------------------------------
    local absorbAnchorTexture = self.OtherIncomingHealBar and self.OtherIncomingHealBar:GetStatusBarTexture() or healthTexture

    if self.TotalAbsorbBar then
        if not self.absorbsEnabled then
            self.TotalAbsorbBar:Hide()
            if self.TotalAbsorbOverlay then self.TotalAbsorbOverlay:Hide() end
        else
            local totalAbsorb = UnitGetTotalAbsorbs(self.unit) or DEFAULT_HEAL_VALUE
            self.TotalAbsorbBar:SetMinMaxValues(0, maxHealth)
            self.TotalAbsorbBar:SetValue(totalAbsorb)
            self.TotalAbsorbBar:Show()
            SafeSetHealBarPoints(self.TotalAbsorbBar, absorbAnchorTexture, totalWidth)

            if self.TotalAbsorbOverlay then
                self.TotalAbsorbOverlay:Show()
                self.TotalAbsorbOverlay:SetAllPoints(self.TotalAbsorbBar:GetStatusBarTexture())
            end
        end
    end

    -- [ HEAL ABSORBS ]-------------------------------------------------------------------------------
    if self.HealAbsorbBar then
        if not self.healAbsorbsEnabled then
            self.HealAbsorbBar:Hide()
        else
            local healAbsorbAmount = UnitGetTotalHealAbsorbs(self.unit) or DEFAULT_HEAL_VALUE
            self.HealAbsorbBar:SetMinMaxValues(0, maxHealth)
            self.HealAbsorbBar:SetValue(healAbsorbAmount)
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
    if not self.HealAbsorbBar then return end
    if not (r and g and b) then error("SetHealAbsorbColor requires r, g, b values") end
    self.HealAbsorbBar:SetStatusBarColor(r, g, b, a or 1)
end

UnitButton.PredictionMixin = PredictionMixin
