-- Volume.lua
-- Volume datatext: master volume display with scroll-to-adjust
local _, Orbit = ...
local DT = Orbit.Datatexts
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local VOLUME_STEP = 0.05
local VOLUME_MIN = 0
local VOLUME_MAX = 1

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Volume")

function W:Update()
    local vol = tonumber(GetCVar("Sound_MasterVolume")) or 0
    local muted = GetCVarBool("Sound_EnableAllSound") == false
    if muted then
        self:SetText(L.PLU_DT_VOLUME_MUTED)
    else
        self:SetText(string.format("|cffffffff%d%%|r", vol * 100))
    end
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_VOLUME_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local vol = tonumber(GetCVar("Sound_MasterVolume")) or 0
    GameTooltip:AddDoubleLine(L.PLU_DT_VOLUME_MASTER, string.format("%d%%", vol * 100), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.PLU_DT_VOLUME_EFFECTS, string.format("%d%%", (tonumber(GetCVar("Sound_SFXVolume")) or 0) * 100), 1, 1, 1, 0.7, 0.7, 0.7)
    GameTooltip:AddDoubleLine(L.PLU_DT_VOLUME_MUSIC, string.format("%d%%", (tonumber(GetCVar("Sound_MusicVolume")) or 0) * 100), 1, 1, 1, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.PLU_DT_VOLUME_SCROLL, L.PLU_DT_VOLUME_ADJUST, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.PLU_DT_HINT_CLICK, L.PLU_DT_VOLUME_TOGGLE_MUTE, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function()
        local muted = GetCVarBool("Sound_EnableAllSound")
        SetCVar("Sound_EnableAllSound", muted and "0" or "1")
        self:Update()
    end)
    self.leftClickHint = L.PLU_DT_VOLUME_TOGGLE_MUTE
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnMouseWheel", function(_, delta)
        local vol = tonumber(GetCVar("Sound_MasterVolume")) or 0
        vol = math.max(VOLUME_MIN, math.min(VOLUME_MAX, vol + delta * VOLUME_STEP))
        SetCVar("Sound_MasterVolume", tostring(vol))
        self:Update()
    end)
    self:SetCategory("UTILITY")
    self:Register()
    self:Update()
end

W:Init()
