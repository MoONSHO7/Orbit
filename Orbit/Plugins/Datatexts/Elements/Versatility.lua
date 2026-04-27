-- Versatility.lua
-- Versatility datatext: shows current Versatility percentage or rating
local _, Orbit = ...
local DT = Orbit.Datatexts
local NumericOrNil = Orbit.SecretValueUtils.NumericOrNil
local L = Orbit.L

local CR_VERSATILITY_DAMAGE_DONE = 29

local W = DT.BaseDatatext:New("Versatility")
W.showPercentage = true

-- Each operand needs NumericOrNil before the add; one secret operand poisons the sum.
local function VersatilityPercent()
    local bonus = NumericOrNil(GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE))
    local flat = NumericOrNil(GetVersatilityBonus and GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE))
    if not bonus and not flat then return nil end
    return (bonus or 0) + (flat or 0)
end

function W:Update()
    local pct = VersatilityPercent()
    local rating = NumericOrNil(GetCombatRating(CR_VERSATILITY_DAMAGE_DONE))
    if self.showPercentage then
        if pct then self:SetText(string.format("Versatility: |cffffffff%.2f%%|r", pct))
        else self:SetText("Versatility: |cffffffff" .. L.CMN_HIDDEN_VALUE .. "|r") end
    else
        if rating then self:SetText(string.format("Versatility: |cffffffff%d|r", rating))
        else self:SetText("Versatility: |cffffffff" .. L.CMN_HIDDEN_VALUE .. "|r") end
    end
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_VERSATILITY_TITLE, 1, 0.82, 0)

    local pct = VersatilityPercent()
    local rating = NumericOrNil(GetCombatRating(CR_VERSATILITY_DAMAGE_DONE))
    GameTooltip:AddDoubleLine("Rating:", rating and string.format("%d", rating) or L.CMN_HIDDEN_VALUE, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Percentage:", pct and string.format("%.2f%%", pct) or L.CMN_HIDDEN_VALUE, 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()

    self:SetClickFunc(function(datatext, button)
        if button == "LeftButton" then
            datatext.showPercentage = not datatext.showPercentage
            datatext:Update()
            if datatext.isHovered then datatext:UpdateTooltip() end
        end
    end)

    self:SetUpdateFunc(function() self:Update() end)
    self:RegisterUnitEvent("UNIT_STATS", "player")
    self:RegisterUnitEvent("UNIT_AURA", "player")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetCategory("CHARACTER")
    self.leftClickHint = "Toggle Percentage/Rating"
    self:Register()
    self:Update()
end

W:Init()
