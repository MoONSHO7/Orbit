-- [ ORBIT SLASH COMMAND ]----------------------------------------------------------------------------
local _, Orbit = ...

SLASH_ORBIT1 = "/orbit"
SLASH_ORBIT2 = "/orb"

SlashCmdList["ORBIT"] = function()
    Orbit.OptionsPanel:ToggleEditMode()
end
