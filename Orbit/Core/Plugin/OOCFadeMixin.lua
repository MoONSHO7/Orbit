-- [ OUT OF COMBAT FADE MIXIN ]----------------------------------------------------------------------
-- Hide frames OOC without target. Usage: call ApplyOOCFade(frame, plugin, systemIndex) in ApplySettings

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local pairs, ipairs = pairs, ipairs
local InCombatLockdown = InCombatLockdown

Orbit.OOCFadeMixin = {}
local Mixin = Orbit.OOCFadeMixin

local EventFrame = CreateFrame("Frame")
local ManagedFrames = {}

-- [ VISIBILITY LOGIC ]------------------------------------------------------------------------------
-- Resolve the VE key for a managed frame's data
local function GetVEKey(data)
    if data.veKey then return data.veKey end
    if not Orbit.VisibilityEngine then return nil end
    return Orbit.VisibilityEngine:GetKeyForPlugin(data.plugin and data.plugin.name, data.systemIndex)
end

local function ShouldShowFrame(frame, data)
    if frame and not frame:IsShown() then return false end
    if Orbit:IsEditMode() then return true end
    if CooldownViewerSettings and CooldownViewerSettings:IsShown() then return true end
    local cursorType = GetCursorInfo()
    if cursorType == "spell" or cursorType == "item" then return true end
    if InCombatLockdown() or UnitAffectingCombat("player") then return true end
    -- Check showWithTarget from VE (defaults true if no VE entry)
    local showWithTarget = true
    if data then
        local veKey = GetVEKey(data)
        if veKey and Orbit.VisibilityEngine then showWithTarget = Orbit.VisibilityEngine:GetFrameSetting(veKey, "showWithTarget") end
    end
    if showWithTarget and UnitExists("target") then return true end
    return (frame and frame.orbitMouseOver) or false
end

-- Enable/disable mouse on frame and optionally children (protected in combat)
local function SetFrameMouseEnabled(frame, enabled, includeChildren)
    if not frame then return end
    if frame.orbitClickThrough then return end
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() SetFrameMouseEnabled(frame, enabled, includeChildren) end)
        return
    end
    if frame.EnableMouse then frame:EnableMouse(enabled) end
    if includeChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            if child.EnableMouse then child:EnableMouse(enabled) end
        end
    end
end

-- Directly hide/show the group border overlay on a frame or its ancestor's merge root
local function SetGroupBorderOOCHidden(frame, hidden)
    local target = frame
    for _ = 1, 5 do
        if target._groupBorderActive then break end
        target = target:GetParent()
        if not target then return end
    end
    if not target._groupBorderActive then return end
    target._oocFadeHidden = hidden or nil
    local root = target._groupBorderRoot or target
    if root._groupBorderOverlay then
        if hidden then root._groupBorderOverlay:Hide()
        else root._groupBorderOverlay:Show() end
    end
end

local function UpdateFrameVisibility(frame, fadeEnabled, data)
    if not frame then return end
    
    -- Check per-frame mounted hide setting instead of global ShouldHide()
    local isMountedHidden = false
    if data and Orbit.MountedVisibility then
        if data.plugin then
            isMountedHidden = Orbit.MountedVisibility:ShouldHidePlugin(data.plugin)
        elseif data.veKey then
            isMountedHidden = Orbit.MountedVisibility:ShouldHideBlizzard(data.veKey)
        end
    end
    -- Also must check if mounted visibility is actually active globally
    if isMountedHidden and Orbit.MountedVisibility:ShouldHide() then return end
    
    local includeChildren = data and not data.enableHover
    if not fadeEnabled then
        SetFrameMouseEnabled(frame, true, includeChildren)
        if frame._oocFadeHidden then
            frame._oocFadeHidden = nil
            SetGroupBorderOOCHidden(frame, false)
        end
        return
    end
    local shouldShow = ShouldShowFrame(frame, data)
    if shouldShow then
        SetFrameMouseEnabled(frame, true, includeChildren)
        -- Read opacity from VE if available, fallback to plugin setting
        local opacity = 100
        if data then
            local veKey = GetVEKey(data)
            if veKey and Orbit.VisibilityEngine then
                opacity = Orbit.VisibilityEngine:GetFrameSetting(veKey, "opacity")
            elseif data.plugin then
                opacity = data.plugin:GetSetting(data.systemIndex, "Opacity") or 100
            end
        end
        Orbit.Animation:ApplyHoverFade(frame, opacity / 100, 1, Orbit:IsEditMode())
        if frame._oocFadeHidden then
            frame._oocFadeHidden = nil
            SetGroupBorderOOCHidden(frame, false)
        end
    else
        frame:SetAlpha(0)
        if includeChildren then SetFrameMouseEnabled(frame, false, true) end
        if not frame._oocFadeHidden then
            frame._oocFadeHidden = true
            SetGroupBorderOOCHidden(frame, true)
        end
    end
