---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Bar v2")

-- [ MILESTONES ]-------------------------------------------------------------------------------------
-- Event-driven flourishes that aren't Blizzard toasts: a level-up, a major-faction renown level-up, and an
-- honor (PvP) level-up. All replay through the flourish queue as the same centre production
-- (`_RenderMilestone`) with per-milestone sprites — level-up gold with the level, renown rep-colour with the
-- renown level + faction name, honor red with the honor level + "Honor" + the honor-system prestige flash.

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
        -- HONOR_LEVEL_UPDATE also fires on honor-xp gains; only a real level increase flourishes. The first
        -- update just seeds the baseline (no flourish on login).
        local new = UnitHonorLevel("player") or 0
        local old = self._honorLevel
        self._honorLevel = new
        if old and new > old then self:PlayHonorFlourish(new, old) end
    end
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
-- "/orbitlevel" previews the level-up; "/orbitlevel renown" the renown production (using a current major
-- faction's name); "/orbitlevel honor" the honor (PvP) production.
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
