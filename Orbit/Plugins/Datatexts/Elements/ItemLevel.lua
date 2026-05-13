-- ItemLevel.lua
-- Item level datatext: shows average equipped item level
local _, Orbit = ...
local DT = Orbit.Datatexts
local L = Orbit.L

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("ItemLevel")

function W:Update()
    local avgLevel, equippedLevel = GetAverageItemLevel()
    self:SetText(L.PLU_DT_ILVL_TEXT_F:format(equippedLevel or avgLevel or 0))
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_ILVL_TITLE, 1, 0.82, 0)
    local avg, equipped = GetAverageItemLevel()
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.PLU_DT_ILVL_OVERALL, string.format("%.1f", avg or 0), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.PLU_DT_ILVL_EQUIPPED, string.format("%.1f", equipped or 0), 1, 1, 1, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.PLU_DT_HINT_CLICK, L.PLU_DT_ILVL_CHARACTER_PANEL, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function() ToggleCharacter("PaperDollFrame") end)
    self.leftClickHint = L.PLU_DT_ILVL_CHARACTER_PANEL
    self:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

W:Init()
