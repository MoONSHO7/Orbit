---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local SESSION_WINDOW_COUNT = DM.SessionWindowCount
local OFFSCREEN_X = -10000
local OFFSCREEN_Y = -10000

local Plugin = Orbit:GetPlugin(DM.SystemID)
if not Plugin then return end

-- [ BLIZZARD DAMAGEMETER DISABLE ] ------------------------------------------------------------------
-- Session windows: don't Hide() — Blizzard persists IsShown() and shown=false trips an assertsafe in CreateWindowData on next load.
local function NeutralizeSessionWindow(window)
    if window._orbitNeutralized then return end
    window:EnableMouse(false)
    window:SetMouseClickEnabled(false)
    window:SetMouseMotionEnabled(false)
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", OFFSCREEN_X, OFFSCREEN_Y)
    window:SetAlpha(0)
    window._orbitNeutralized = true
end

local function NeutralizeAllSessionWindows()
    for i = 1, SESSION_WINDOW_COUNT do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then NeutralizeSessionWindow(w) end
    end
end

function Plugin:DisableBlizzardMeter()
    local frame = _G.DamageMeter
    if not frame then return end
    OrbitEngine.NativeFrame:Disable(frame)
    NeutralizeAllSessionWindows()
    -- SetupSessionWindow is the single funnel for primary restore + secondary creation; hook to neutralize new ones.
    if not frame._orbitShowHooked then
        hooksecurefunc(frame, "SetupSessionWindow", NeutralizeAllSessionWindows)
        frame._orbitShowHooked = true
    end
end