end

local function UpdateAllFrames()
    for frame, data in pairs(ManagedFrames) do
        -- Read oocFade from VE if available, fallback to plugin setting
        local fadeEnabled = false
        local veKey = GetVEKey(data)
        if veKey and Orbit.VisibilityEngine then
            fadeEnabled = Orbit.VisibilityEngine:GetFrameSetting(veKey, "oocFade")
        elseif data.plugin and data.plugin.GetSetting then
            fadeEnabled = data.plugin:GetSetting(data.systemIndex, data.settingKey or "OutOfCombatFade")
        end
        UpdateFrameVisibility(frame, fadeEnabled, data)
    end
end

-- [ EVENT HANDLING ]--------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

EventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        UpdateAllFrames()
    else
        C_Timer.After(0.05, UpdateAllFrames)
    end
end)

-- Hook Edit Mode show/hide
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function() C_Timer.After(0.1, UpdateAllFrames) end)
    EditModeManagerFrame:HookScript("OnHide", function() C_Timer.After(0.1, UpdateAllFrames) end)
end

-- Hook CooldownViewerSettings show/hide (delayed for load order)
C_Timer.After(2, function()
    if CooldownViewerSettings then
        CooldownViewerSettings:HookScript("OnShow", function() C_Timer.After(0.1, UpdateAllFrames) end)
        CooldownViewerSettings:HookScript("OnHide", function() C_Timer.After(0.1, UpdateAllFrames) end)
    end
end)

