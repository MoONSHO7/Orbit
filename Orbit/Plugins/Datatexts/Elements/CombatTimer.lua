local _, Orbit = ...
local DT = Orbit.Datatexts
local GameTooltip = Orbit.Tooltip
local RingBuffer = DT.Formatting.RingBuffer
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local UPDATE_INTERVAL_SEC = 0.5
local IDLE_TIMEOUT_SEC = 5
local MIN_TRACKED_COMBAT_SEC = 5
local SECONDS_PER_MINUTE = 60
local FRAME_WIDTH = 60
local FRAME_HEIGHT = 20
local COLOR_COMBAT = "|cffff0000"
local COLOR_IDLE = "|cff888888"
local COLOR_DONE = "|cff00ff00"
local COMBAT_HISTORY_SIZE = 5
local RESULT_DISPLAY_SEC = 15

-- [ HELPERS ] ---------------------------------------------------------------------------------------
local function FormatDuration(seconds)
    return string.format("%02d:%02d", math.floor(seconds / SECONDS_PER_MINUTE), math.floor(seconds % SECONDS_PER_MINUTE))
end

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("CombatTimer", L.PLU_DT_COMBAT_TIMER_NAME)

-- [ STATE ] -----------------------------------------------------------------------------------------
W.startTime = 0
W.inCombat = false
W.ticker = nil
W.encounterName = nil
W.encounterStart = 0
W.sessionDeaths = 0
W.combatHistory = RingBuffer:New(COMBAT_HISTORY_SIZE)
W._resultText = nil
W._resultExpiry = 0
W._resultTicker = nil
W._pendingEncounter = nil

-- [ HELPERS ] ---------------------------------------------------------------------------------------
function W:GetAverageCombatDuration()
    if self.combatHistory:Count() == 0 then return 0 end
    local sum = 0
    for _, d in self.combatHistory:Iterate() do sum = sum + d.duration end
    return sum / self.combatHistory:Count()
end

-- [ UPDATE ] ----------------------------------------------------------------------------------------
function W:Update()
    if self._resultText then return end
    if not self.inCombat then
        self:SetText(COLOR_IDLE .. L.PLU_DT_COMBAT_STATUS_IDLE .. "|r")
        return
    end
    self:SetText(COLOR_COMBAT .. FormatDuration(GetTime() - self.startTime) .. "|r")
end

-- [ ENCOUNTER RESULT ] ------------------------------------------------------------------------------
function W:ClearResult()
    if self._resultTicker then self._resultTicker:Cancel(); self._resultTicker = nil end
    self._resultText = nil
end

-- Pin the Kill/Wipe report on the widget; hold it for RESULT_DISPLAY_SEC and while hovered, then revert.
function W:ShowResult(text)
    self._resultText = text
    self._resultExpiry = GetTime() + RESULT_DISPLAY_SEC
    self.frame:Show()
    self:SetText(text)
    if self._resultTicker then self._resultTicker:Cancel() end
    self._resultTicker = C_Timer.NewTicker(UPDATE_INTERVAL_SEC, function()
        if GetTime() < self._resultExpiry or self.isHovered then return end
        self:ClearResult()
        self:Update()
    end)
end

-- [ EVENTS ] ----------------------------------------------------------------------------------------
function W:OnCombatStart()
    self:ClearResult()
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
    
    if duration >= MIN_TRACKED_COMBAT_SEC then
        local entry = { duration = duration }
        if self._pendingEncounter then entry.name = self._pendingEncounter.name; entry.success = self._pendingEncounter.success end
        self.combatHistory:Push(entry)
    end
    self._pendingEncounter = nil

    if self._resultText then return end
    self:SetText(COLOR_DONE .. FormatDuration(duration) .. "|r")
    C_Timer.After(IDLE_TIMEOUT_SEC, function()
        if not self.inCombat and not self._resultText then self:SetText(COLOR_IDLE .. L.PLU_DT_COMBAT_STATUS_IDLE .. "|r") end
    end)
end

function W:OnEncounterStart(_, _, encounterName)
    self.encounterName = encounterName
    self.encounterStart = GetTime()
end

function W:OnEncounterEnd(_, _, encounterName, _, _, success)
    if self.encounterStart > 0 then
        local duration = GetTime() - self.encounterStart
        local isKill = success == 1
        local bossName = encounterName or self.encounterName or L.PLU_DT_COMBAT_BOSS
        local result = isKill and COLOR_DONE .. L.PLU_DT_COMBAT_KILL or COLOR_COMBAT .. L.PLU_DT_COMBAT_WIPE
        self:ShowResult(L.MSG_DT_ENCOUNTER_RESULT_F:format(result, bossName, FormatDuration(duration)))
        self._pendingEncounter = { name = bossName, success = isKill }
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
        for _, fight in self.combatHistory:Iterate() do
            fightNum = fightNum + 1
            local label
            if fight.name then
                label = (fight.success and COLOR_DONE or COLOR_COMBAT) .. fight.name .. "|r"
            else
                label = L.PLU_DT_COMBAT_FIGHT_LABEL_F:format(fightNum)
            end
            GameTooltip:AddDoubleLine(label, FormatDuration(fight.duration), 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.CMN_LEFT_CLICK, L.PLU_DT_GOLD_RESET_SESSION, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.CMN_RIGHT_CLICK, L.PLU_DT_GOLD_SETTINGS, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function W:Init()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn)
        if btn == "RightButton" then self:ShowContextMenu(); return end
        self.sessionDeaths = 0; self.combatHistory = RingBuffer:New(COMBAT_HISTORY_SIZE); print("|cff00ff00" .. L.MSG_DT_COMBAT_TIMER_RESET .. "|r")
    end)
    self.leftClickHint = L.PLU_DT_GOLD_RESET_SESSION
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() self:OnCombatStart() end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() self:OnCombatEnd() end)
    self:RegisterEvent("ENCOUNTER_START", function(_, ...) self:OnEncounterStart(...) end)
    self:RegisterEvent("ENCOUNTER_END", function(_, ...) self:OnEncounterEnd(...) end)
    self:RegisterEvent("PLAYER_DEAD", function() self.sessionDeaths = self.sessionDeaths + 1 end)
    self:Register()
    self:Update()
end

W:Init()
