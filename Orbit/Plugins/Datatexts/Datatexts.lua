-- Datatexts.lua
-- Plugin entry point — registers the Datatexts system as an experimental Orbit plugin
local _, Orbit = ...
local OrbitEngine = Orbit.Engine

-- [ NAMESPACE ] -------------------------------------------------------------------
Orbit.Datatexts = Orbit.Datatexts or {}

-- [ PLUGIN REGISTRATION ] ---------------------------------------------------------
local SYSTEM_ID = "Orbit_Datatexts"

local Plugin = Orbit:RegisterPlugin("Datatexts", SYSTEM_ID, {
    liveToggle = true,
    defaults = {
        datatextPositions = {},
    },
})

-- [ LIFECYCLE ] -------------------------------------------------------------------
function Plugin:OnLoad()
    local DT = Orbit.Datatexts
    DT.DrawerUI:CreateCornerTriggers()
    C_Timer.After(0.5, function() DT.DatatextManager:RestorePositions() end)
end

function Plugin:ApplySettings()
    local DT = Orbit.Datatexts
    DT.DatatextManager:UpdateAllDatatexts()
end
