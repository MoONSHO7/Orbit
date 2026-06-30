---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local C = Orbit.ObjectivesConstants
local SYSTEM_ID = C.SYSTEM_ID

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Objectives", SYSTEM_ID, {
    defaults = {
        StyleMode = C.STYLE_MODE_DEFAULT,
        Scale = C.DEFAULT_SCALE,
        Width = C.DEFAULT_WIDTH,
        Height = C.DEFAULT_HEIGHT,
        HeaderColor = C.HEADER_COLOR_DEFAULT,
        ShowBorder = false,
        BackgroundOpacity = C.BG_OPACITY_DEFAULT,
        HeaderSeparators = true,
        AutoCollapseCombat = false,
        ZoneFilter = false,
        ZoneWorldQuests = false,
        ShowQuestCount = true,
        Opacity = C.OPACITY_DEFAULT,
        ProgressBarLabelFormat = C.PROGRESS_FORMAT_DEFAULT,
        TitleFontSize = C.TITLE_FONT_SIZE_DEFAULT,
        ObjectiveFontSize = C.OBJECTIVE_FONT_SIZE_DEFAULT,
        HeaderFontSize = C.HEADER_FONT_SIZE_DEFAULT,
        TitleColor = C.TITLE_COLOR_DEFAULT,
        CompletedColor = C.COMPLETED_COLOR_DEFAULT,
        FocusColor = C.FOCUS_COLOR_DEFAULT,
    },
    displayName = Orbit.L.PLG_NAME_OBJECTIVES,
})

-- Key binding label for ORBIT_OBJECTIVES_TOGGLE (Bindings.xml); shown under BINDING_HEADER_ORBIT.
_G.BINDING_NAME_ORBIT_OBJECTIVES_TOGGLE = Orbit.L.PLU_OBJ_BINDING_TOGGLE

Mixin(Plugin, Orbit.NativeBarMixin)

-- [ COLOUR MIGRATION ]-------------------------------------------------------------------------------
-- Migrates colour-curve {pins=...} format to plain {r,g,b,a} tables. Runs once at OnLoad.
local COLOR_KEYS = { "TitleColor", "CompletedColor", "FocusColor" }

local function MigrateColorSettings(plugin)
    for _, key in ipairs(COLOR_KEYS) do
        local raw = plugin:GetSetting(SYSTEM_ID, key)
        local clean = C.ValidateColor(raw, nil)
        if clean and clean ~= raw then
            plugin:SetSetting(SYSTEM_ID, key, clean)
        end
    end
end

-- Migrate retired ClassColorHeaders/ProgressBarMode keys, then clear them so this runs once.
local function MigrateLegacySettings(plugin)
    if plugin:GetSetting(SYSTEM_ID, "ClassColorHeaders") == true then
        plugin:SetSetting(SYSTEM_ID, "HeaderColor", { r = 1, g = 1, b = 1, a = 1, type = "class" })
    end
    plugin:SetSetting(SYSTEM_ID, "ClassColorHeaders", nil)

    local mode = plugin:GetSetting(SYSTEM_ID, "ProgressBarMode")
    if (mode == "XY" or mode == "Both")
        and plugin:GetSetting(SYSTEM_ID, "ProgressBarLabelFormat") == C.PROGRESS_FORMAT_DEFAULT then
        plugin:SetSetting(SYSTEM_ID, "ProgressBarLabelFormat", mode == "XY" and "Current / Max" or "Current / Max (%)")
    end
    plugin:SetSetting(SYSTEM_ID, "ProgressBarMode", nil)

    plugin:SetSetting(SYSTEM_ID, "SkinProgressBars", nil)
    plugin:SetSetting(SYSTEM_ID, "BlizzardProgressBars", nil)
end

-- True when an anchor's width-sync owns our width (top/bottom edge).
local function IsWidthSynced(frame)
    if not frame.orbitWidthSync then return false end
    local FA = OrbitEngine.FrameAnchor
    local anchor = FA and FA.anchors[frame]
    if not anchor then return false end
    local Axis = OrbitEngine.Axis
    local edgeAxis = Axis and Axis.ForEdge(anchor.edge)
    return (edgeAxis and edgeAxis.perpendicular == Axis.horizontal) or false
end

