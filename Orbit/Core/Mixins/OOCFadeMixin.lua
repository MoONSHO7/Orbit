-- [ OUT OF COMBAT FADE MIXIN ]----------------------------------------------------------------------
-- Hide frames OOC without target. Usage: call ApplyOOCFade(frame, plugin, systemIndex) in ApplySettings

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

Orbit.OOCFadeMixin = {}
local Mixin = Orbit.OOCFadeMixin

local EventFrame = CreateFrame("Frame")
local ManagedFrames = {}

-- [ VISIBILITY LOGIC ]------------------------------------------------------------------------------

local function ShouldShowFrame(frame)
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
        return true
    end
    if CooldownViewerSettings and CooldownViewerSettings:IsShown() then
        return true
    end
    return InCombatLockdown() or UnitAffectingCombat("player") or UnitExists("target") or (frame and frame.orbitMouseOver)
end

-- Enable/disable mouse on frame and optionally children (protected in combat)
local function SetFrameMouseEnabled(frame, enabled, includeChildren)
    if not frame then
        return
    end
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
    if includeChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            if child.EnableMouse then
                child:EnableMouse(enabled)
            end
        end
    end
end

local function UpdateFrameVisibility(frame, fadeEnabled, data)
    if not frame then
        return
    end
    local includeChildren = data and not data.enableHover
    if not fadeEnabled then
        SetFrameMouseEnabled(frame, true, includeChildren)
        return
    end
    if ShouldShowFrame(frame) then
        frame:SetAlpha(1)
        SetFrameMouseEnabled(frame, true, includeChildren)
    else
        frame:SetAlpha(0)
        if includeChildren then
            SetFrameMouseEnabled(frame, false, true)
        end
    end
end

local function UpdateAllFrames()
    for frame, data in pairs(ManagedFrames) do
        local fadeEnabled = data.plugin and data.plugin.GetSetting and data.plugin:GetSetting(data.systemIndex, data.settingKey or "OutOfCombatFade")
        UpdateFrameVisibility(frame, fadeEnabled, data)
    end
end

-- [ EVENT HANDLING ]--------------------------------------------------------------------------------

EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

EventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        UpdateAllFrames() -- Update immediately before combat lockdown
    else
        C_Timer.After(0.05, UpdateAllFrames)
    end
end)

-- Hook Edit Mode show/hide
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function()
        C_Timer.After(0.1, UpdateAllFrames)
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        C_Timer.After(0.1, UpdateAllFrames)
    end)
end

-- Hook CooldownViewerSettings show/hide (delayed for load order)
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
function Mixin:ApplyOOCFade(frame, plugin, systemIndex, settingKey, enableHover)
    if not frame or not plugin then
        return
    end
    settingKey = settingKey or "OutOfCombatFade"
    ManagedFrames[frame] = { plugin = plugin, systemIndex = systemIndex, settingKey = settingKey, enableHover = enableHover or false }

    if enableHover and not frame.orbitOOCHoverHooked then
        frame:HookScript("OnEnter", function(self)
            self.orbitMouseOver = true
            local data = ManagedFrames[self]
            if data and data.plugin:GetSetting(data.systemIndex, data.settingKey) then
                self:SetAlpha(1)
            end
        end)
        frame:HookScript("OnLeave", function(self)
            self.orbitMouseOver = nil
            local data = ManagedFrames[self]
            if data then
                UpdateFrameVisibility(self, data.plugin:GetSetting(data.systemIndex, data.settingKey), data)
            end
        end)
        frame.orbitOOCHoverHooked = true
    end

    -- Hook SetAlpha to prevent external override when OOC fade should hide
    if not frame.orbitOOCSetAlphaHooked then
        local originalSetAlpha = frame.SetAlpha
        frame.SetAlpha = function(self, alpha)
            local data = ManagedFrames[self]
            if data and data.plugin:GetSetting(data.systemIndex, data.settingKey) and not ShouldShowFrame(self) and alpha > 0 then
                return originalSetAlpha(self, 0)
            end
            return originalSetAlpha(self, alpha)
        end
        frame.orbitOOCSetAlphaHooked = true
    end
    UpdateFrameVisibility(frame, plugin:GetSetting(systemIndex, settingKey), ManagedFrames[frame])
end

--- Remove OOC Fade behavior from a frame
function Mixin:RemoveOOCFade(frame)
    if not frame then
        return
    end
    ManagedFrames[frame] = nil
    frame:SetAlpha(1)
    SetFrameMouseEnabled(frame, true, true)
end

function Mixin:RefreshAll()
    UpdateAllFrames()
end
