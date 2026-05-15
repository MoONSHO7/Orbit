---@type Orbit
local Orbit = Orbit
local L = Orbit.L

-- [ TOOLTIP BUILDER ]--------------------------------------------------------------------------------
-- Centralised hover-tooltip content for the three bars. Each `Show*` function adopts GameTooltip
-- at the owner anchor and writes several lines of progression + session stats.

Orbit.StatusBarTooltip = {}
local Tooltip = Orbit.StatusBarTooltip

local Session = Orbit.StatusBarSession
local PendingXP = Orbit.StatusBarPendingXP

local function FormatNumber(n)
    if not n then return "0" end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(n)) or tostring(math.floor(n))
end

local function FormatETA(seconds)
    if not seconds or seconds <= 0 or seconds == math.huge then return "—" end
    if seconds < 60 then return string.format("%ds", seconds) end
    if seconds < 3600 then return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60) end
    return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
end

local function AddSession(trackerKey, gainedLabel, perHourLabel, unitColor)
    local gained, rate = Session:GetStats(trackerKey)
    if gained and gained > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(gainedLabel, FormatNumber(gained), 0.8, 0.8, 0.8, unitColor[1], unitColor[2], unitColor[3])
        if rate and rate > 0 then
            GameTooltip:AddDoubleLine(perHourLabel, FormatNumber(rate), 0.8, 0.8, 0.8, unitColor[1], unitColor[2], unitColor[3])
        end
    end
    return gained, rate
end

-- [ XP TOOLTIP ]-------------------------------------------------------------------------------------
function Tooltip:ShowXP(owner, level, currentXP, maxXP)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(L.PLU_XP_TITLE_F:format(level or UnitLevel("player")), 1, 1, 1)

    local xpSafe = currentXP and maxXP and not issecretvalue(currentXP) and not issecretvalue(maxXP) and maxXP > 0
    if xpSafe then
        local pct = (currentXP / maxXP) * 100
        GameTooltip:AddDoubleLine(L.CMN_PROGRESS, string.format("%s / %s (%.1f%%)", FormatNumber(currentXP), FormatNumber(maxXP), pct), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.CMN_REMAINING, FormatNumber(maxXP - currentXP), 0.8, 0.8, 0.8, 1, 1, 1)
    end

    local rested = GetXPExhaustion() or 0
    if rested > 0 and xpSafe then
        GameTooltip:AddDoubleLine(L.PLU_XP_RESTED, string.format("%s (%.0f%%)", FormatNumber(rested), (rested / maxXP) * 100), 0.5, 0.7, 1.0, 0.5, 0.7, 1.0)
    end

    -- Pending XP from complete quests
    local pending = PendingXP:Sum()
    if pending > 0 and xpSafe then
        local willDing = (currentXP + pending) >= maxXP
        GameTooltip:AddDoubleLine(L.PLU_XP_PENDING_QUESTS,
            string.format("%s%s", FormatNumber(pending), willDing and ("  |cff00ff00" .. L.PLU_XP_ENOUGH_TO_LEVEL .. "|r") or ""),
            0.6, 1.0, 0.6, 0.6, 1.0, 0.6)
    end

    -- Session
    local _, rate = AddSession("Orbit_ExperienceBar", L.PLU_XP_SESSION_GAINED, L.PLU_XP_PER_HOUR, { 0.9, 0.6, 1.0 })
    if rate and rate > 0 and xpSafe then
        local remaining = maxXP - currentXP
        local eta = (remaining / rate) * 3600
        GameTooltip:AddDoubleLine(L.PLU_XP_TIME_TO_LEVEL, FormatETA(eta), 0.8, 0.8, 0.8, 1, 0.82, 0)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff888888" .. L.PLU_XP_HINT_CHAR_PANEL .. "|r", 1, 1, 1)
    GameTooltip:AddLine("|cff888888" .. L.PLU_XP_HINT_LINK_CHAT .. "|r", 1, 1, 1)
    GameTooltip:AddLine("|cff888888" .. L.PLU_XP_HINT_RESET_SESSION .. "|r", 1, 1, 1)
    GameTooltip:Show()
end

-- [ REPUTATION TOOLTIP ]-----------------------------------------------------------------------------
function Tooltip:ShowRep(owner, record, isAccountWide, paragonCycles)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(record.name or L.PLU_REP_DEFAULT_NAME, 1, 1, 1)

    if isAccountWide then
        GameTooltip:AddLine("|cff4db8ff" .. L.PLU_REP_WARBAND .. "|r", 0.3, 0.7, 1.0)
    end

    if record.level and record.level ~= "" then
        GameTooltip:AddDoubleLine(L.PLU_REP_STANDING, record.level, 0.8, 0.8, 0.8, 1, 1, 1)
    end
    local span = (record.max or 1) - (record.min or 0)
    local progress = (record.current or 0) - (record.min or 0)
    if span > 0 then
        GameTooltip:AddDoubleLine(L.CMN_PROGRESS,
            string.format("%s / %s (%.1f%%)", FormatNumber(progress), FormatNumber(span), (progress / span) * 100),
            0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.CMN_REMAINING, FormatNumber(span - progress), 0.8, 0.8, 0.8, 1, 1, 1)
    end

    if paragonCycles and paragonCycles > 0 then
        GameTooltip:AddDoubleLine(L.PLU_REP_PARAGON_CYCLES, tostring(paragonCycles), 1.0, 0.5, 0.0, 1.0, 0.8, 0.0)
    end

    AddSession("Orbit_ExperienceBar", L.PLU_REP_SESSION_GAINED, L.PLU_REP_PER_HOUR, { 0.9, 0.9, 0.5 })

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff888888" .. L.PLU_REP_HINT_REP_PANEL .. "|r", 1, 1, 1)
    GameTooltip:AddLine("|cff888888" .. L.PLU_XP_HINT_LINK_CHAT .. "|r", 1, 1, 1)
    GameTooltip:AddLine("|cff888888" .. L.PLU_XP_HINT_RESET_SESSION .. "|r", 1, 1, 1)
    GameTooltip:Show()
end

-- [ HONOR TOOLTIP ]----------------------------------------------------------------------------------
function Tooltip:ShowHonor(owner, level, current, max)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(L.PLU_HONOR_TITLE_F:format(level or 0), 1, 1, 1)

    if max and max > 0 and not issecretvalue(current) and not issecretvalue(max) then
        GameTooltip:AddDoubleLine(L.CMN_PROGRESS,
            string.format("%s / %s (%.1f%%)", FormatNumber(current), FormatNumber(max), (current / max) * 100),
            0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.CMN_REMAINING, FormatNumber(max - current), 0.8, 0.8, 0.8, 1, 1, 1)
    end

    local _, rate = AddSession("Orbit_HonorBar", L.PLU_HONOR_SESSION_GAINED, L.PLU_HONOR_PER_HOUR, { 0.95, 0.45, 0.15 })
    if rate and rate > 0 and max and max > 0 and not issecretvalue(current) and not issecretvalue(max) then
        local remaining = max - current
        GameTooltip:AddDoubleLine(L.PLU_HONOR_TIME_TO_RANK, FormatETA((remaining / rate) * 3600), 0.8, 0.8, 0.8, 1, 0.82, 0)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff888888" .. L.PLU_HONOR_HINT_PVP_PANEL .. "|r", 1, 1, 1)
    GameTooltip:AddLine("|cff888888" .. L.PLU_HONOR_HINT_RESET_SESSION .. "|r", 1, 1, 1)
    GameTooltip:Show()
end

function Tooltip:Hide()
    GameTooltip:Hide()
end
