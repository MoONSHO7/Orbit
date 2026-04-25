-- Time.lua
-- Time datatext: local/realm time with calendar tooltip
local _, Orbit = ...
local DT = Orbit.Datatexts
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local FORMAT_12H = "%I:%M %p"
local FORMAT_24H = "%H:%M"

-- [ STATE ] -----------------------------------------------------------------------------------------
local use24h = true

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Time")

function W:Update()
    local format = use24h and FORMAT_24H or FORMAT_12H
    self:SetText(date(format))
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_TIME_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Local:", date(use24h and FORMAT_24H or FORMAT_12H), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Server:", GetGameTime() and string.format("%02d:%02d", GetGameTime()) or "N/A", 1, 1, 1, 0.7, 0.7, 0.7)
    GameTooltip:AddDoubleLine("Date:", date("%Y-%m-%d"), 1, 1, 1, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", L.PLU_DT_TIME_HINT_TOGGLE, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", L.PLU_DT_TIME_HINT_CALENDAR, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:GetMenuItems()
    return {
        { text = L.PLU_DT_TIME_24H, checked = use24h, func = function() use24h = not use24h; self:Update() end, closeOnClick = false },
    }
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetUpdateTier("NORMAL")
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn)
        if btn == "RightButton" then if ToggleCalendar then ToggleCalendar() end
        else use24h = not use24h; self:Update() end
    end)
    self.leftClickHint = L.PLU_DT_TIME_HINT_TOGGLE
    self.rightClickHint = L.PLU_DT_TIME_HINT_CALENDAR
    self:SetCategory("UTILITY")
    self:Register()
    self:Update()
end

W:Init()
