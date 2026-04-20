-- [ OUT OF COMBAT FADE MIXIN ]----------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local pairs, ipairs = pairs, ipairs
local InCombatLockdown = InCombatLockdown

Orbit.OOCFadeMixin = {}
local Mixin = Orbit.OOCFadeMixin

local EventFrame = CreateFrame("Frame")
local ManagedFrames = setmetatable({}, { __mode = "k" })

-- [ VISIBILITY LOGIC ]------------------------------------------------------------------------------
local function GetVEKey(data)
    if data.veKey then return data.veKey end
    if not Orbit.VisibilityEngine then return nil end
    return Orbit.VisibilityEngine:GetKeyForPlugin(data.plugin and data.plugin.name, data.systemIndex)
end

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

local function GetVESettings(data)
    local veKey = data and GetVEKey(data)
    local VE = Orbit.VisibilityEngine
    if veKey and VE then
        local opacity = VE:GetFrameSetting(veKey, "opacity")
        if VE:IsOpacityOnly(veKey) then return opacity, false, false, false, false end
        return opacity, VE:GetFrameSetting(veKey, "oocFade"),
               VE:GetFrameSetting(veKey, "mouseOver"), VE:GetFrameSetting(veKey, "showWithTarget"),
               VE:GetFrameSetting(veKey, "alphaLock")
    end
    local opacity = data and data.plugin and data.plugin:GetSetting(data.systemIndex, "Opacity") or 100
    local oocFade = data and data.plugin and data.plugin.GetSetting and data.plugin:GetSetting(data.systemIndex, data.settingKey or "OutOfCombatFade") or false
    return opacity, oocFade, true, true, false
end



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

local function SyncMinimapChildrenAlpha(frame, alpha)
    if not frame or not frame.orbitOpacityExternal then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        child:SetAlpha(alpha)
    end
end

local function UpdateFrameVisibility(frame, _, data)
    if not frame then return end
    -- Mounted: supreme override — completely hide
    local isMountedHidden = false
    if data and Orbit.MountedVisibility and Orbit.MountedVisibility:IsCachedHidden() then
        local veKey = GetVEKey(data)
        if veKey and not Orbit.VisibilityEngine:IsOpacityOnly(veKey) then
            isMountedHidden = Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted")
        end
    end
    if isMountedHidden then
        local _, _, mouseOver, showWithTarget = GetVESettings(data)
        local revealFull = (mouseOver and frame.orbitMouseOver) or (showWithTarget and UnitExists("target")) or IsCursorRevealing(frame)
        if not revealFull then
            frame:SetAlpha(0)
            if not frame._oocFadeHidden then frame._oocFadeHidden = true; SetGroupBorderOOCHidden(frame, true) end
            SyncMinimapChildrenAlpha(frame, 0)
            return
        end
    end
    local opacity, oocFade, mouseOver, showWithTarget, alphaLock = GetVESettings(data)
    local baseAlpha = frame.orbitOpacityExternal and 1 or (opacity or 100) / 100
    local rawOpacity = (opacity or 100) / 100
    if not oocFade and rawOpacity >= 1 and not mouseOver then
        if frame._oocFadeHidden then frame._oocFadeHidden = nil; SetGroupBorderOOCHidden(frame, false) end
        Orbit.Animation:StopHoverFade(frame)
        frame:SetAlpha(1)
        SyncMinimapChildrenAlpha(frame, 1)
        return
    end
    local isHovering = frame.orbitMouseOver
    local hasTarget = UnitExists("target")
    local revealFull = (mouseOver and isHovering) or (showWithTarget and hasTarget) or IsCursorRevealing(frame)
    local shouldOOCHide = oocFade and not IsInCombatContext(frame) and not revealFull
    -- Alpha Lock caps reveal at base opacity instead of pushing to 1.0 on mouseOver/target.
    local finalAlpha
    if shouldOOCHide then
        finalAlpha = 0
    elseif revealFull then
        finalAlpha = alphaLock and baseAlpha or 1
    else
        finalAlpha = baseAlpha
    end
    -- Apply alpha and mouse state
    if finalAlpha > 0 then
        Orbit.Animation:ApplyHoverFade(frame, finalAlpha, 1, Orbit:IsEditMode())
        if frame._oocFadeHidden then frame._oocFadeHidden = nil; SetGroupBorderOOCHidden(frame, false) end
        local revealChildAlpha = alphaLock and (frame.orbitOpacityExternal and rawOpacity or baseAlpha) or 1
        local childAlpha = revealFull and revealChildAlpha or (frame.orbitOpacityExternal and rawOpacity or baseAlpha)
        SyncMinimapChildrenAlpha(frame, childAlpha)
    else
        frame:SetAlpha(0)
        if not frame._oocFadeHidden then frame._oocFadeHidden = true; SetGroupBorderOOCHidden(frame, true) end
        SyncMinimapChildrenAlpha(frame, 0)
    end
