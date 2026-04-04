-- Guild.lua
-- Guild datatext: online guild members count
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ datatext ] ----------------------------------------------------------------------
local W = DT.BaseDatatext:New("Guild")

function W:Update()
    if not IsInGuild() then self:SetText("|cff888888No Guild|r"); return end
    local total = GetNumGuildMembers() or 0
    local online = 0
    for i = 1, total do
        local _, _, _, _, _, _, _, _, isOnline, _, _, _, _, isMobile = GetGuildRosterInfo(i)
        if isOnline and not isMobile then online = online + 1 end
    end
    self:SetText(string.format("|cff00ff00%d|r Members", online))
end

function W:ShowTooltip()
    C_GuildInfo.GuildRoster() 
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    if not IsInGuild() then GameTooltip:AddLine("Not in a Guild", 0.5, 0.5, 0.5); GameTooltip:Show(); return end
    local guildName = GetGuildInfo("player")
    GameTooltip:AddLine(guildName or "Guild", 0, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local total = GetNumGuildMembers() or 0
    local online = 0
    local rosterLines = {}
    
    for i = 1, total do
        local name, rankName, rankIndex, level, classDisplayName, zone, _, _, isOnline, _, class, _, _, isMobile = GetGuildRosterInfo(i)
        if isOnline and not isMobile then
            online = online + 1
            if #rosterLines < 25 then
                local r, g, b = 1, 1, 1
                if class and Orbit.Engine.ClassColor then
                    r, g, b = Orbit.Engine.ClassColor:GetOverridesUnpacked(class)
                elseif class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
                    r, g, b = RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
                end
                name = string.match(name, "([^%-]+)") or name -- strip realm
                table.insert(rosterLines, { name = string.format("%s |cffaaaaaa%d|r", name, level or 0), zone = zone or "", r = r, g = g, b = b })
            end
        end
    end
    
    GameTooltip:AddDoubleLine("Online:", string.format("%d / %d", online, total), 1, 1, 1, 0.7, 0.7, 0.7)
    
    if online > 0 then
        GameTooltip:AddLine(" ")
        for _, line in ipairs(rosterLines) do
            GameTooltip:AddDoubleLine(line.name, line.zone, line.r, line.g, line.b, 0.7, 0.7, 0.7)
        end
        if online > 25 then
            GameTooltip:AddLine(string.format("... and %d more", online - 25), 0.7, 0.7, 0.7)
        end
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Guild Roster", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function() ToggleGuildFrame() end)
    self.leftClickHint = "Guild Roster"
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_GUILD_UPDATE")
    self:SetCategory("SOCIAL")
    self:Register()
    C_GuildInfo.GuildRoster()
    self:Update()
end

W:Init()
