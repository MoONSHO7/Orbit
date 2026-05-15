-- Hearthstone.lua
-- Hearthstone datatext: shows hearthstone location and cooldown
local _, Orbit = ...
local DT = Orbit.Datatexts
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
-- UI Constants
local HEARTHSTONE_ID = 6948
local SECONDS_PER_MINUTE = 60
local BAG_COUNT = 4

local HEARTHSTONE_TOYS = {
    { itemID = 54452, name = "Ethereal Portal", type = "toy" },
    { itemID = 64488, name = "The Innkeeper's Daughter", type = "toy" },
    { itemID = 93672, name = "Dark Portal", type = "toy" },
    { itemID = 142542, name = "Tome of Town Portal", type = "toy" },
    { itemID = 162973, name = "Greatfather Winter's Hearthstone", type = "toy" },
    { itemID = 163045, name = "Headless Horseman's Hearthstone", type = "toy" },
    { itemID = 163206, name = "Weary Spirit Binding", type = "toy" },
    { itemID = 165669, name = "Lunar Elder's Hearthstone", type = "toy" },
    { itemID = 165670, name = "Peddlefeet's Lovely Hearthstone", type = "toy" },
    { itemID = 165802, name = "Noble Gardener's Hearthstone", type = "toy" },
    { itemID = 166746, name = "Fire Eater's Hearthstone", type = "toy" },
    { itemID = 166747, name = "Brewfest Reveler's Hearthstone", type = "toy" },
    { itemID = 168907, name = "Holographic Digitalization Hearthstone", type = "toy" },
    { itemID = 172179, name = "Eternal Traveler's Hearthstone", type = "toy" },
    { itemID = 180290, name = "Night Fae Hearthstone", type = "toy" },
    { itemID = 182773, name = "Necrolord Hearthstone", type = "toy" },
    { itemID = 183716, name = "Venthyr Sinstone", type = "toy" },
    { itemID = 184353, name = "Kyrian Hearthstone", type = "toy" },
    { itemID = 188952, name = "Dominated Hearthstone", type = "toy" },
    { itemID = 190237, name = "Broker Translocation Matrix", type = "toy" },
    { itemID = 193588, name = "Timewalker's Hearthstone", type = "toy" },
    { itemID = 200630, name = "Ohn'ir Windsage's Hearthstone", type = "toy" },
    { itemID = 206195, name = "Path of the Naaru", type = "toy" },
    { itemID = 208704, name = "Deepdweller's Earthen Hearthstone", type = "toy" },
    { itemID = 209035, name = "Hearthstone of the Flame", type = "toy" },
    { itemID = 210455, name = "Draenic Hologem", type = "toy" },
    { itemID = 212337, name = "Stone of the Hearth", type = "toy" },
    { itemID = 228940, name = "Notorious Thread's Hearthstone", type = "toy" },
    { itemID = 257736, name = "Lightcalled Hearthstone", type = "toy" },
    { itemID = 263933, name = "Preyseeker's Hearthstone", type = "toy" },
    { itemID = 265100, name = "Corewarden's Hearthstone", type = "toy" },
}

local function HearthstoneItemName()
    return (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(HEARTHSTONE_ID)) or L.PLU_DT_HEARTH_TITLE
end

local function GetAvailableHearthstones()
    local available = {}
    for bag = 0, BAG_COUNT do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == HEARTHSTONE_ID then
                available[#available + 1] = { itemID = HEARTHSTONE_ID, name = HearthstoneItemName(), type = "item" }
                break
            end
        end
        if #available > 0 then break end
    end

    if PlayerHasToy then
        for _, toy in ipairs(HEARTHSTONE_TOYS) do
            if PlayerHasToy(toy.itemID) and C_ToyBox.IsToyUsable(toy.itemID) then
                available[#available + 1] = toy
            end
        end
    end

    if #available == 0 then
        available[#available + 1] = { itemID = HEARTHSTONE_ID, name = HearthstoneItemName(), type = "item" }
    end
    return available
end

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Hearthstone")
W.availableCache = nil

function W:Update()
    local start, duration, enabled = C_Container.GetItemCooldown(HEARTHSTONE_ID)
    if enabled == 1 and duration > 2 then
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            self.iconTexture:SetAtlas("Crosshair_unableinnkeeper_128")
            return
        end
    end
    self.iconTexture:SetAtlas("Crosshair_innkeeper_128")
end

function W:RebuildCache()
    self.availableCache = GetAvailableHearthstones()
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_HEARTH_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local bindLoc = GetBindLocation()
    GameTooltip:AddDoubleLine(L.PLU_DT_HEARTH_LOCATION, bindLoc or L.PLU_DT_LOCATION_UNKNOWN, 1, 1, 1, 1, 1, 1)
    local start, duration, enabled = C_Container.GetItemCooldown(HEARTHSTONE_ID)
    if enabled == 1 and duration > 2 then
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            GameTooltip:AddDoubleLine(L.PLU_DT_HEARTH_COOLDOWN, DT.Formatting:FormatTime(remaining), 1, 1, 1, 1, 0.5, 0)
        else
            GameTooltip:AddDoubleLine(L.PLU_DT_HEARTH_STATUS, L.PLU_DT_HEARTH_READY, 1, 1, 1, 1, 1, 1)
        end
    else
        GameTooltip:AddDoubleLine(L.PLU_DT_HEARTH_STATUS, L.PLU_DT_HEARTH_READY, 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.PLU_DT_HINT_CLICK, L.PLU_DT_HEARTH_USE, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self.isSecure = true
    self:CreateFrame()
    
    self.text:SetText("")
    self.text:Hide()
    self.frame:SetSize(20, 20)
    
    self.iconTexture = self.frame:CreateTexture(nil, "ARTWORK")
    self.iconTexture:SetSize(20, 20)
    self.iconTexture:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    self.iconTexture:SetAtlas("Crosshair_innkeeper_128")
    
    self:SetUpdateFunc(function() self:Update() end)
    self:SetUpdateTier("NORMAL")
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    
    self.frame:SetScript("PreClick", function(f, button)
        if button == "RightButton" or InCombatLockdown() then return end
        local available = self.availableCache or GetAvailableHearthstones()
        if #available > 0 then
            local randomIndex = math.random(1, #available)
            local chosen = available[randomIndex]
            if chosen.type == "toy" then
                f:SetAttribute("type1", "toy")
                f:SetAttribute("toy1", chosen.itemID)
                f:SetAttribute("item1", nil)
            else
                f:SetAttribute("type1", "item")
                f:SetAttribute("item1", chosen.name)
                f:SetAttribute("toy1", nil)
            end
        end
    end)
    
    self.leftClickHint = L.PLU_DT_HEARTH_RANDOM
    self:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self:RegisterEvent("BAG_UPDATE", function() self:RebuildCache() end)
    self:RegisterEvent("TOYS_UPDATED", function() self:RebuildCache() end)
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:RebuildCache()
    self:Update()
end

W:Init()
