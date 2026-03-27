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

-- Check if frame should be revealed for OOC fade (combat, edit mode, cursor)
local function IsInCombatContext(frame)
    if frame and not frame:IsShown() then return false end
    if Orbit:IsEditMode() then return true end
    if CooldownViewerSettings and CooldownViewerSettings:IsShown() then return true end
    local cursorType = GetCursorInfo()
    if cursorType == "spell" or cursorType == "item" then return true end
    return InCombatLockdown() or UnitAffectingCombat("player")
end

local function IsCursorRevealing(frame)
    if not frame or not frame.orbitCursorReveal then return false end
    local ct = GetCursorInfo()
    return ct == "spell" or ct == "item"
end

-- Read all VE settings for a managed frame
local function GetVESettings(data)
    local veKey = data and GetVEKey(data)
    local VE = Orbit.VisibilityEngine
    if veKey and VE then
        return VE:GetFrameSetting(veKey, "opacity"), VE:GetFrameSetting(veKey, "oocFade"),
               VE:GetFrameSetting(veKey, "mouseOver"), VE:GetFrameSetting(veKey, "showWithTarget")
    end
    local opacity = data and data.plugin and data.plugin:GetSetting(data.systemIndex, "Opacity") or 100
    local oocFade = data and data.plugin and data.plugin.GetSetting and data.plugin:GetSetting(data.systemIndex, data.settingKey or "OutOfCombatFade") or false
    return opacity, oocFade, true, true
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

-- Hide/show Minimap widget when its cluster fades; engine-rendered POI pins ignore alpha
local function SyncMinimapWidget(frame, hidden)
    if not frame or not frame.orbitOpacityExternal then return end
    local minimap = _G["Minimap"]
    if not minimap then return end
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() SyncMinimapWidget(frame, hidden) end)
        return
    end
    if hidden then minimap:Hide() elseif not minimap:IsShown() then minimap:Show() end
end