-- [ STYLE MODE ]-------------------------------------------------------------------------------------
-- "Blizzard" leaves the native tracker chrome (larger bars/headers) intact inside the Orbit container; "Orbit" applies the custom skin. Read by the skin gate (SetSkinEnabled), the cosmetic passes (InstallSkinHooks/ApplySkins), the content-height separator reservation, and the settings UI. Reload-gated, since the skin strips Blizzard textures irreversibly within a session.
function Plugin:IsOrbitStyle()
    return (self:GetSetting(SYSTEM_ID, "StyleMode") or C.STYLE_MODE_DEFAULT) ~= C.STYLE_BLIZZARD
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- When disabled via Plugin Manager (requires reload), skip all initialisation
    if not Orbit:IsPluginEnabled(self.name) then return end

    MigrateColorSettings(self)
    MigrateLegacySettings(self)

    -- Create container frame that will own the Blizzard ObjectiveTrackerFrame
    self.frame = CreateFrame("Frame", "OrbitObjectivesContainer", UIParent)
    -- Pixel-lock every dynamic size change (content-fit, collapse animation, resize, width-sync) to the physical grid, the way FrameFactory frames get it for free.
    OrbitEngine.Pixel:Enforce(self.frame)
    self.frame:SetSize(C.DEFAULT_WIDTH, C.DEFAULT_HEIGHT)
    self.frame:SetClampedToScreen(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = self.displayName
    self.frame.orbitResizeBounds = {
        minW     = C.WIDTH_MIN,
        maxW     = C.WIDTH_MAX,
        minH     = C.HEIGHT_MIN,
        maxH     = C.HEIGHT_MAX,
        widthKey = "Width",
        heightKey = "Height",
    }

    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
    }

    -- Force the saved/restored anchor to keep a TOP component so the box grows downward on resize instead of re-centering.
    self.frame.orbitForceAnchorPoint = "TOPRIGHT"

    -- When docked top/bottom to another Orbit frame, match that frame's width.
    self.frame.orbitWidthSync = true

    -- Native ScrollFrame viewport (the proven Kaliel's-Tracker pattern): it clips and offsets its scroll child at the engine level, replacing the hand-rolled clip frame + SetPoint-offset scroll. It only clips its own child, so the Edit Mode selection/resize handle (sibling children of self.frame) stay visible. Inset/size applied in ApplySettings.
    self.scrollFrame = CreateFrame("ScrollFrame", "OrbitObjectivesScroll", self.frame)
    self.scrollFrame:SetClipsChildren(true)
    self.scrollFrame:EnableMouseWheel(true)
    self.scrollFrame:SetScript("OnMouseWheel", function(_, delta) self:OnScroll(delta) end)
    -- Content shrinking (quest dropped / collapse) can leave the scroll past the new end; clamp back into range.
    self.scrollFrame:SetScript("OnScrollRangeChanged", function(sf, _, yRange)
        if sf:GetVerticalScroll() > yRange then sf:SetVerticalScroll(math.max(0, yRange)) end
    end)

    self.scrollChild = CreateFrame("Frame", "OrbitObjectivesScrollChild", self.scrollFrame)
    self.scrollChild:SetSize(C.DEFAULT_WIDTH, C.DEFAULT_HEIGHT)
    self.scrollFrame:SetScrollChild(self.scrollChild)
    self.scrollFrame:SetScript("OnSizeChanged", function(_, w) self.scrollChild:SetWidth(w) end)

    -- Default position: right side, below minimap
    self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", C.DEFAULT_ANCHOR_X, C.DEFAULT_ANCHOR_Y)

    -- Register to Orbit edit mode + position persistence
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    self:InstallCombatCollapseHooks()

    -- Root frame: standard events miss border/background changes, so listen explicitly.
    Orbit.EventBus:On("ORBIT_BORDER_SIZE_CHANGED", function() self:ApplySettings() end, self)
    Orbit.EventBus:On("ORBIT_GLOBAL_BACKDROP_CHANGED", function() self:ApplySettings() end, self)

    -- Profile changes are already covered by the shared restore (Persistence:RestoreAffectedByProfileChange runs over every attached frame) plus RefreshAllPlugins' ApplySettings. Spec changes are not: the shared spec-restore deliberately covers only spec-scoped plugins (perf guard) and Objectives isn't one, yet Blizzard re-anchors the managed tracker on spec — so re-assert here. Next frame, after Blizzard's relayout.
    Orbit.EventBus:On("ORBIT_PLAYER_SPECIALIZATION_CHANGED", function() RunNextFrame(function() self:ReassertLayout() end) end, self)

    -- Hook ObjectiveTracker addon loading
    local function HookTracker()
        self:CaptureTracker()
        self:InstallSkinHooks()
        self:InstallCollapseHooks()
        self:ApplySettings()
    end

    if C_AddOns.IsAddOnLoaded("Blizzard_ObjectiveTracker") then
        HookTracker()
    else
        self._addonLoader = CreateFrame("Frame")
        self._addonLoader:RegisterEvent("ADDON_LOADED")
        self._addonLoader:SetScript("OnEvent", function(f, event, addonName)
            if addonName == "Blizzard_ObjectiveTracker" then
                HookTracker()
                f:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- [ CAPTURE ]----------------------------------------------------------------------------------------
function Plugin:CaptureTracker()
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end

    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:CaptureTracker() end)
        return
    end

    if tracker:GetParent() ~= self.scrollChild then
        local parent = tracker:GetParent()
        -- Only capture from native Blizzard parents
        if parent ~= UIParent and parent ~= (UIParentRightManagedFrameContainer or UIParent) then
            return
        end
        tracker:SetParent(self.scrollChild)
    end

    tracker:ClearAllPoints()
    tracker:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, 0)
    tracker:SetPoint("TOPRIGHT", self.scrollChild, "TOPRIGHT", 0, 0)

    -- The tracker is a screen-clamped, LOW-strata UIParentRight-managed frame. Inside a scroll viewport both must be undone: unclamp so it scrolls past the screen edge into the clipped region (instead of sticking at the edge), and match the scroll frame's strata so SetClipsChildren actually clips it — a different-strata child escapes the clip and renders outside the box.
    tracker:SetClampedToScreen(false)
    tracker:SetFrameStrata(self.scrollFrame:GetFrameStrata())

    -- Suppress Blizzard's native Edit Mode selection (prevents double-highlight)
    if tracker.Selection then
        tracker.Selection:SetAlpha(0)
        tracker.Selection:EnableMouse(false)
    end

    -- Protect against re-parenting by Blizzard or other addons
    OrbitEngine.FrameGuard:Protect(tracker, self.scrollChild)
    OrbitEngine.FrameGuard:UpdateProtection(tracker, self.scrollChild, function()
        self:ApplySettings()
    end, { enforceShow = false })

    -- Override the tracker's height system so modules use our container height
    if not self._heightOverridden then
        -- Let Blizzard render every block regardless of visible height; the ScrollFrame supplies the viewport + scrolling.
        tracker.GetAvailableHeight = function()
            return C.MAX_TRACKER_HEIGHT
        end

        -- Wheel over the box or the tracker scrolls the viewport (the ScrollFrame handles direct hovers itself).
        local function Wheel(_, delta) self:OnScroll(delta) end
        self.frame:EnableMouseWheel(true)
        self.frame:SetScript("OnMouseWheel", Wheel)
        tracker:EnableMouseWheel(true)
        tracker:SetScript("OnMouseWheel", Wheel)

        -- Real content height = topModulePadding (which spans the master header) + module heights + the moduleSpacing Blizzard inserts between them. Drives both the tracker and the ScrollFrame's scroll child, whose height the engine uses for GetVerticalScrollRange. No re-entrancy — GetAvailableHeight is constant so SetHeight never changes the layout.
        tracker.UpdateHeight = function(container)
            local count, sum = 0, 0
            for _, module in ipairs(container.modules or {}) do
                local ch = module:GetContentsHeight()
                if module:IsShown() and ch > 0 then
                    sum = sum + ch
                    count = count + 1
                end
            end
            local h
            if count > 0 then
                h = (container.topModulePadding or 0) + sum + (container.moduleSpacing or 0) * (count - 1)
            elseif container.Header and container.Header:IsShown() then
                h = container.Header:GetHeight()
            else
                h = 0
            end
            h = math.max(h, C.MIN_TRACKER_HEIGHT)
            -- Reserve a sliver for the trailing header separator: it hangs just below the last header, so on a collapsed last section it lands in the bottom inset where the ScrollFrame would clip it. Only the Orbit skin draws separators, so Blizzard style reserves nothing.
            if self:IsOrbitStyle() and self:GetSetting(SYSTEM_ID, "HeaderSeparators") ~= false then
                h = h + OrbitEngine.Pixel:Multiple(C.HEADER_SEPARATOR_HEIGHT + 1, container:GetEffectiveScale())
            end
            container:SetHeight(h)
            if self.scrollChild then self.scrollChild:SetHeight(h) end

            self:RefreshEmptyState()
            self:ApplyContainerHeight()
        end

        -- Blizzard calls UpdateHeight only on OnShow, so a relayout (quest added, objective changed) leaves our content height + scroll range stale and the bottom clips unscrollably. Recompute on every relayout; converges in one extra cycle since GetAvailableHeight is constant (no oscillation). UpdateHeight also runs RefreshEmptyState.
        hooksecurefunc(tracker, "Update", function()
            if tracker.UpdateHeight then tracker:UpdateHeight() end
            self:UpdateSeparators()
        end)

        self._heightOverridden = true
    end

    self._captured = true
