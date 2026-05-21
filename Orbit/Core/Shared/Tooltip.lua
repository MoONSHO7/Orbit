-- [ ORBIT TOOLTIP ]----------------------------------------------------------------------------------
local _, Orbit = ...

-- A private GameTooltip-template frame for every Orbit-owned hover tooltip.
-- Owning the shared global GameTooltip from addon code taints it (WoW 12.0+): Blizzard then
-- runs its own unit-tooltip pipeline (SetWorldCursor → UnitPlayerControlled, coloured lines)
-- on a tainted object, and the secret unit data is rejected. A separate frame keeps Orbit's
-- taint off the global tooltip entirely. Consumers alias it as `local GameTooltip = Orbit.Tooltip`.
Orbit.Tooltip = CreateFrame("GameTooltip", "OrbitTooltip", UIParent, "GameTooltipTemplate")
