-- Mastery.lua
-- Mastery datatext: shows current Mastery percentage or rating
local _, Orbit = ...
local DT = Orbit.Datatexts
local NumericOrNil = Orbit.SecretValueUtils.NumericOrNil
local L = Orbit.L

local CR_MASTERY = 26

local W = DT.BaseDatatext:New("Mastery")
W.showPercentage = true

function W:Update()
    local pct = NumericOrNil(GetMasteryEffect and GetMasteryEffect())
    local rating = NumericOrNil(GetCombatRating(CR_MASTERY))
    if self.showPercentage then
        if pct then self:SetText(string.format("Mastery: |cffffffff%.2f%%|r", pct))
        else self:SetText("Mastery: |cffffffff" .. L.CMN_HIDDEN_VALUE .. "|r") end
    else
        if rating then self:SetText(string.format("Mastery: |cffffffff%d|r", rating))
        else self:SetText("Mastery: |cffffffff" .. L.CMN_HIDDEN_VALUE .. "|r") end
    end
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_MASTERY_TITLE, 1, 0.82, 0)

    local pct = NumericOrNil(GetMasteryEffect and GetMasteryEffect())
    local rating = NumericOrNil(GetCombatRating(CR_MASTERY))
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
