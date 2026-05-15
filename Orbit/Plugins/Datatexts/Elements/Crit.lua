-- Crit.lua
-- Crit datatext: shows current Critical Strike percentage or rating
local _, Orbit = ...
local DT = Orbit.Datatexts
local NumericOrNil = Orbit.SecretValueUtils.NumericOrNil
local L = Orbit.L

local CR_CRIT_MELEE = 9

local W = DT.BaseDatatext:New("Crit")
W.showPercentage = true

function W:Update()
    local pct = NumericOrNil(GetCritChance and GetCritChance()) or NumericOrNil(GetMeleeCritChance and GetMeleeCritChance())
    local rating = NumericOrNil(GetCombatRating(CR_CRIT_MELEE))
    if pct == self._lastPct and rating == self._lastRating and self.showPercentage == self._lastShowPct then return end
    self._lastPct, self._lastRating, self._lastShowPct = pct, rating, self.showPercentage
    if self.showPercentage then
        if pct then self:SetText(L.PLU_DT_STAT_CRIT_LABEL .. string.format("|cffffffff%.2f%%|r", pct))
        else self:SetText(L.PLU_DT_STAT_CRIT_LABEL .. "|cffffffff" .. L.CMN_HIDDEN_VALUE .. "|r") end
    else
        if rating then self:SetText(L.PLU_DT_STAT_CRIT_LABEL .. string.format("|cffffffff%d|r", rating))
        else self:SetText(L.PLU_DT_STAT_CRIT_LABEL .. "|cffffffff" .. L.CMN_HIDDEN_VALUE .. "|r") end
    end
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_CRIT_TITLE, 1, 0.82, 0)

    local pct = NumericOrNil(GetCritChance and GetCritChance()) or NumericOrNil(GetMeleeCritChance and GetMeleeCritChance())
    local rating = NumericOrNil(GetCombatRating(CR_CRIT_MELEE))
    GameTooltip:AddDoubleLine(L.PLU_DT_STAT_RATING, rating and string.format("%d", rating) or L.CMN_HIDDEN_VALUE, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.PLU_DT_STAT_PERCENT, pct and string.format("%.2f%%", pct) or L.CMN_HIDDEN_VALUE, 1, 1, 1, 1, 1, 1)
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
    self.leftClickHint = L.PLU_DT_STAT_TOGGLE
    self:Register()
    self:Update()
end

W:Init()
