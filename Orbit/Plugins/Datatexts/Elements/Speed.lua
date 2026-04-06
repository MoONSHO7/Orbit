-- Speed.lua
-- Movement speed datatext: shows current speed percentage
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------
local BASE_SPEED = 7

-- [ datatext ] ----------------------------------------------------------------------
local W = DT.BaseDatatext:New("Speed")

function W:Update()
    local speed = GetUnitSpeed("player")
    local pct = (speed / BASE_SPEED) * 100
    if pct > 0 then
        self:SetText(string.format("|cff00ff00%.0f%%|r", pct))
    else
        self:SetText("|cff888888Idle|r")
    end
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Movement Speed", 1, 0.82, 0)
    local speed = GetUnitSpeed("player")
    local pct = (speed / BASE_SPEED) * 100
    GameTooltip:AddDoubleLine("Current:", string.format("%.0f%%", pct), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Yards/sec:", string.format("%.1f", speed), 1, 1, 1, 0.7, 0.7, 0.7)
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
