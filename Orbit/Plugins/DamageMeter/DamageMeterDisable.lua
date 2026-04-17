---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
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

local function NeutralizeSessionWindow(window)
    if not window or window._orbitNeutralized then return end
    window:EnableMouse(false)
    window:SetMouseClickEnabled(false)
    if window.SetMouseMotionEnabled then window:SetMouseMotionEnabled(false) end
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", OFFSCREEN_X, OFFSCREEN_Y)
    window:SetAlpha(0)
    window:Hide()
    window._orbitNeutralized = true
end

local function NeutralizeRoot(frame)
    if not frame or frame._orbitNeutralized then return end
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", GetHiddenParent(), "TOPLEFT", 0, 0)
    frame:Hide()
    frame._orbitNeutralized = true
end

-- hooksecurefunc cannot change return values, so hook UpdateShownState and re-hide after it runs.
local function InstallShowGuard(frame)
    if frame._orbitShowGuardInstalled then return end
    if not frame.UpdateShownState then return end
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
    for i = 1, 3 do
        NeutralizeSessionWindow(_G["DamageMeterSessionWindow" .. i])
    end
    -- Session windows are created lazily on first ShowNewSessionWindow — hook to neutralize new ones.
    if frame.ShowNewSessionWindow and not frame._orbitShowHooked then
        hooksecurefunc(frame, "ShowNewSessionWindow", function()
            for i = 1, 3 do
                NeutralizeSessionWindow(_G["DamageMeterSessionWindow" .. i])
            end
        end)
        frame._orbitShowHooked = true
    end
end
