-- Quest.lua
-- Quest datatext: active quest count and tracker
local _, Orbit = ...
local DT = Orbit.Datatexts
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local MAX_QUESTS = 35
local QUEST_LOW = 25
local QUEST_HIGH = 30

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Quests")
W.activeCount = 0

function W:Update()
    local numQuests = C_QuestLog.GetNumQuestLogEntries()
    local active = 0
    for i = 1, numQuests do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden then active = active + 1 end
    end
    self.activeCount = active
    local color = active >= QUEST_HIGH and "|cffff0000" or (active >= QUEST_LOW and "|cffffa500" or "|cff00ff00")
    self:SetText(string.format("%s%d|r/%d Quests", color, active, MAX_QUESTS))
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_QUEST_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    local lastHeader = nil
    local shown = 0
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                lastHeader = info.title
            elseif not info.isHidden and shown < 20 then
                if lastHeader then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(lastHeader, 1, 0.82, 0)
                    lastHeader = nil
                end
                local level = info.difficultyLevel or 0
                local complete = C_QuestLog.IsComplete(info.questID)
                local status = complete and "|cff00ff00\226\156\147|r" or string.format("|cff888888[%d]|r", level)
                GameTooltip:AddDoubleLine(info.title, status, 1, 1, 1, 1, 1, 1)
                shown = shown + 1
            end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.PLU_DT_HINT_CLICK, L.PLU_DT_QUEST_TITLE, 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function() ToggleQuestLog() end)
    self.leftClickHint = L.PLU_DT_QUEST_TITLE
    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:Update()
end

W:Init()
