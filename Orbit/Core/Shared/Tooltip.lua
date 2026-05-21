-- [ ORBIT TOOLTIP ]----------------------------------------------------------------------------------
local _, Orbit = ...

-- Private tooltip — owning the shared global GameTooltip taints it (12.0+), and Blizzard's secret unit data is rejected on a tainted object.
Orbit.Tooltip = CreateFrame("GameTooltip", "OrbitTooltip", UIParent, "GameTooltipTemplate")
