-- [ OUT OF COMBAT FADE MIXIN ]----------------------------------------------------------------------
-- Shared functionality to hide frames when out of combat and no target selected
-- Usage: Mix into plugin, call ApplyOOCFade(frame, systemIndex) in ApplySettings
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

Orbit.OOCFadeMixin = {}
local Mixin = Orbit.OOCFadeMixin

-- Centralized event handler frame
local EventFrame = CreateFrame("Frame")
local ManagedFrames = {}  -- { [frame] = { plugin, systemIndex, settingKey } }

-- [ VISIBILITY LOGIC ]------------------------------------------------------------------------------

local function ShouldShowFrame(frame)
    -- Always show in Edit Mode
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
        return true
    end
    
    -- Always show when Cooldown Settings panel is open
    if CooldownViewerSettings and CooldownViewerSettings:IsShown() then
        return true
    end
    
    -- Show if in combat OR has a target OR mouse is over frame (if hover enabled)
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local hasTarget = UnitExists("target")
    local mouseOver = frame and frame.orbitMouseOver
    return inCombat or hasTarget or mouseOver
end

-- Helper to enable/disable mouse on a frame and optionally its children
-- When enableHover is true, we only toggle the parent frame so hover detection works
local function SetFrameMouseEnabled(frame, enabled, includeChildren)
    if not frame then return end
    
    -- EnableMouse is protected - queue for after combat if needed
    if InCombatLockdown() then
        if Orbit.CombatManager then
            Orbit.CombatManager:QueueUpdate(function()
                SetFrameMouseEnabled(frame, enabled, includeChildren)
            end)
        end
        return
    end
    
    if frame.EnableMouse then
        frame:EnableMouse(enabled)
    end
    
    -- Only toggle children when explicitly requested (hover reveal needs children to pass through)
    if includeChildren then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            if child.EnableMouse then
                child:EnableMouse(enabled)
            end
        end
    end
end

local function UpdateFrameVisibility(frame, fadeEnabled, data)
    if not frame then return end
    
    -- Determine if we should include children in mouse toggle
    -- When enableHover is true, we DON'T touch children so hover detection works
    local includeChildren = data and not data.enableHover
    
    -- If fade is disabled, do nothing - let the Opacity slider / ApplyHoverFade handle alpha
    if not fadeEnabled then
        -- Ensure mouse is re-enabled when fade is disabled
        SetFrameMouseEnabled(frame, true, includeChildren)
        return
    end
    
    -- Apply visibility based on combat/target/hover state
    local shouldShow = ShouldShowFrame(frame)
    
    if shouldShow then
        frame:SetAlpha(1)
        -- Re-enable mouse when visible
        SetFrameMouseEnabled(frame, true, includeChildren)
    else
        frame:SetAlpha(0)
        -- Disable mouse when hidden (unless hover is enabled for reveal)
        if includeChildren then
            SetFrameMouseEnabled(frame, false, true)
        end
    end
end

local function UpdateAllFrames()
    for frame, data in pairs(ManagedFrames) do
        local plugin = data.plugin
        local systemIndex = data.systemIndex
        local settingKey = data.settingKey or "OutOfCombatFade"
        
        local fadeEnabled = plugin and plugin.GetSetting and plugin:GetSetting(systemIndex, settingKey)
        UpdateFrameVisibility(frame, fadeEnabled, data)
    end
end

-- [ EVENT HANDLING ]--------------------------------------------------------------------------------

EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

EventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Combat enter: Update IMMEDIATELY so frames are visible and mouse-enabled
        -- BEFORE combat lockdown starts (can't call EnableMouse after lockdown)
        UpdateAllFrames()
    else
        -- Combat exit / target change: Small delay to allow state to settle
        C_Timer.After(0.05, UpdateAllFrames)
    end
end)

-- Hook Edit Mode show/hide to refresh visibility
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function()
        C_Timer.After(0.1, UpdateAllFrames)
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        C_Timer.After(0.1, UpdateAllFrames)
    end)
end

-- Hook CooldownViewerSettings show/hide
-- Delay 2s to ensure addon load order - CooldownViewerSettings is created late
C_Timer.After(2, function()
    if CooldownViewerSettings then
        CooldownViewerSettings:HookScript("OnShow", function()
            C_Timer.After(0.1, UpdateAllFrames)
        end)
        CooldownViewerSettings:HookScript("OnHide", function()
            C_Timer.After(0.1, UpdateAllFrames)
        end)
    end
end)

-- [ MIXIN FUNCTIONS ]-------------------------------------------------------------------------------

--- Apply Out of Combat Fade behavior to a frame
--- @param frame Frame The frame to manage
--- @param plugin table The plugin instance (must have GetSetting)
--- @param systemIndex number System index for settings lookup
--- @param settingKey string|nil Optional setting key (defaults to "OutOfCombatFade")
--- @param enableHover boolean|nil Optional - if true, show on mouseover (default false)
function Mixin:ApplyOOCFade(frame, plugin, systemIndex, settingKey, enableHover)
    if not frame or not plugin then return end
    
    settingKey = settingKey or "OutOfCombatFade"
    
    -- Register frame for management
    ManagedFrames[frame] = {
        plugin = plugin,
        systemIndex = systemIndex,
        settingKey = settingKey,
        enableHover = enableHover or false,
    }
    
    -- Add hover detection (show on mouseover) - only if explicitly enabled
    if enableHover and not frame.orbitOOCHoverHooked then
        frame:HookScript("OnEnter", function(self)
            self.orbitMouseOver = true
            local data = ManagedFrames[self]
            if data then
                local fadeEnabled = data.plugin:GetSetting(data.systemIndex, data.settingKey)
                if fadeEnabled then
                    self:SetAlpha(1)
                end
            end
        end)
        frame:HookScript("OnLeave", function(self)
            self.orbitMouseOver = nil
            local data = ManagedFrames[self]
            if data then
                local fadeEnabled = data.plugin:GetSetting(data.systemIndex, data.settingKey)
                UpdateFrameVisibility(self, fadeEnabled, data)
            end
        end)
        frame.orbitOOCHoverHooked = true
    end
    
    -- Hook SetAlpha to prevent external code from overriding when OOC fade should hide
    if not frame.orbitOOCSetAlphaHooked then
        local originalSetAlpha = frame.SetAlpha
        frame.SetAlpha = function(self, alpha)
            local data = ManagedFrames[self]
            if data then
                local fadeEnabled = data.plugin:GetSetting(data.systemIndex, data.settingKey)
                if fadeEnabled and not ShouldShowFrame(self) then
                    -- Block alpha changes when frame should be hidden
                    if alpha > 0 then
                        return originalSetAlpha(self, 0)
                    end
                end
            end
            return originalSetAlpha(self, alpha)
        end
        frame.orbitOOCSetAlphaHooked = true
    end
    
    -- Apply current visibility state
    local fadeEnabled = plugin:GetSetting(systemIndex, settingKey)
    UpdateFrameVisibility(frame, fadeEnabled, ManagedFrames[frame])
end

--- Remove OOC Fade behavior from a frame
--- @param frame Frame The frame to unregister
function Mixin:RemoveOOCFade(frame)
    if frame then
        ManagedFrames[frame] = nil
        frame:SetAlpha(1)  -- Restore visibility
        SetFrameMouseEnabled(frame, true, true)  -- Restore interactivity (including children)
    end
end

--- Force update all managed frames (call after setting changes)
function Mixin:RefreshAll()
    UpdateAllFrames()
end
