-- [ OUT OF COMBAT FADE MIXIN ]-----------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local pairs, ipairs = pairs, ipairs
local InCombatLockdown = InCombatLockdown

Orbit.OOCFadeMixin = {}
local Mixin = Orbit.OOCFadeMixin

local EventFrame = CreateFrame("Frame")
local ManagedFrames = setmetatable({}, { __mode = "k" })

-- [ VISIBILITY LOGIC ]-------------------------------------------------------------------------------
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

local function IsSpellUIOpen()
    local psf = PlayerSpellsFrame
    return psf and psf:IsShown()
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

-- Snapshot 5 VE settings (+ hideMounted) onto the frame; SetAlpha fires every render-frame during UIFrameFadeIn/Out — snapshot avoids 5-6 VE lookups per fire × frame.
local function RefreshVESnapshot(frame, data)
    local opacity, oocFade, mouseOver, showWithTarget, alphaLock = GetVESettings(data)
    frame._veOpacity        = opacity
    frame._veOocFade        = oocFade
    frame._veMouseOver      = mouseOver
    frame._veShowWithTarget = showWithTarget
    frame._veAlphaLock      = alphaLock
    local veKey = GetVEKey(data)
    local VE = Orbit.VisibilityEngine
    if veKey and VE and not VE:IsOpacityOnly(veKey) then
        frame._veHideMounted = VE:GetFrameSetting(veKey, "hideMounted")
    else
        frame._veHideMounted = false
    end
    frame._veKey = veKey
    frame._veProfileCap = (veKey and Orbit.FadeProfiles and Orbit.FadeProfiles:GetResolvedAlpha(veKey)) or 1
    frame._veMouseoverProfile = (veKey and Orbit.FadeProfiles and Orbit.FadeProfiles:FrameHasMouseoverProfile(veKey)) or false
end

local function RefreshAllSnapshots()
    for frame, data in pairs(ManagedFrames) do
        RefreshVESnapshot(frame, data)
    end
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
    -- select-vararg avoids {GetChildren()} temp-table alloc on the SetAlpha hot path.
    local function ApplyChildAlpha(a, ...)
        for i = 1, select("#", ...) do
            select(i, ...):SetAlpha(a)
        end
    end
    ApplyChildAlpha(alpha, frame:GetChildren())
end

local function ResolveProfileCap(frame)
    local cap = frame._veProfileCap or 1
    if frame._veMouseoverProfile and Orbit.FadeProfiles then
        cap = math.min(cap, Orbit.FadeProfiles:GetMouseoverAlpha(frame._veKey, frame.orbitMouseOver))
    end
    return cap
end

local function UpdateFrameVisibility(frame, _, data)
    if not frame then return end
    local profileCap = ResolveProfileCap(frame)
    -- Mounted: supreme override — completely hide
    local isMountedHidden = false
    if data and Orbit.MountedVisibility and Orbit.MountedVisibility:IsCachedHidden() then
        local veKey = GetVEKey(data)
        if veKey and not Orbit.VisibilityEngine:IsOpacityOnly(veKey) then
            isMountedHidden = Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted")
        end
    end
    if isMountedHidden then
        -- S04-C3: read from snapshot (refreshed by ApplyOOCFade / ORBIT_VISIBILITY_CHANGED).
        local mouseOver, showWithTarget = frame._veMouseOver, frame._veShowWithTarget
        local revealFull = (mouseOver and frame.orbitMouseOver) or (showWithTarget and UnitExists("target")) or IsCursorRevealing(frame) or IsSpellUIOpen()
        if not revealFull then
            frame:SetAlpha(0)
            if not frame._oocFadeHidden then frame._oocFadeHidden = true; SetGroupBorderOOCHidden(frame, true) end
            SyncMinimapChildrenAlpha(frame, 0)
            return
        end
    end
    local opacity, oocFade, mouseOver, showWithTarget, alphaLock =
        frame._veOpacity, frame._veOocFade, frame._veMouseOver, frame._veShowWithTarget, frame._veAlphaLock
    local baseAlpha = frame.orbitOpacityExternal and 1 or (opacity or 100) / 100
    local rawOpacity = (opacity or 100) / 100
    if not oocFade and rawOpacity >= 1 and not mouseOver then
        if frame._oocFadeHidden then frame._oocFadeHidden = nil; SetGroupBorderOOCHidden(frame, false) end
        Orbit.Animation:StopHoverFade(frame)
        frame:SetAlpha(profileCap)
        SyncMinimapChildrenAlpha(frame, profileCap)
        return
    end
    local isHovering = frame.orbitMouseOver
    local hasTarget = UnitExists("target")
    local revealFull = (mouseOver and isHovering) or (showWithTarget and hasTarget) or IsCursorRevealing(frame) or IsSpellUIOpen()
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
    finalAlpha = math.min(finalAlpha, profileCap)
    -- Apply alpha and mouse state
    if finalAlpha > 0 then
        Orbit.Animation:ApplyHoverFade(frame, finalAlpha, 1, Orbit:IsEditMode())
        if frame._oocFadeHidden then frame._oocFadeHidden = nil; SetGroupBorderOOCHidden(frame, false) end
        local revealChildAlpha = alphaLock and (frame.orbitOpacityExternal and rawOpacity or baseAlpha) or 1
        local childAlpha = math.min(revealFull and revealChildAlpha or (frame.orbitOpacityExternal and rawOpacity or baseAlpha), profileCap)
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
            local hoverWanted = mouseOver or (Orbit.FadeProfiles and Orbit.FadeProfiles:FrameHasMouseoverProfile(veKey)) or false
            data.enableHover = hoverWanted
            if frame.orbitOOCHoverTicker then
                if hoverWanted then frame.orbitOOCHoverTicker:Show()
                else frame.orbitOOCHoverTicker:Hide(); frame.orbitMouseOver = nil end
            end
        end
        UpdateFrameVisibility(frame, nil, data)
    end