local function UpdateFrameVisibility(frame, _, data)
    if not frame then return end
    -- Mounted: supreme override — completely hide
    local isMountedHidden = false
    if data and Orbit.MountedVisibility and Orbit.MountedVisibility:IsCachedHidden() then
        local veKey = GetVEKey(data)
        isMountedHidden = veKey and Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted")
    end
    if isMountedHidden then
        -- Check reveal overrides before hiding
        local _, _, mouseOver, showWithTarget = GetVESettings(data)
        local revealFull = (mouseOver and frame.orbitMouseOver) or (showWithTarget and UnitExists("target")) or IsCursorRevealing(frame)
        if not revealFull then
            frame:SetAlpha(0)
            if not frame._oocFadeHidden then frame._oocFadeHidden = true; SetGroupBorderOOCHidden(frame, true) end
            SyncMinimapWidget(frame, true)
            return
        end
    end
    -- Read VE settings
    local opacity, oocFade, mouseOver, showWithTarget = GetVESettings(data)
    local baseAlpha = frame.orbitOpacityExternal and 1 or (opacity or 100) / 100
    -- Early out: no VE effects active — don't touch the frame at all
    if not oocFade and baseAlpha >= 1 and not mouseOver then
        if frame._oocFadeHidden then frame._oocFadeHidden = nil; SetGroupBorderOOCHidden(frame, false) end
        frame:SetAlpha(1)
        SyncMinimapWidget(frame, false)
        return
    end
    -- Determine reveal overrides (only when opacity > 0 — don't override explicit hide)
    local isHovering = frame.orbitMouseOver
    local hasTarget = UnitExists("target")
    local revealFull = (mouseOver and isHovering) or (showWithTarget and hasTarget) or IsCursorRevealing(frame)
    -- Determine OOC hide
    local shouldOOCHide = oocFade and not IsInCombatContext(frame) and not revealFull
    -- Calculate final alpha
    local finalAlpha
    if shouldOOCHide then
        finalAlpha = 0
    elseif revealFull then
        finalAlpha = 1
    else
        finalAlpha = baseAlpha
    end
    -- Apply alpha and mouse state
    if finalAlpha > 0 then
        Orbit.Animation:ApplyHoverFade(frame, finalAlpha, 1, Orbit:IsEditMode())
        if frame._oocFadeHidden then frame._oocFadeHidden = nil; SetGroupBorderOOCHidden(frame, false) end
        SyncMinimapWidget(frame, false)
    else
        frame:SetAlpha(0)
        if not frame._oocFadeHidden then frame._oocFadeHidden = true; SetGroupBorderOOCHidden(frame, true) end
        SyncMinimapWidget(frame, true)
    end
end

local function UpdateAllFrames()
    for frame, data in pairs(ManagedFrames) do
        -- Re-sync hover ticker from VE mouseOver setting
        local veKey = GetVEKey(data)
        if veKey and Orbit.VisibilityEngine then
            local mouseOver = Orbit.VisibilityEngine:GetFrameSetting(veKey, "mouseOver")
            data.enableHover = mouseOver or false
            if frame.orbitOOCHoverTicker then
                if mouseOver then frame.orbitOOCHoverTicker:Show()
                else frame.orbitOOCHoverTicker:Hide(); frame.orbitMouseOver = nil end
            end
        end
        UpdateFrameVisibility(frame, nil, data)
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

-- Re-evaluate all managed frames after mount/dismount to restore mouse state
C_Timer.After(0, function()
    if Orbit.EventBus then Orbit.EventBus:On("MOUNTED_VISIBILITY_CHANGED", function() C_Timer.After(0.1, UpdateAllFrames) end) end
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
function Mixin:ApplyOOCFade(frame, plugin, systemIndex, settingKey, enableHover, veKey)
    if not frame then return end
    if plugin then
        settingKey = settingKey or "OutOfCombatFade"
        veKey = Orbit.VisibilityEngine and Orbit.VisibilityEngine:GetKeyForPlugin(plugin.name, systemIndex)
    end
    if veKey and Orbit.VisibilityEngine then enableHover = Orbit.VisibilityEngine:GetFrameSetting(veKey, "mouseOver") end
    ManagedFrames[frame] = { plugin = plugin, systemIndex = systemIndex, settingKey = settingKey, enableHover = enableHover or false, veKey = veKey }
    -- Create hover ticker (MouseIsOver for child-inclusive detection)
    if not frame.orbitOOCHoverTicker then
        local hoverTicker = CreateFrame("Frame", nil, frame)
        hoverTicker:SetScript("OnUpdate", function(self, elapsed)
            self.timer = (self.timer or 0) + elapsed
            if self.timer < Orbit.Constants.Timing.HoverCheckInterval then return end
            self.timer = 0
            local parent = self:GetParent()
            if not parent:IsShown() then return end
            local isOver = MouseIsOver(parent)
            if isOver and not parent.orbitMouseOver then
                parent.orbitMouseOver = true
                UpdateFrameVisibility(parent, nil, ManagedFrames[parent])
            elseif not isOver and parent.orbitMouseOver then
                parent.orbitMouseOver = nil
                UpdateFrameVisibility(parent, nil, ManagedFrames[parent])
            end
        end)
        frame.orbitOOCHoverTicker = hoverTicker
    end
    if enableHover then frame.orbitOOCHoverTicker:Show()
    else frame.orbitOOCHoverTicker:Hide(); frame.orbitMouseOver = nil end
    -- Hook SetAlpha to enforce VE-managed alpha
    if not frame.orbitOOCSetAlphaHooked then
        local originalSetAlpha = frame.SetAlpha
        frame.SetAlpha = function(self, alpha)
            local d = ManagedFrames[self]
            if not d then return originalSetAlpha(self, alpha) end
            local opacity, oocFade, mouseOver, showWithTarget = GetVESettings(d)
            local maxAlpha = self.orbitOpacityExternal and 1 or (opacity or 100) / 100
            -- Mounted hidden check (shared by all paths)
            local isMountedHide = false
            if Orbit.MountedVisibility and Orbit.MountedVisibility:IsCachedHidden() then
                local veKey = GetVEKey(d)
                local isMH = veKey and Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted")
                if isMH then
                    local revealFull = (showWithTarget and UnitExists("target")) or (mouseOver and self.orbitMouseOver) or IsCursorRevealing(self)
                    if not revealFull then isMountedHide = true end
                end
            end
            if isMountedHide then return originalSetAlpha(self, 0) end
            -- Fast path: no VE effects active, pass through
            if not oocFade and maxAlpha >= 1 and not mouseOver then return originalSetAlpha(self, alpha) end
            -- OOC fade should hide: force 0
            if oocFade and not IsInCombatContext(self) and not self.orbitMouseOver and not (showWithTarget and UnitExists("target")) then
                return originalSetAlpha(self, 0)
            end
            -- Apply VE opacity as cap (bypass during hover reveal or cursor reveal)
            if IsCursorRevealing(self) then return originalSetAlpha(self, 1) end
            if mouseOver and self.orbitMouseOver then return originalSetAlpha(self, alpha) end
            return originalSetAlpha(self, math.min(alpha, maxAlpha))
        end
        frame.orbitOOCSetAlphaHooked = true
    end
    UpdateFrameVisibility(frame, nil, ManagedFrames[frame])
end

--- Remove OOC Fade behavior from a frame
function Mixin:RemoveOOCFade(frame)
    if not frame then return end
    ManagedFrames[frame] = nil
    frame:SetAlpha(1)
end

function Mixin:RefreshAll()
    UpdateAllFrames()
end