end

-- [ SCROLL ]-----------------------------------------------------------------------------------------
-- The ScrollFrame derives its range from scroll-child height vs viewport height; we just step within it.
function Plugin:OnScroll(delta)
    local sf = self.scrollFrame
    if not sf then return end
    local range = sf:GetVerticalScrollRange()
    if range <= 0 then return end
    local v = sf:GetVerticalScroll() - delta * C.SCROLL_SPEED
    if v < 0 then v = 0 elseif v > range then v = range end
    sf:SetVerticalScroll(v)
end

-- [ APPLY SETTINGS ]---------------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then return end

    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:ApplySettings() end)
        return
    end

    -- Skin hooks gate on the style mode: Orbit applies the custom skin, Blizzard leaves native chrome.
    self:SetSkinEnabled(self:IsOrbitStyle())

    self:CaptureTracker()

    local scale = self:GetSetting(SYSTEM_ID, "Scale") or C.DEFAULT_SCALE
    local width = self:GetSetting(SYSTEM_ID, "Width") or C.DEFAULT_WIDTH
    local height = self:GetSetting(SYSTEM_ID, "Height") or C.DEFAULT_HEIGHT
    frame:SetScale(scale / 100)
    frame:Show()

    -- Border must be applied before width/anchors so borderPixelSize is available for inset calc
    self:ApplyBorder()

    -- Background backdrop
    self:ApplyBackdrop()

    -- Apply size and re-anchor tracker inside border. When width-synced to an anchor parent, the anchor engine owns our width.
    local s = frame:GetEffectiveScale()
    local snappedHeight = OrbitEngine.Pixel:Snap(height, s)
    if IsWidthSynced(frame) then
        frame:SetHeight(snappedHeight)
    else
        frame:SetSize(OrbitEngine.Pixel:Snap(width, s), snappedHeight)
    end
    local containerWidth = frame:GetWidth()

    -- ScrollFrame fills the box interior (inset for border + content padding); the scroll child matches its width so only vertical scrolling occurs.
    local inset = self:GetContentInset()
    local innerWidth = containerWidth - (inset * 2)
    self.scrollFrame:ClearAllPoints()
    self.scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    self.scrollChild:SetWidth(innerWidth)

    if ObjectiveTrackerFrame then
        -- Blizzard style hangs each block's POI button ~7px left of the module edge (blockOffsetX 20 − 7 anchor − 20 POI width), which the ScrollFrame clips. Shift the native content right so the icons clear the clip; the header backgrounds compensate back to full width (FitNativeHeaderBackground). Orbit style repositions the POI itself, so no pad.
        local leftPad = self:IsOrbitStyle() and 0 or C.BLIZZARD_LEFT_PAD
        ObjectiveTrackerFrame:ClearAllPoints()
        ObjectiveTrackerFrame:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", leftPad, 0)
        ObjectiveTrackerFrame:SetPoint("TOPRIGHT", self.scrollChild, "TOPRIGHT", 0, 0)
    end

    -- Re-apply skins with current settings
    self:ApplySkins()

    -- Restore collapse state (always persist), then size the box to it (collapsed = tight bar)
    self:RestoreCollapseState()
    self:ApplyContainerHeight()

    -- Full Visibility Engine integration (opacity, oocFade, mouseOver reveal, showWithTarget, hideMounted) — supersedes ApplyMouseOver; keyed off the VE entry registered in Plugins/VisibilityManifest.lua.
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, SYSTEM_ID) end

    -- Zone filter + area world-quest tracker manage the watch list off their own events; this reconciles their enabled states (idempotent).
    self:UpdateZoneFilters()

    -- Hide all chrome when nothing is tracked (border/backdrop were just applied per settings)
    self._isEmpty = self:IsTrackerEmpty()
    if self._isEmpty then self:ApplyEmptyVisibility(true) end
