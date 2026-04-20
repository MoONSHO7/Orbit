-- Location.lua
-- Location datatext: current zone name with PvP type coloring
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local PVP_COLORS = {
    sanctuary = { 0.41, 0.80, 0.94 },
    friendly  = { 0.0, 1.0, 0.0 },
    hostile   = { 1.0, 0.0, 0.0 },
    contested = { 1.0, 0.7, 0.0 },
}
local DEFAULT_COLOR = { 1, 0.82, 0 }

-- [ HELPERS ] ---------------------------------------------------------------------------------------
local function GetPvPColor()
    local pvpType = C_PvP.GetZonePVPInfo()
    return PVP_COLORS[pvpType] or DEFAULT_COLOR
end

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Location")

function W:Update()
    local zone = GetSubZoneText()
    if not zone or zone == "" then zone = GetZoneText() end
    local c = GetPvPColor()
    self:SetText(string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, zone or "Unknown"))
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Location", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Zone:", GetZoneText() or "Unknown", 1, 1, 1, 1, 1, 1)
    local subZone = GetSubZoneText()
    if subZone and subZone ~= "" then GameTooltip:AddDoubleLine("Sub-Zone:", subZone, 1, 1, 1, 0.7, 0.7, 0.7) end
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            GameTooltip:AddDoubleLine("Coords:", string.format("%.1f, %.1f", pos.x * 100, pos.y * 100), 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end

    local numSaved = GetNumSavedInstances()
    local numWorldBosses = GetNumSavedWorldBosses and GetNumSavedWorldBosses() or 0
    
    if numSaved > 0 or numWorldBosses > 0 then
        local hasLockouts = false
        
        for i = 1, numSaved do
            local name, _, _, _, locked, _, _, isRaid, _, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)
            if locked then
                if not hasLockouts then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Lockouts", 1, 0.82, 0)
                    hasLockouts = true
                end
                local progressMsg = (numEncounters and numEncounters > 0) and string.format("%d/%d", encounterProgress or 0, numEncounters) or "Defeated"
                local label = string.format("%s - %s", name or "Unknown", difficultyName or "")
                GameTooltip:AddDoubleLine(label, progressMsg, 1, 1, 1, 1, 1, 1)
            end
        end

        for i = 1, numWorldBosses do
            local name = GetSavedWorldBossInfo and GetSavedWorldBossInfo(i) or nil
            if name then
                if not hasLockouts then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Lockouts", 1, 0.82, 0)
                    hasLockouts = true
                end
                GameTooltip:AddDoubleLine(name, "Defeated", 1, 1, 1, 1, 0.2, 0.2)
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "World Map", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function() ToggleWorldMap() end)
    self.leftClickHint = "World Map"
    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("ZONE_CHANGED_INDOORS")
    self:SetCategory("WORLD")
    self:Register()
    self:Update()
end

W:Init()
