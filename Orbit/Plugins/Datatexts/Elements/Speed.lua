-- Speed.lua
-- Movement speed datatext: shows current speed percentage
local _, Orbit = ...
local DT = Orbit.Datatexts
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local BASE_SPEED = 7

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Speed")

function W:Update()
    local speed = GetUnitSpeed("player")
    if issecretvalue(speed) then return end
    local pct = (speed / BASE_SPEED) * 100
    if pct > 0 then
        self:SetText(string.format("|cff00ff00%.0f%%|r", pct))
    else
        self:SetText("|cff888888" .. L.PLU_DT_COMBAT_STATUS_IDLE .. "|r")
    end
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_SPEED_TITLE, 1, 0.82, 0)
    local speed = GetUnitSpeed("player")
    if issecretvalue(speed) then
        GameTooltip:Show()
        return
    end
    local pct = (speed / BASE_SPEED) * 100
    GameTooltip:AddDoubleLine(L.PLU_DT_SPEED_CURRENT, string.format("%.0f%%", pct), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.PLU_DT_SPEED_YARDS, string.format("%.1f", speed), 1, 1, 1, 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetUpdateTier("FAST")
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

W:Init()