end

-- [ RE-ASSERT LAYOUT ]-------------------------------------------------------------------------------
-- Re-apply the saved position + full layout — what Edit Mode exit effectively does — after a spec change displaces the reparented tracker. RestorePosition fixes the container; ApplySettings re-anchors the managed tracker (a bare RestorePosition, which is all the shared spec-restore does, would not). SetPoint on the container — parent of the managed tracker — is protected, so defer out of combat.
function Plugin:ReassertLayout()
    if not self.frame then return end
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:ReassertLayout() end)
        return
    end
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)
    self:ApplySettings()
end

-- [ CONTAINER HEIGHT ]-------------------------------------------------------------------------------
-- Box height for the collapsed master bar: header with symmetric top/bottom inset (the separator is hidden while collapsed, so there's no divider to hug).
function Plugin:CollapsedBarHeight()
    local tracker = ObjectiveTrackerFrame
    local barH = (tracker and tracker.Header and tracker.Header:GetHeight()) or C.MIN_TRACKER_HEIGHT
    return barH + 2 * self:GetContentInset()
end

-- Uncapped box height that wraps the content with symmetric top/bottom inset. The trailing header's separator is hidden (UpdateSeparators) when content ends on a collapsed header, so there's no divider to hug — the box pads evenly top and bottom.
function Plugin:DesiredContentHeight()
    local heightSetting = self:GetSetting(SYSTEM_ID, "Height") or C.DEFAULT_HEIGHT
    local tracker = ObjectiveTrackerFrame
    if not tracker then return heightSetting end
    if tracker.IsCollapsed and tracker:IsCollapsed() then return self:CollapsedBarHeight() end
    return tracker:GetHeight() + 2 * self:GetContentInset()
end

-- Box content-fits, capped at the Height setting — position-independent (no screen-relative cap: that made the box height depend on where on screen it sat). The ScrollFrame scrolls anything beyond. Edit mode = full Height (grabbable; the resize handle drives the real setting).
function Plugin:ResolveContainerHeight()
    local heightSetting = self:GetSetting(SYSTEM_ID, "Height") or C.DEFAULT_HEIGHT
    if Orbit:IsEditMode() then return heightSetting end
    return math.min(heightSetting, self:DesiredContentHeight())
end

-- A stale saved position can restore a centered anchor (RestorePosition applies the stored point verbatim); re-pin to the forced TOP point — preserving the current spot — so SetHeight holds the top instead of growing about the centre.
function Plugin:HoldTopAnchor()
    local frame = self.frame
    local forced = frame.orbitForceAnchorPoint
    if not forced or frame.orbitIsDragging then return end
    local point, relTo = frame:GetPoint(1)
    if point == forced or (relTo and relTo ~= UIParent) then return end
    local p, x, y = OrbitEngine.FrameSnap:NormalizePosition(frame)
    if p then
        frame:ClearAllPoints()
        frame:SetPoint(p, x, y)
    end
end

-- override (capped at Height) lets the collapse animation drive the box height per frame so the backdrop tracks the slide; without it the box uses the settled content-fit height.
function Plugin:ApplyContainerHeight(override)
    local frame = self.frame
    if not frame then return end
    -- During the slide (override set), skip the re-pin: HoldTopAnchor could jump the box on a stale anchor. The ScrollFrame is anchored to the box, so SetHeight resizes the viewport and OnScrollRangeChanged re-clamps the scroll.
    if not override then self:HoldTopAnchor() end
    local h = override and math.min(override, self:GetSetting(SYSTEM_ID, "Height") or C.DEFAULT_HEIGHT) or self:ResolveContainerHeight()
    frame:SetHeight(OrbitEngine.Pixel:Snap(h, frame:GetEffectiveScale()))
end

-- [ BORDER ]-----------------------------------------------------------------------------------------
function Plugin:ApplyBorder()
    local frame = self.frame
    local showBorder = self:GetSetting(SYSTEM_ID, "ShowBorder")
    if showBorder == false then
        if Orbit.Skin.ClearNineSliceBorder then Orbit.Skin:ClearNineSliceBorder(frame) end
        if frame._borderFrame then frame._borderFrame:Hide() end
        return
    end

    local gs = Orbit.db and Orbit.db.GlobalSettings
    local borderSize = gs and gs.BorderSize or 1
    Orbit.Skin:SkinBorder(frame, frame, borderSize)
end

-- [ CONTENT INSET ]----------------------------------------------------------------------------------
function Plugin:GetContentInset()
    local showBorder = self:GetSetting(SYSTEM_ID, "ShowBorder")
    local borderInset = 0
    if showBorder ~= false then
        borderInset = OrbitEngine.Pixel:BorderInset(self.frame, 1)
    end
    return borderInset + C.CONTENT_PADDING
end

-- [ BACKDROP ]---------------------------------------------------------------------------------------
function Plugin:ApplyBackdrop()
    local frame = self.frame
    local opacity = (self:GetSetting(SYSTEM_ID, "BackgroundOpacity") or C.BG_OPACITY_DEFAULT) / 100

    if not frame._backdrop then
        frame._backdrop = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        frame._backdrop:SetAllPoints(frame)
    end

    if opacity > 0 then
        local bgColor = Orbit.Skin:GetBackgroundColor()
        frame._backdrop:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, opacity)
        frame._backdrop:Show()
    else
        frame._backdrop:Hide()
    end
