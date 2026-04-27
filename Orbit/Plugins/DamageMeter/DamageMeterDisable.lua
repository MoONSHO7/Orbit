---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter

local Plugin = Orbit:GetPlugin(DM.SystemID)
if not Plugin then return end

-- [ BLIZZARD DAMAGEMETER DISABLE ] ------------------------------------------------------------------
-- damageMeterEnabled CVar is set to 0 (see DamageMeter.lua), so UpdateShownState won't re-show the frame after Hide. Mirrors Details!'s pattern.
function Plugin:DisableBlizzardMeter()
    local frame = _G.DamageMeter
    if not frame then return end
    if InCombatLockdown() then return end
    frame:Hide()
    if frame.HideAllSessionWindows then frame:HideAllSessionWindows() end
end