end

-- [ EVENT HANDLING ]---------------------------------------------------------------------------------
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
    local p = Orbit.Profiler
    local s = p and p:Begin()
    if event == "PLAYER_REGEN_DISABLED" then
        UpdateAllFrames()
    else
        C_Timer.After(0.05, UpdateAllFrames)
    end
    if p then p:End("Orbit_OOCFade", event, s) end
end)

-- ORBIT_VISIBILITY_CHANGED drives the snapshot refresh (the per-frame cache SetAlpha/UpdateFrameVisibility read from).
C_Timer.After(0, function()
    if not Orbit.EventBus then return end
    Orbit.EventBus:On("ORBIT_MOUNTED_VISIBILITY_CHANGED", function() C_Timer.After(0.1, UpdateAllFrames) end)
    Orbit.EventBus:On("ORBIT_VISIBILITY_CHANGED", function()
        RefreshAllSnapshots()
        UpdateAllFrames()
    end)
end)

-- Hook Edit Mode enter/exit
if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Enter", function() C_Timer.After(0.1, UpdateAllFrames) end, Mixin)
    EventRegistry:RegisterCallback("EditMode.Exit",  function() C_Timer.After(0.1, UpdateAllFrames) end, Mixin)
end

-- Hook via ADDON_LOADED — both Blizzard_CooldownViewer and Blizzard_PlayerSpells are load-on-demand.
local function HookCooldownViewer()
    local cvs = CooldownViewerSettings
    if cvs and not cvs._orbitOOCHooked then
        cvs:HookScript("OnShow", function() C_Timer.After(0.1, UpdateAllFrames) end)
        cvs:HookScript("OnHide", function() C_Timer.After(0.1, UpdateAllFrames) end)
        cvs._orbitOOCHooked = true
    end
end
local function HookSpellUI()
    local psf = PlayerSpellsFrame
    if psf and not psf._orbitOOCHooked then
        psf:HookScript("OnShow", function() C_Timer.After(0.05, UpdateAllFrames) end)
        psf:HookScript("OnHide", function() C_Timer.After(0.05, UpdateAllFrames) end)
        psf._orbitOOCHooked = true
    end
end
HookCooldownViewer()
HookSpellUI()
local addonLoader = CreateFrame("Frame")
addonLoader:RegisterEvent("ADDON_LOADED")
addonLoader:SetScript("OnEvent", function(self, _, addon)
    if addon == "Blizzard_CooldownViewer" then HookCooldownViewer() end
    if addon == "Blizzard_PlayerSpells" then HookSpellUI() end
    if CooldownViewerSettings and CooldownViewerSettings._orbitOOCHooked
       and PlayerSpellsFrame and PlayerSpellsFrame._orbitOOCHooked then
        self:UnregisterAllEvents()
    end
end)

