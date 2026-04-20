-- Durability.lua
-- Equipment durability datatext: shows lowest item durability percentage
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DURABILITY_LOW = 25
local DURABILITY_MED = 50
local EQUIP_SLOTS = { "HeadSlot", "ShoulderSlot", "ChestSlot", "WaistSlot", "LegsSlot", "FeetSlot", "WristSlot", "HandsSlot", "MainHandSlot", "SecondaryHandSlot" }

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Durability")

function W:Update()
    local lowest = 100
    for _, slot in ipairs(EQUIP_SLOTS) do
        local id = GetInventorySlotInfo(slot)
        local current, maximum = GetInventoryItemDurability(id)
        if current and maximum and maximum > 0 then
            local pct = (current / maximum) * 100
            if pct < lowest then lowest = pct end
        end
    end
    local color = lowest <= DURABILITY_LOW and "|cffff0000" or (lowest <= DURABILITY_MED and "|cffffa500" or "|cff00ff00")
    self:SetText(string.format("%s%.0f%%|r Dur", color, lowest))
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Equipment Durability", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    for _, slot in ipairs(EQUIP_SLOTS) do
        local id = GetInventorySlotInfo(slot)
        local current, maximum = GetInventoryItemDurability(id)
        if current and maximum and maximum > 0 then
            local pct = (current / maximum) * 100
            local color = pct <= DURABILITY_LOW and "|cffff0000" or (pct <= DURABILITY_MED and "|cffffa500" or "|cff00ff00")
            GameTooltip:AddDoubleLine(slot:gsub("Slot$", ""), string.format("%s%.0f%%|r", color, pct), 1, 1, 1, 1, 1, 1)
        end
    end
    local cost = GetRepairAllCost()
    if cost and cost > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Repair Cost:", DT.Formatting:FormatMoney(cost), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetUpdateTier("SLOW")
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

W:Init()