-- [ MIXIN FUNCTIONS ]-------------------------------------------------------------------------------
--- Apply Out of Combat Fade behavior to a frame (pass plugin for Orbit frames, or just veKey for Blizzard frames)
function Mixin:ApplyOOCFade(frame, plugin, systemIndex, settingKey, enableHover, veKey)
    if not frame then return end
    
    -- Orbit plugins resolve their own keys, Blizzard frames pass veKey directly
    if plugin then
        settingKey = settingKey or "OutOfCombatFade"
        veKey = Orbit.VisibilityEngine and Orbit.VisibilityEngine:GetKeyForPlugin(plugin.name, systemIndex)
    end
    
    if veKey and Orbit.VisibilityEngine then
        enableHover = Orbit.VisibilityEngine:GetFrameSetting(veKey, "mouseOver")
    end
    ManagedFrames[frame] = { plugin = plugin, systemIndex = systemIndex, settingKey = settingKey, enableHover = enableHover or false, veKey = veKey }
    
    -- Create hover ticker if not exists (uses MouseIsOver for child-inclusive detection)
    if not frame.orbitOOCHoverTicker then
        local hoverTicker = CreateFrame("Frame", nil, frame)
        hoverTicker:SetScript("OnUpdate", function(self, elapsed)
            self.timer = (self.timer or 0) + elapsed
            if self.timer < Orbit.Constants.Timing.HoverCheckInterval then return end
            self.timer = 0
            local parent = self:GetParent()
            if not parent:IsShown() then return end
            local isOver = MouseIsOver(parent)
            
            local data = ManagedFrames[parent]
            if data and Orbit.MountedVisibility then
                local isMountedHidden = data.plugin and Orbit.MountedVisibility:ShouldHidePlugin(data.plugin) or (data.veKey and Orbit.MountedVisibility:ShouldHideBlizzard(data.veKey))
                if isMountedHidden and Orbit.MountedVisibility:ShouldHide() then return end
            end
            
            if isOver and not parent.orbitMouseOver then
                parent.orbitMouseOver = true
                if data then
                    -- Check oocFade from VE
                    local fadeOn = false
                    local vk = GetVEKey(data)
                    if vk and Orbit.VisibilityEngine then fadeOn = Orbit.VisibilityEngine:GetFrameSetting(vk, "oocFade")
                    elseif data.plugin then fadeOn = data.plugin:GetSetting(data.systemIndex, data.settingKey) end
                    if fadeOn then parent:SetAlpha(1) end
                end
            elseif not isOver and parent.orbitMouseOver then
                parent.orbitMouseOver = nil
                local data = ManagedFrames[parent]
                if data then
                    local fadeOn = false
                    local vk = GetVEKey(data)
                    if vk and Orbit.VisibilityEngine then fadeOn = Orbit.VisibilityEngine:GetFrameSetting(vk, "oocFade")
                    elseif data.plugin then fadeOn = data.plugin:GetSetting(data.systemIndex, data.settingKey) end
                    UpdateFrameVisibility(parent, fadeOn, data)
                end
            end
        end)
        frame.orbitOOCHoverTicker = hoverTicker
    end
    -- Show/hide ticker based on enableHover setting
    if enableHover then
        frame.orbitOOCHoverTicker:Show()
    else
        frame.orbitOOCHoverTicker:Hide()
        frame.orbitMouseOver = nil
    end
    -- Hook SetAlpha to prevent external override when OOC fade should hide
    if not frame.orbitOOCSetAlphaHooked then
        local originalSetAlpha = frame.SetAlpha
        frame.SetAlpha = function(self, alpha)
            local data = ManagedFrames[self]
            
            local isMountedHidden = false
            if data and Orbit.MountedVisibility then
                isMountedHidden = data.plugin and Orbit.MountedVisibility:ShouldHidePlugin(data.plugin) or (data.veKey and Orbit.MountedVisibility:ShouldHideBlizzard(data.veKey))
                isMountedHidden = isMountedHidden and Orbit.MountedVisibility:ShouldHide()
            end

            if data and alpha > 0 and not isMountedHidden then
                local fadeOn = false
                local vk = GetVEKey(data)
                if vk and Orbit.VisibilityEngine then fadeOn = Orbit.VisibilityEngine:GetFrameSetting(vk, "oocFade")
                elseif data.plugin then fadeOn = data.plugin:GetSetting(data.systemIndex, data.settingKey) end
                if fadeOn and not ShouldShowFrame(self, data) then return originalSetAlpha(self, 0) end
            end
            return originalSetAlpha(self, alpha)
        end
        frame.orbitOOCSetAlphaHooked = true
    end
    -- Read fadeEnabled from VE
    local fadeOn = false
    if veKey and Orbit.VisibilityEngine then fadeOn = Orbit.VisibilityEngine:GetFrameSetting(veKey, "oocFade")
    elseif plugin then fadeOn = plugin:GetSetting(systemIndex, settingKey) end
    UpdateFrameVisibility(frame, fadeOn, ManagedFrames[frame])
end

--- Remove OOC Fade behavior from a frame
function Mixin:RemoveOOCFade(frame)
    if not frame then return end
    ManagedFrames[frame] = nil
    frame:SetAlpha(1)
    SetFrameMouseEnabled(frame, true, true)
end

function Mixin:RefreshAll()
    UpdateAllFrames()
end