end

-- [ EMPTY STATE ]------------------------------------------------------------------------------------
-- Hide chrome when nothing is tracked; restore per settings when content returns.
function Plugin:IsTrackerEmpty()
    if Orbit:IsEditMode() then return false end
    local tracker = ObjectiveTrackerFrame
    if not tracker or not tracker.modules then return true end
    -- When collapsed, Blizzard hides every module (IsShown false) but contentsHeight stays positive — so don't gate on IsShown, or a collapsed-but-populated tracker reads as empty and loses its chrome.
    local collapsed = tracker.IsCollapsed and tracker:IsCollapsed()
    for _, module in ipairs(tracker.modules) do
        local ch = module.contentsHeight
        if ch and ch > 0 and (collapsed or module:IsShown()) then
            return false
        end
    end
    return true
end

function Plugin:ApplyEmptyVisibility(empty)
    local frame = self.frame
    if not frame then return end
    if empty then
        if frame._backdrop then frame._backdrop:Hide() end
        if frame._borderFrame then frame._borderFrame:Hide() end
        if frame._edgeBorderOverlay then frame._edgeBorderOverlay:Hide() end
    else
        self:ApplyBorder()
        self:ApplyBackdrop()
    end
end

function Plugin:RefreshEmptyState()
    local empty = self:IsTrackerEmpty()
    if empty == self._isEmpty then return end
    self._isEmpty = empty
    self:ApplyEmptyVisibility(empty)
