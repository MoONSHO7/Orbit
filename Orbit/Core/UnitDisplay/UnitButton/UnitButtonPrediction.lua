-- [ UNIT BUTTON - PREDICTION MODULE ]----------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton
local DEFAULT_HEAL_VALUE = 0

-- UnitGetIncomingHeals / UnitGetTotalAbsorbs / UnitGetTotalHealAbsorbs are secret in combat;
-- `v or 0` would throw. Forward the value as-is (StatusBar:SetValue is a C++ sink that accepts
-- secret numerics) and only substitute DEFAULT_HEAL_VALUE when we can prove v is plainly nil.
local function SafeHealValue(v)
    if issecretvalue(v) then return v end
    return v or DEFAULT_HEAL_VALUE
end

-- [ LOCAL HELPERS ]----------------------------------------------------------------------------------
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

-- [ PREDICTION MIXIN ]-------------------------------------------------------------------------------
local PredictionMixin = {}

function PredictionMixin:UpdateHealPrediction()
    if not self.unit or not UnitExists(self.unit) then return end

    local maxHealth = UnitHealthMax(self.unit)

    local healthTexture = self.Health:GetStatusBarTexture()
    local totalWidth = self.Health:GetWidth()
    if issecretvalue and issecretvalue(totalWidth) then return end

    -- [ MY INCOMING HEALS ]--------------------------------------------------------------------------
    if self.MyIncomingHealBar then
        local myIncomingHeal = SafeHealValue(UnitGetIncomingHeals(self.unit, "player"))
        self.MyIncomingHealBar:SetMinMaxValues(0, maxHealth)
        self.MyIncomingHealBar:SetValue(myIncomingHeal)
        self.MyIncomingHealBar:Show()
        SafeSetHealBarPoints(self.MyIncomingHealBar, healthTexture, totalWidth)
    end

    -- [ ALL INCOMING HEALS ]-------------------------------------------------------------------------
    if self.OtherIncomingHealBar then
        local allIncomingHeal = SafeHealValue(UnitGetIncomingHeals(self.unit))
        self.OtherIncomingHealBar:SetMinMaxValues(0, maxHealth)
        self.OtherIncomingHealBar:SetValue(allIncomingHeal)
        self.OtherIncomingHealBar:Show()
        SafeSetHealBarPoints(self.OtherIncomingHealBar, healthTexture, totalWidth)
    end

    -- [ TOTAL ABSORBS ]------------------------------------------------------------------------------
    if self.TotalAbsorbBar then
        if not self.absorbsEnabled then
            self.TotalAbsorbBar:Hide()
        else
            local totalAbsorb = SafeHealValue(UnitGetTotalAbsorbs(self.unit))
            self.TotalAbsorbBar:SetMinMaxValues(0, maxHealth)
            self.TotalAbsorbBar:SetValue(totalAbsorb)
            self.TotalAbsorbBar:Show()
            local gs = Orbit.db.GlobalSettings
            if gs and gs.AlwaysShowAbsorb then
                self.TotalAbsorbBar:SetReverseFill(true)
                self.TotalAbsorbBar:ClearAllPoints()
                self.TotalAbsorbBar:SetPoint("TOPLEFT", self.Health, "TOPLEFT", 0, 0)
                self.TotalAbsorbBar:SetPoint("BOTTOMRIGHT", self.Health, "BOTTOMRIGHT", 0, 0)
                self.TotalAbsorbBar.cachedAnchor = nil
            else
                self.TotalAbsorbBar:SetReverseFill(false)
                local absorbAnchorTexture = self.OtherIncomingHealBar and self.OtherIncomingHealBar:GetStatusBarTexture() or healthTexture
                SafeSetHealBarPoints(self.TotalAbsorbBar, absorbAnchorTexture, totalWidth)
            end
        end
    end

    -- [ HEAL ABSORBS ]-------------------------------------------------------------------------------
    if self.HealAbsorbBar then
        if not self.healAbsorbsEnabled then
            self.HealAbsorbBar:Hide()
        else
            local healAbsorbAmount = SafeHealValue(UnitGetTotalHealAbsorbs(self.unit))
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
