-- [ MOUNTED VISIBILITY MANAGER ]--------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MOUNTED_COMBAT_PREFIX = "[mounted,nocombat] hide; "
local MOUNTED_ALWAYS_PREFIX = "[mounted] hide; "
local OPEN_WORLD_INSTANCE_TYPES = { ["none"] = true, ["scenario"] = true }
local REAPPLY_DELAY = 0.5
local OVERLAY_LEVEL_BOOST = 100
local DRUID_TRAVEL_FORMS = { [DRUID_TRAVEL_FORM] = true, [DRUID_FLIGHT_FORM] = true }

---@class MountedVisibilityManager
local Manager = {}
Orbit.MountedVisibility = Manager

local cachedShouldHide = false

-- [ CORE LOGIC ]------------------------------------------------------------------------------------
local function IsInDruidTravelForm() return DRUID_TRAVEL_FORMS[GetShapeshiftFormID()] == true end

local function IsMountedHideActive()
    if Orbit.IsEditMode and Orbit:IsEditMode() then return false end
    if OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then return false end
    if not IsMounted() and not IsInDruidTravelForm() then return false end
    if not Orbit.VisibilityEngine or not Orbit.VisibilityEngine:AnyFrameHasSetting("hideMounted") then return false end
    local _, instanceType = IsInInstance()
    return OPEN_WORLD_INSTANCE_TYPES[instanceType] == true
end

function Manager:ShouldHide() return IsMountedHideActive() end
function Manager:IsCachedHidden() return cachedShouldHide end



function Manager:GetMountedDriver(baseDriver, combatEssential)
    if not self:ShouldHide() then return baseDriver end
    local prefix = combatEssential and MOUNTED_COMBAT_PREFIX or MOUNTED_ALWAYS_PREFIX
    return prefix .. baseDriver
end



-- [ BLIZZARD HOVER OVERLAYS ]-----------------------------------------------------------------------
local function CreateSimpleHoverOverlay(frame, revealFn, suppressFn)
    if not frame or frame.orbitHoverOverlay then return end
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + OVERLAY_LEVEL_BOOST)
    overlay:EnableMouse(true); overlay:SetMouseMotionEnabled(true); overlay:SetMouseClickEnabled(false)
    overlay:SetScript("OnEnter", function(self)
        revealFn()
        self:Hide()
        frame:SetScript("OnUpdate", function()
            if not frame:IsMouseOver() then
                frame:SetScript("OnUpdate", nil)
                if cachedShouldHide then suppressFn(); self:Show() end
            end
        end)
    end)
    frame.orbitHoverOverlay = overlay
    overlay:Hide()
end

local function ToggleOverlay(frame, shouldHide)
    if not frame or not frame.orbitHoverOverlay then return end
    if shouldHide then frame.orbitHoverOverlay:Show() else frame:SetScript("OnUpdate", nil); frame.orbitHoverOverlay:Hide() end
end

local function SetupMinimapHoverOverlay()
    local cluster = _G["MinimapCluster"]
    if not cluster then return end
    CreateSimpleHoverOverlay(cluster, function() cluster:SetAlpha(1) end, function() cluster:SetAlpha(0) end)
end

local function SetupObjectiveHoverOverlay()
    local objective = _G["ObjectiveTrackerFrame"]
    if not objective then return end
    CreateSimpleHoverOverlay(objective, function() objective:SetAlpha(1) end, function() objective:SetAlpha(0) end)
end

-- [ REFRESH ALL SYSTEMS ]---------------------------------------------------------------------------
function Manager:Refresh(force)
    local shouldHide = self:ShouldHide()
    if not force and shouldHide == cachedShouldHide then return end
    cachedShouldHide = shouldHide

    -- Blizzard frames: only hide if their VE entry has hideMounted enabled
    if Orbit.VisibilityEngine then
        for _, entry in ipairs(Orbit.VisibilityEngine:GetBlizzardFrames()) do
            local frame = _G[entry.blizzardFrame]
            if frame then
                local frameHide = shouldHide and Orbit.VisibilityEngine:GetFrameSetting(entry.key, "hideMounted")
                local allowHover = frameHide and Orbit.VisibilityEngine:GetFrameSetting(entry.key, "mouseOver")
                frame:SetAlpha(frameHide and 0 or 1)
                if entry.key == "Minimap" then
                    SetupMinimapHoverOverlay()
                    ToggleOverlay(_G["MinimapCluster"], allowHover)
                elseif entry.blizzardFrame == "ObjectiveTrackerFrame" then
                    SetupObjectiveHoverOverlay()
                    ToggleOverlay(frame, allowHover)
                elseif entry.blizzardFrame == "BuffFrame" or entry.blizzardFrame == "DebuffFrame" then
                    CreateSimpleHoverOverlay(frame, function() frame:SetAlpha(1) end, function() frame:SetAlpha(0) end)
                    ToggleOverlay(frame, allowHover)
                end
            end
        end
    end


    Orbit.EventBus:Fire("MOUNTED_VISIBILITY_CHANGED", shouldHide)
end

-- [ EVENT REGISTRATION ]----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Manager:Refresh(true)
        C_Timer.After(REAPPLY_DELAY, function() Manager:Refresh(true) end)
    else
        Manager:Refresh()
    end
end)

if EditModeManagerFrame then
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
        C_Timer.After(0, function() Manager:Refresh(true) end)
    end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() Manager:Refresh(true) end)
end