end

-- The master separator divides it from the modules below — hide it only while the master itself is collapsed (genuinely nothing below it). Module separators always show per the setting, so a collapsed sub-header keeps its divider and reads consistently with the master. Colours persist from ApplySkins; this only toggles visibility. Runs on every relayout + at the end of ApplySkins.
function Plugin:UpdateSeparators()
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    local sepOn = self:GetSetting(SYSTEM_ID, "HeaderSeparators") ~= false

    local masterSep = tracker.Header and tracker.Header._orbitSeparator
    if masterSep then
        masterSep:SetShown(sepOn and not (tracker.IsCollapsed and tracker:IsCollapsed()))
    end

    for _, m in ipairs(tracker.modules or {}) do
        local sep = m.Header and m.Header._orbitSeparator
        if sep then sep:SetShown(sepOn) end
    end
end

-- [ COLLAPSE PERSISTENCE ]---------------------------------------------------------------------------
function Plugin:SaveCollapseState()
    if not Orbit.db or not Orbit.db.AccountSettings then return end
    local state = {}

    -- Main tracker collapse
    if ObjectiveTrackerFrame then
        state._main = ObjectiveTrackerFrame.isCollapsed or false
    end

    -- Per-module collapse
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker then
            state[moduleName] = tracker.isCollapsed or false
        end
    end

    Orbit.db.AccountSettings.ObjectivesCollapseState = state
