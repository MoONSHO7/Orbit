-- RaidPanelVisibility.lua: Visibility gate — in a group AND player has lead or assist.

local _, Orbit = ...

local IsInGroup = IsInGroup
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsGroupAssistant = UnitIsGroupAssistant

-- [ MODULE ] ----------------------------------------------------------------------------------------
Orbit.RaidPanelVisibility = {}
local Visibility = Orbit.RaidPanelVisibility

function Visibility.ShouldShow()
    if not IsInGroup() then return false end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end
