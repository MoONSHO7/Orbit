-- CombatTimer.lua
-- Combat timer datatext: encounter tracking, death counter, average combat duration
local _, Orbit = ...
local DT = Orbit.Datatexts
local RingBuffer = DT.Formatting.RingBuffer
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local UPDATE_INTERVAL_SEC = 0.5
local IDLE_TIMEOUT_SEC = 5
local SECONDS_PER_MINUTE = 60
local FRAME_WIDTH = 60
local FRAME_HEIGHT = 20
local COLOR_COMBAT = "|cffff0000"
local COLOR_IDLE = "|cff888888"
local COLOR_DONE = "|cff00ff00"
local COMBAT_HISTORY_SIZE = 5

-- [ HELPERS ] ---------------------------------------------------------------------------------------
local function FormatDuration(seconds)
    return string.format("%02d:%02d", math.floor(seconds / SECONDS_PER_MINUTE), math.floor(seconds % SECONDS_PER_MINUTE))
end

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("CombatTimer")

-- [ STATE ] -----------------------------------------------------------------------------------------
W.startTime = 0
W.inCombat = false
W.ticker = nil
W.encounterName = nil
W.encounterStart = 0
W.sessionDeaths = 0
W.combatHistory = RingBuffer:New(COMBAT_HISTORY_SIZE)

-- [ HELPERS ] ---------------------------------------------------------------------------------------
function W:GetAverageCombatDuration()
    if self.combatHistory:Count() == 0 then return 0 end
    local sum = 0
    for _, d in self.combatHistory:Iterate() do sum = sum + d end
    return sum / self.combatHistory:Count()
end

-- [ UPDATE ] ----------------------------------------------------------------------------------------
function W:Update()
    if not self.inCombat then
        self:SetText(COLOR_IDLE .. L.PLU_DT_COMBAT_STATUS_IDLE .. "|r")
        return
    end
    self:SetText(COLOR_COMBAT .. FormatDuration(GetTime() - self.startTime) .. "|r")
end

-- [ EVENTS ] ----------------------------------------------------------------------------------------
function W:OnCombatStart()
    self.inCombat = true
    self.startTime = GetTime()
    self.frame:Show()
    if self.ticker then self.ticker:Cancel() end
    self.ticker = C_Timer.NewTicker(UPDATE_INTERVAL_SEC, function() self:Update() end)
    self:Update()
end

function W:OnCombatEnd()
    self.inCombat = false
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    local duration = GetTime() - self.startTime
    
    if duration >= 5 and not InCombatLockdown() then
        self.combatHistory:Push(duration)
    end
    
    self:SetText(COLOR_DONE .. FormatDuration(duration) .. "|r")
    C_Timer.After(IDLE_TIMEOUT_SEC, function()
        if not self.inCombat then self:SetText(COLOR_IDLE .. L.PLU_DT_COMBAT_STATUS_IDLE .. "|r") end
    end)
end

function W:OnEncounterStart(_, _, encounterName)
    self.encounterName = encounterName
    self.encounterStart = GetTime()
end

function W:OnEncounterEnd(_, _, encounterName, _, _, success)
    if self.encounterStart > 0 then
        local duration = GetTime() - self.encounterStart
        local result = success == 1 and "|cff00ff00" .. L.PLU_DT_COMBAT_KILL or "|cffff0000" .. L.PLU_DT_COMBAT_WIPE
        print(L.MSG_DT_ENCOUNTER_RESULT_F:format(result, encounterName or self.encounterName or L.PLU_DT_COMBAT_BOSS, FormatDuration(duration)))
        self.encounterName = nil
        self.encounterStart = 0
    end
end

-- [ TOOLTIP ] ---------------------------------------------------------------------------------------
function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_COMBAT_TIMER_TITLE, 1, 0.82, 0)
    if self.inCombat then
        GameTooltip:AddDoubleLine(L.PLU_DT_COMBAT_DURATION, string.format("%.1fs", GetTime() - self.startTime), 1, 1, 1, 1, 1, 1)
        if self.encounterName then GameTooltip:AddDoubleLine(L.PLU_DT_COMBAT_ENCOUNTER, self.encounterName, 1, 1, 1, 1, 0.82, 0) end
        GameTooltip:AddLine(L.PLU_DT_COMBAT_STATUS_IN_COMBAT, 1, 0, 0)
    else
        GameTooltip:AddLine(L.PLU_DT_COMBAT_STATUS_LABEL_IDLE, 0.5, 0.5, 0.5)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.PLU_DT_COMBAT_SESSION_DEATHS, tostring(self.sessionDeaths), 1, 1, 1, 1, 0.3, 0.3)
    local avg = self:GetAverageCombatDuration()
    if avg > 0 then
        GameTooltip:AddDoubleLine(L.PLU_DT_COMBAT_AVG_COMBAT, FormatDuration(avg), 1, 1, 1, 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L.PLU_DT_COMBAT_RECENT_FIGHTS, 0.7, 0.7, 0.7)
        local fightNum = 0
        for _, dur in self.combatHistory:Iterate() do
            fightNum = fightNum + 1
            GameTooltip:AddDoubleLine(L.PLU_DT_COMBAT_FIGHT_LABEL_F:format(fightNum), FormatDuration(dur), 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.PLU_DT_HINT_CLICK, L.PLU_DT_GOLD_RESET_SESSION, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function W:Init()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function() self.sessionDeaths = 0; self.combatHistory = RingBuffer:New(COMBAT_HISTORY_SIZE); print("|cff00ff00" .. L.MSG_DT_COMBAT_TIMER_RESET .. "|r") end)
    self.leftClickHint = L.PLU_DT_GOLD_RESET_SESSION
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() self:OnCombatStart() end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() self:OnCombatEnd() end)
    self:RegisterEvent("ENCOUNTER_START", function(_, ...) self:OnEncounterStart(_, ...) end)
    self:RegisterEvent("ENCOUNTER_END", function(_, ...) self:OnEncounterEnd(_, ...) end)
    self:RegisterEvent("PLAYER_DEAD", function() self.sessionDeaths = self.sessionDeaths + 1 end)
    self:SetCategory("SYSTEM")
    self:Register()
    self:Update()
end

W:Init()
