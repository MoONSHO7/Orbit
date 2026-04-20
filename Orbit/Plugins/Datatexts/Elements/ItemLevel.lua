-- ItemLevel.lua
-- Item level datatext: shows average equipped item level
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("ItemLevel")

function W:Update()
    local avgLevel, equippedLevel = GetAverageItemLevel()
    self:SetText(string.format("|cffffd700%.0f|r iLvl", equippedLevel or avgLevel or 0))
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Item Level", 1, 0.82, 0)
    local avg, equipped = GetAverageItemLevel()
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Overall:", string.format("%.1f", avg or 0), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Equipped:", string.format("%.1f", equipped or 0), 1, 1, 1, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Character Panel", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function() ToggleCharacter("PaperDollFrame") end)
    self.leftClickHint = "Character Panel"
    self:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

W:Init()