-- [ MIXIN FUNCTIONS ]--------------------------------------------------------------------------------
function Mixin:ApplyOOCFade(frame, plugin, systemIndex, settingKey, enableHover, veKey)
    if not frame then return end
    if plugin then
        settingKey = settingKey or "OutOfCombatFade"
        veKey = Orbit.VisibilityEngine and Orbit.VisibilityEngine:GetKeyForPlugin(plugin.name, systemIndex)
    end
    if veKey and Orbit.VisibilityEngine then
        enableHover = Orbit.VisibilityEngine:GetFrameSetting(veKey, "mouseOver")
            or (Orbit.FadeProfiles and Orbit.FadeProfiles:FrameHasMouseoverProfile(veKey)) or false
    end
    ManagedFrames[frame] = { plugin = plugin, systemIndex = systemIndex, settingKey = settingKey, enableHover = enableHover or false, veKey = veKey }
    RefreshVESnapshot(frame, ManagedFrames[frame])
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
            local p = Orbit.Profiler
            local s = p and p:Begin()
            local isOver = MouseIsOver(target)
            if isOver and not target.orbitMouseOver then
                target.orbitMouseOver = true
                UpdateFrameVisibility(target, nil, ManagedFrames[target])
                if Orbit.FadeProfiles then Orbit.FadeProfiles:OnFrameHoverChanged(target._veKey, true) end
            elseif not isOver and target.orbitMouseOver then
                target.orbitMouseOver = nil
                UpdateFrameVisibility(target, nil, ManagedFrames[target])
                if Orbit.FadeProfiles then Orbit.FadeProfiles:OnFrameHoverChanged(target._veKey, false) end
            end
            if p then
                local d = ManagedFrames[target]
                p:End(d and d.plugin or "Orbit_OOCFade", "HoverTicker", s)
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
            local p = Orbit.Profiler
            local s = p and p:Begin()

            -- Read from snapshot — hook fires 60Hz during fades, each cached field removes a VE lookup per fire.
            local opacity, oocFade, mouseOver, showWithTarget, alphaLock =
                self._veOpacity, self._veOocFade, self._veMouseOver, self._veShowWithTarget, self._veAlphaLock
            local maxAlpha = self.orbitOpacityExternal and 1 or (opacity or 100) / 100

            -- Mounted hidden check (shared by all paths)
            local isMountedHide = false
            if Orbit.MountedVisibility and Orbit.MountedVisibility:IsCachedHidden() then
                if self._veHideMounted then
                    local revealFull = (showWithTarget and UnitExists("target")) or (mouseOver and self.orbitMouseOver) or IsCursorRevealing(self) or IsSpellUIOpen()
                    if not revealFull then isMountedHide = true end
                end
            end
            
            local finalAlpha = alpha
            if isMountedHide then 
                finalAlpha = 0
            elseif IsSpellUIOpen() then
                -- Spell UI override: show bars at full alpha
                finalAlpha = math.max(alpha, 1)
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
            
            finalAlpha = math.min(finalAlpha, ResolveProfileCap(self))
            -- Apply guarded alpha correction if necessary
            if finalAlpha ~= alpha then
                self._orbitSetAlphaGuard = true
                self:SetAlpha(finalAlpha)
                self._orbitSetAlphaGuard = false
            end
            if p then p:End(d.plugin or "Orbit_OOCFade", "SetAlphaHook", s) end
        end)
        frame.orbitOOCSetAlphaHooked = true
    end
    UpdateFrameVisibility(frame, nil, ManagedFrames[frame])
end

-- Tear down hover ticker AND any in-flight UIFrameFadeIn/Out so a caller's subsequent SetAlpha sticks.
function Mixin:RemoveOOCFade(frame)
    if not frame then return end
    ManagedFrames[frame] = nil
    if frame.orbitOOCHoverTicker then frame.orbitOOCHoverTicker:Hide() end
    frame.orbitMouseOver = nil
    Orbit.Animation:StopHoverFade(frame)
    frame:SetAlpha(1)
end

function Mixin:RefreshAll()
    UpdateAllFrames()
end

if table.freeze then table.freeze(Orbit.OOCFadeMixin) end
