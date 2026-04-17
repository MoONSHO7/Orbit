---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local SIGNAL = DM.Events
local BRIDGE_FRAME_NAME = "OrbitDamageMeterEventBridge"

local Plugin = Orbit:GetPlugin(DM.SystemID)
if not Plugin then return end

-- [ EVENT BRIDGE ] ----------------------------------------------------------------------------------
local BLIZZ_EVENTS = {
    "DAMAGE_METER_COMBAT_SESSION_UPDATED",
    "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    "DAMAGE_METER_RESET",
}

local function OnBridgeEvent(_, event, ...)
    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        Orbit.EventBus:Fire(SIGNAL.SessionUpdated, ...)
    elseif event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" then
        Orbit.EventBus:Fire(SIGNAL.CurrentUpdated)
    elseif event == "DAMAGE_METER_RESET" then
        Orbit.EventBus:Fire(SIGNAL.SessionReset)
    end
end

function Plugin:InitEventBridge()
    if self._eventBridge then return end
    local frame = CreateFrame("Frame", BRIDGE_FRAME_NAME, UIParent)
    for _, event in ipairs(BLIZZ_EVENTS) do frame:RegisterEvent(event) end
    frame:SetScript("OnEvent", OnBridgeEvent)
    self._eventBridge = frame
end
