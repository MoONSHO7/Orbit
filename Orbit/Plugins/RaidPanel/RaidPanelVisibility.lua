-- RaidPanelVisibility.lua: Visibility gate — in a group AND player has lead or assist.

local _, Orbit = ...

local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsGroupAssistant = UnitIsGroupAssistant
local GetPartyAssignment = GetPartyAssignment

-- [ MODULE ] ----------------------------------------------------------------------------------------
Orbit.RaidPanelVisibility = {}
local Visibility = Orbit.RaidPanelVisibility

function Visibility.ShouldShow()
    if not IsInGroup() then return false end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function Visibility.IsRaidLeaderTier()
    if not IsInRaid() then return false end
    if UnitIsGroupLeader("player") then return true end
    if UnitIsGroupAssistant("player") then return true end
    return GetPartyAssignment("MAINTANK", "player") and true or false
end