end

local function UpdateAllFrames()
    for frame, data in pairs(ManagedFrames) do
        -- Re-sync hover ticker from VE mouseOver setting
        local veKey = data.veKey
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
EventFrame:RegisterEvent("CINEMATIC_STOP")
EventFrame:RegisterEvent("STOP_MOVIE")
EventFrame:RegisterEvent("BARBER_SHOP_CLOSE")
EventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
EventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
EventFrame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
EventFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
EventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

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
    -- Create hover ticker (parented to UIParent to avoid corrupting LayoutFrame sizing)
    if not frame.orbitOOCHoverTicker then
        local hoverTicker = CreateFrame("Frame", nil, UIParent)
        hoverTicker.orbitTarget = frame
        hoverTicker:SetScript("OnUpdate", function(self, elapsed)
            self.timer = (self.timer or 0) + elapsed
            if self.timer < Orbit.Constants.Timing.HoverCheckInterval then return end
            self.timer = 0
            local target = self.orbitTarget
            if not target:IsShown() then return end
            local isOver = MouseIsOver(target)
            if isOver and not target.orbitMouseOver then
                target.orbitMouseOver = true
                UpdateFrameVisibility(target, nil, ManagedFrames[target])
            elseif not isOver and target.orbitMouseOver then
                target.orbitMouseOver = nil
                UpdateFrameVisibility(target, nil, ManagedFrames[target])
            end
        end)
        frame.orbitOOCHoverTicker = hoverTicker
    end
    if enableHover then frame.orbitOOCHoverTicker:Show()
    else frame.orbitOOCHoverTicker:Hide(); frame.orbitMouseOver = nil end
    -- Hook SetAlpha to enforce VE-managed alpha safely via hooksecurefunc
    if not frame.orbitOOCSetAlphaHooked then
        hooksecurefunc(frame, "SetAlpha", function(self, alpha)
            if self._orbitSetAlphaGuard then return end
            local d = ManagedFrames[self]
            if not d then return end
            
            local opacity, oocFade, mouseOver, showWithTarget, alphaLock = GetVESettings(d)
            local maxAlpha = self.orbitOpacityExternal and 1 or (opacity or 100) / 100
            
            -- Mounted hidden check (shared by all paths)
            local isMountedHide = false
            if Orbit.MountedVisibility and Orbit.MountedVisibility:IsCachedHidden() then
                local isMH = d.veKey and Orbit.VisibilityEngine:GetFrameSetting(d.veKey, "hideMounted")
                if isMH then
                    local revealFull = (showWithTarget and UnitExists("target")) or (mouseOver and self.orbitMouseOver) or IsCursorRevealing(self)
                    if not revealFull then isMountedHide = true end
                end
            end
            
            local finalAlpha = alpha
            if isMountedHide then 
                finalAlpha = 0
            elseif not oocFade and maxAlpha >= 1 and not mouseOver then
                -- Fast path: no VE effects active
                finalAlpha = alpha
            elseif oocFade and not IsInCombatContext(self) and not self.orbitMouseOver and not (showWithTarget and UnitExists("target")) then
                -- OOC fade should hide: force 0
                finalAlpha = 0
            elseif IsCursorRevealing(self) then
                -- Cursor override (respect Alpha Lock if enabled)
                finalAlpha = alphaLock and math.min(alpha, maxAlpha) or math.max(alpha, 1)
            elseif mouseOver and self.orbitMouseOver then
                -- MouseOver bypasses maxAlpha cap unless Alpha Lock is set
                finalAlpha = alphaLock and math.min(alpha, maxAlpha) or alpha
            else
                -- Apply VE opacity as cap
                finalAlpha = math.min(alpha, maxAlpha)
            end
            
            -- Apply guarded alpha correction if necessary
            if finalAlpha ~= alpha then
                self._orbitSetAlphaGuard = true
                self:SetAlpha(finalAlpha)
                self._orbitSetAlphaGuard = false
            end
        end)
        frame.orbitOOCSetAlphaHooked = true
    end
    UpdateFrameVisibility(frame, nil, ManagedFrames[frame])
end

-- Remove OOC Fade behavior from a frame
function Mixin:RemoveOOCFade(frame)
    if not frame then return end
    ManagedFrames[frame] = nil
    frame:SetAlpha(1)
end

function Mixin:RefreshAll()
    UpdateAllFrames()
end


