---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ MILESTONES ]-------------------------------------------------------------------------------------
function Plugin:SetupMilestones()
    if self._milestonesHooked then return end
    self._milestonesHooked = true
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LEVEL_UP")
    f:RegisterEvent("HONOR_LEVEL_UPDATE")
    if C_MajorFactions then f:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED") end
    f:SetScript("OnEvent", function(_, event, ...) self:OnMilestone(event, ...) end)
    self._milestoneFrame = f
end

function Plugin:OnMilestone(event, ...)
    if not self:GetSetting(self.system, "ShowMilestones") then return end
    if event == "PLAYER_LEVEL_UP" then
        local level = ...
        self:PlayLevelUpFlourish(level or UnitLevel("player") or 0)
    elseif event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
        local factionID, newLevel, oldLevel = ...
        local data = C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(factionID)
        self:PlayRenownFlourish(newLevel or 0, data and data.name or "", oldLevel)
    elseif event == "HONOR_LEVEL_UPDATE" then
        -- HONOR_LEVEL_UPDATE also fires on honor-xp gains; flourish only on a real increase, first update seeds the baseline.
        local new = UnitHonorLevel("player") or 0
        local old = self._honorLevel
        self._honorLevel = new
        if old and new > old then self:PlayHonorFlourish(new, old) end
    end
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
SLASH_ORBITLEVEL1 = "/orbitlevel"
SlashCmdList["ORBITLEVEL"] = function(arg)
    arg = arg and arg:lower()
    if arg == "renown" then
        local name = ""
        if C_MajorFactions and C_MajorFactions.GetMajorFactionIDs then
            local ids = C_MajorFactions.GetMajorFactionIDs(LE_EXPANSION_LEVEL_CURRENT)
            local data = ids and ids[1] and C_MajorFactions.GetMajorFactionData(ids[1])
            name = data and data.name or ""
        end
        Plugin:PlayRenownFlourish(12, name, 11)
    elseif arg == "honor" then
        local cur = UnitHonorLevel("player") or 50
        Plugin:PlayHonorFlourish(cur + 1, cur)
    else
        Plugin:PlayLevelUpFlourish((UnitLevel("player") or 70) + 1)
    end
end
