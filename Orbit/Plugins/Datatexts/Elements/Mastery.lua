-- Mastery.lua
-- Mastery datatext: shows current Mastery percentage or rating
local _, Orbit = ...
local DT = Orbit.Datatexts

local W = DT.BaseDatatext:New("Mastery")
W.showPercentage = true

function W:Update()
    local pct = GetMasteryEffect and GetMasteryEffect() or 0
    local rating = GetCombatRating(26 --[[CR_MASTERY]]) or 0
    if self.showPercentage then
        self:SetText(string.format("Mastery: |cffffffff%.2f%%|r", pct))
    else
        self:SetText(string.format("Mastery: |cffffffff%d|r", rating))
    end
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Mastery", 1, 0.82, 0)
    
    local pct = GetMasteryEffect and GetMasteryEffect() or 0
    local rating = GetCombatRating(26 --[[CR_MASTERY]]) or 0
    GameTooltip:AddDoubleLine("Rating:", string.format("%d", rating), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Percentage:", string.format("%.2f%%", pct), 1, 1, 1, 1, 1, 1)
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