end

function Plugin:RestoreCollapseState()
    local state = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.ObjectivesCollapseState
    if not state then return end

    -- Main tracker
    if ObjectiveTrackerFrame and state._main and ObjectiveTrackerFrame.SetCollapsed then
        if ObjectiveTrackerFrame.isCollapsed ~= state._main then
            ObjectiveTrackerFrame:SetCollapsed(state._main)
        end
    end

    -- Per-module
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker and state[moduleName] ~= nil and tracker.SetCollapsed then
            if tracker.isCollapsed ~= state[moduleName] then
                tracker:SetCollapsed(state[moduleName])
            end
        end
    end
end

-- [ COLLAPSE TOGGLE ]--------------------------------------------------------------------------------
-- Instant collapse/expand for a module or the master container — no animation. Toggle, settle Blizzard's layout synchronously (dirty primed so SetCollapsed's MarkDirty doesn't queue a deferred relayout), then resize the box. The transient _orbitAnimating flag suppresses Blizzard's header shine for this toggle (see the PlayAddAnimation hook).
function Plugin:ToggleCollapse(target)
    if not target or not target.ToggleCollapsed then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    target._orbitAnimating = true
    ObjectiveTrackerFrame.dirty = true
    target:ToggleCollapsed()
    ObjectiveTrackerFrame:Update(true)
    ObjectiveTrackerFrame.dirty = nil
    target._orbitAnimating = nil
    if ObjectiveTrackerFrame.UpdateHeight then ObjectiveTrackerFrame:UpdateHeight() end
end

function Plugin:InstallCollapseHooks()
    if self._collapseHooksInstalled then return end

    -- Hook the main tracker header collapse
    if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header and ObjectiveTrackerFrame.Header.SetCollapsed then
        hooksecurefunc(ObjectiveTrackerFrame.Header, "SetCollapsed", function()
            self:SaveCollapseState()
            self:RefreshEmptyState()
            self:ApplyContainerHeight()
        end)
    end

    -- Hook per-module collapse via their headers
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local module = _G[moduleName]
        if module and module.Header and module.Header.SetCollapsed then
            hooksecurefunc(module.Header, "SetCollapsed", function()
                self:SaveCollapseState()
            end)
            -- Suppress Blizzard's header shine while a toggle owns this module (or the master); _orbitAnimating is set transiently by ToggleCollapse.
            if module.Header.PlayAddAnimation then
                hooksecurefunc(module.Header, "PlayAddAnimation", function(header)
                    if (module._orbitAnimating or ObjectiveTrackerFrame._orbitAnimating) and header.AddAnim then
                        header.AddAnim:Stop()
                    end
                end)
            end
        end
    end

    self._collapseHooksInstalled = true
end

-- [ AUTO-COLLAPSE IN COMBAT ]------------------------------------------------------------------------
function Plugin:InstallCombatCollapseHooks()
    if self._combatCollapseInstalled then return end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        local enabled = self:GetSetting(SYSTEM_ID, "AutoCollapseCombat")
        if not enabled then return end
        if not ObjectiveTrackerFrame then return end

        if event == "PLAYER_REGEN_DISABLED" then
            -- Save current state before collapsing
            self._preCombatCollapsed = ObjectiveTrackerFrame.isCollapsed
            if not ObjectiveTrackerFrame.isCollapsed and ObjectiveTrackerFrame.SetCollapsed then
                ObjectiveTrackerFrame:SetCollapsed(true)
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Restore pre-combat state
            if self._preCombatCollapsed == false and ObjectiveTrackerFrame.SetCollapsed then
                ObjectiveTrackerFrame:SetCollapsed(false)
            end
            self._preCombatCollapsed = nil
        end
    end)

    self._combatCollapseInstalled = true
end

-- [ BLIZZARD HIDER ]---------------------------------------------------------------------------------
Orbit:RegisterBlizzardHider("Objectives", function()
    if ObjectiveTrackerFrame then OrbitEngine.NativeFrame:SecureHide(ObjectiveTrackerFrame) end
end)
