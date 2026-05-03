local _, Orbit = ...
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Datatexts"
local POSITION_RESTORE_DELAY = 0.5

-- [ NAMESPACE ] -------------------------------------------------------------------------------------
Orbit.Datatexts = Orbit.Datatexts or {}

-- [ PLUGIN REGISTRATION ] ---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Datatexts", SYSTEM_ID, {
    liveToggle = true,
    defaults = {
        datatextPositions = {},
    },
})

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function Plugin:OnLoad()
    local DT = Orbit.Datatexts
    DT.DrawerUI:CreateCornerTriggers()
    C_Timer.After(POSITION_RESTORE_DELAY, function() DT.DatatextManager:RestorePositions() end)
end

function Plugin:ApplySettings()
    local DT = Orbit.Datatexts
    DT.DatatextManager:UpdateAllDatatexts()
end
