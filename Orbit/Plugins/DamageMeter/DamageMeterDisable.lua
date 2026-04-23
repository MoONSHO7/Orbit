---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local SESSION_WINDOW_COUNT = DM.SessionWindowCount
local OFFSCREEN_X = -10000
local OFFSCREEN_Y = -10000
local HIDDEN_PARENT_NAME = "OrbitDamageMeterHiddenParent"

local Plugin = Orbit:GetPlugin(DM.SystemID)
if not Plugin then return end

-- [ BLIZZARD DAMAGEMETER DISABLE ] ------------------------------------------------------------------
local hiddenParent
local function GetHiddenParent()
    if hiddenParent then return hiddenParent end
    hiddenParent = CreateFrame("Frame", HIDDEN_PARENT_NAME, UIParent)
    hiddenParent:Hide()
    hiddenParent:SetPoint("TOPLEFT", UIParent, "TOPLEFT", OFFSCREEN_X, OFFSCREEN_Y)
    hiddenParent:SetSize(1, 1)
    return hiddenParent
end

local function NeutralizeAllSessionWindows()
    for i = 1, SESSION_WINDOW_COUNT do
        local window = _G["DamageMeterSessionWindow" .. i]
        if window and not window._orbitNeutralized then
            -- Don't Hide(): Blizzard persists IsShown() and a saved shown=false trips a non-fatal
            -- assertsafe in CreateWindowData on next load. Push offscreen + invisible instead.
            window:EnableMouse(false)
            window:SetMouseClickEnabled(false)
            window:SetMouseMotionEnabled(false)
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", OFFSCREEN_X, OFFSCREEN_Y)
            window:SetAlpha(0)
            window._orbitNeutralized = true
        end
    end
end

local function NeutralizeRoot(frame)
    if frame._orbitNeutralized then return end
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    frame:SetMouseClickEnabled(false)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", GetHiddenParent(), "TOPLEFT", 0, 0)
    frame:Hide()
    frame._orbitNeutralized = true
end

-- hooksecurefunc cannot change return values, so hook UpdateShownState and re-hide after it runs.
local function InstallShowGuard(frame)
    if frame._orbitShowGuardInstalled then return end
    hooksecurefunc(frame, "UpdateShownState", function(self)
        if self:IsShown() then self:Hide() end
    end)
    frame._orbitShowGuardInstalled = true
end

function Plugin:DisableBlizzardMeter()
    local frame = _G.DamageMeter
    if not frame then return end
    NeutralizeRoot(frame)
    InstallShowGuard(frame)
    NeutralizeAllSessionWindows()
    -- Session windows are created lazily on first ShowNewSessionWindow — hook to neutralize new ones.
    if not frame._orbitShowHooked then
        hooksecurefunc(frame, "ShowNewSessionWindow", NeutralizeAllSessionWindows)
        frame._orbitShowHooked = true
    end
end
