-- BagSpace.lua
-- Bag space datatext: shows free/total slots
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local BAG_COUNT = 4
local SPACE_LOW = 5
local SPACE_MED = 15

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("BagSpace")

function W:Update()
    local free, total = 0, 0
    for bag = 0, BAG_COUNT do
        local slots = C_Container.GetContainerNumSlots(bag)
        local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
        total = total + slots
        free = free + freeSlots
    end
    local color = free <= SPACE_LOW and "|cffff0000" or (free <= SPACE_MED and "|cffffa500" or "|cff00ff00")
    self:SetText(string.format("%s%d|r/%d", color, free, total))
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Bag Space", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    for bag = 0, BAG_COUNT do
        local slots = C_Container.GetContainerNumSlots(bag)
        local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
        if slots > 0 then
            GameTooltip:AddDoubleLine(bag == 0 and "Backpack" or "Bag " .. bag, string.format("%d / %d", freeSlots, slots), 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function() ToggleAllBags() end)
    self.leftClickHint = "Open Bags"
    self:RegisterEvent("BAG_UPDATE")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

W:Init()
