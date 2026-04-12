-- [ ORBIT TRACKED PLUGIN ] ----------------------------------------------------
-- Spawns user-authored cooldown containers (icon grids) and single-spell bars
-- from tabs added to Blizzard's CooldownViewerSettings frame. Each container is
-- a flat record under OrbitDB.GlobalSettings.TrackedContainers, keyed by a
-- monotonic counter id that doubles as the system index. Records carry their
-- own spec field; only records matching the current spec get a live frame.
--
-- Architecture:
--   * Container records live in a flat global table → globally-unique ids
--   * Counter ensures ids are sparse and never reused
--   * mode = "icons" or "bar" — distinct frame types, never transformed
--   * Per-spec caps (MaxIconContainers / MaxBars) enforced at create time
--   * Settings are stored on the record itself, not in the layout DB, so
--     GetSetting/SetSetting are overridden to redirect by systemIndex → record
--   * Tab buttons are click-to-spawn (not panel switchers); registered with
--     Orbit_CooldownViewerExtensions which owns the Blizzard ADDON_LOADED hook
local _, Orbit = ...

local Constants = Orbit.Constants
local DragDrop = Orbit.CooldownDragDrop

-- [ CONSTANTS ] ---------------------------------------------------------------
local MAX_ICON_CONTAINERS = Constants.Tracked.MaxIconContainers
local MAX_BARS = Constants.Tracked.MaxBars
local SYSTEM_ID_BASE = Constants.Tracked.SystemIndexBase
local TAB_ATLAS = "communities-chat-icon-plus"
local TAB_ID_ICONS = "Orbit_Tracked.Icons"
local TAB_ID_BARS = "Orbit_Tracked.Bars"
-- Tab tints match each plugin's empty-state dropzone color so the create
-- buttons read as "drop a new green/yellow square here".
local TAB_TINT_ICONS = { r = 0.40, g = 0.85, b = 0.40 }
local TAB_TINT_BARS = { r = 1.00, g = 0.82, b = 0.00 }
local DEFAULT_ICON_OFFSET_Y = 0
local DEFAULT_BAR_OFFSET_X = 250
local TALENT_REFRESH_DEBOUNCE = 0.1

-- [ PLUGIN REGISTRATION ] -----------------------------------------------------
-- settingsArePerSpec: opts Tracked OUT of Persistence's spec-data routing for
-- saved Anchor/Position. Each Tracked record carries its own `spec` field and
-- record.settings is already per-spec at the storage layer, so a second per-
-- spec partition (PluginMixin.SpecData) would silently desync from
-- record.settings on subsequent edits and would not survive a profile export.
--
-- canvasMode: opts the bar/icon frames into the right-click → Canvas Mode flow
-- so users can move/disable NameText/CountText (bars) and ChargeText (icons).
-- ComponentPositions defaults are per-component because each Tracked record has
-- one shared schema; per-record overrides land in record.settings via the
-- GetSetting redirect below, so the canvas dialog persists positions per bar
-- without needing a separate ComponentPositions store on each record.
local Plugin = Orbit:RegisterPlugin("Tracked Items", "Orbit_Tracked", {
    liveToggle = true,
    settingsArePerSpec = true,
    containers = {}, -- live frames keyed by id
    defaults = {
        IconSize = Constants.Cooldown.DefaultIconSize,
        IconPadding = Constants.Cooldown.DefaultPadding,
        aspectRatio = "1:1",
        Opacity = 100,
        Width = 200,
        Height = 20,
        DisabledComponents = {},
        ComponentPositions = {
            NameText = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            CountText = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
            ChargeText = { anchorX = "RIGHT", offsetX = 2, anchorY = "BOTTOM", offsetY = 2, justifyH = "RIGHT" },
        },
    },
    OnLoad = function(self)
        self:EnsureStore()
        self:RegisterTabs()
        self:RefreshForCurrentSpec()
        Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function() self:RefreshForCurrentSpec() end, self)
        Orbit.EventBus:On("ACTIVE_TALENT_GROUP_CHANGED", function() self:RefreshForCurrentSpec() end, self)
        Orbit.EventBus:On("PLAYER_SPECIALIZATION_CHANGED", function() self:RefreshForCurrentSpec() end, self)
        Orbit.EventBus:On("TRAIT_CONFIG_UPDATED", function() self:_ScheduleBarPayloadRefresh() end, self)
    end,
})
Plugin.canvasMode = true

-- [ STORE BOOTSTRAP ] ---------------------------------------------------------
function Plugin:EnsureStore()
    local gs = Orbit.db.GlobalSettings
    if not gs.TrackedContainers then gs.TrackedContainers = {} end
    if not gs.NextTrackedContainerId then gs.NextTrackedContainerId = SYSTEM_ID_BASE end
end

function Plugin:GetStore()
    return Orbit.db.GlobalSettings.TrackedContainers
end

function Plugin:AllocateId()
    local gs = Orbit.db.GlobalSettings
    local id = gs.NextTrackedContainerId
    gs.NextTrackedContainerId = id + 1
    return id
end

-- [ RECORD QUERIES ] ----------------------------------------------------------
function Plugin:GetContainerRecord(id)
    return self:GetStore()[id]
end

function Plugin:ContainersForSpec(specID, mode)
    local out = {}
    for _, record in pairs(self:GetStore()) do
        if record.spec == specID and (not mode or record.mode == mode) then
            table.insert(out, record)
        end
    end
    return out
end

function Plugin:CountForSpec(specID, mode)
    local n = 0
    for _, record in pairs(self:GetStore()) do
        if record.spec == specID and record.mode == mode then n = n + 1 end
    end
    return n
end

-- [ SETTINGS REDIRECT ] -------------------------------------------------------
-- Container records own their settings inline; redirect by systemIndex → record.
-- Anything that isn't a container falls through to the standard layout DB so
-- shared keys (Texture, Font, etc) keep flowing through global inheritance.
local OriginalGetSetting = Orbit.PluginMixin.GetSetting
local OriginalSetSetting = Orbit.PluginMixin.SetSetting

function Plugin:GetSetting(systemIndex, key)
    local record = self:GetContainerRecord(systemIndex)
    if record then
        local val = record.settings and record.settings[key]
        if val ~= nil then return val end
        if self.defaults and self.defaults[key] ~= nil then return self.defaults[key] end
        return nil
    end
    return OriginalGetSetting(self, systemIndex, key)
end

function Plugin:SetSetting(systemIndex, key, value)
    local record = self:GetContainerRecord(systemIndex)
    if record then
        record.settings = record.settings or {}
        record.settings[key] = value
        return
    end
    OriginalSetSetting(self, systemIndex, key, value)
end

-- [ COMPONENT DISABLED OVERRIDE ] ---------------------------------------------
-- PluginMixin's default IsComponentDisabled falls back to self.frame.systemIndex,
-- which is wrong for Tracked: there's no single "current frame" because every
-- record has its own systemIndex. The active Canvas Mode transaction is the
-- only reliable source — when canvas mode is editing a Tracked frame, the
-- transaction's systemIndex tells us which record's DisabledComponents to
-- read. ComponentDrag:IsDisabled (called by the dialog and overlay) routes
-- through this method, so getting it right is what makes drag-to-disable work
-- per-bar instead of always reading record id 1.
function Plugin:IsComponentDisabled(componentKey)
    local txn = self:_ActiveTransaction()
    if txn then
        local disabled = txn:GetDisabledComponents() or {}
        for _, k in ipairs(disabled) do if k == componentKey then return true end end
        local sysIdx = txn:GetSystemIndex()
        if sysIdx then
            local saved = self:GetSetting(sysIdx, "DisabledComponents") or {}
            for _, k in ipairs(saved) do if k == componentKey then return true end end
        end
        return false
    end
    return false
end

-- [ GLOBAL FONT ] -------------------------------------------------------------
-- Returns the resolved path for GlobalSettings.Font (LSM-fetched). Tracked
-- icons and bars call this on every Apply pass so changing the global font in
-- the settings panel propagates without needing a full rebuild.
function Plugin:GetGlobalFont()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    if fontName and LSM then
        return LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    end
    return STANDARD_TEXT_FONT
end

-- [ DROP HINT VISIBILITY ] ----------------------------------------------------
-- Drop hints (icons-mode neighbor zones, bars-mode empty bar hint) are shown
-- whenever the user could plausibly want to see where their tracked frames are:
-- (1) actively dragging a cooldown ability, (2) the cooldown viewer settings
-- panel is open, or (3) edit mode is active AND the frame is empty. Cases (2)
-- and (3) make empty containers discoverable — without them, an empty container
-- is invisible and there's no way to find or delete it. The `isEmpty` argument
-- gates the edit-mode case so populated frames don't sprout hints in edit mode.
function Plugin:ShouldShowDropHints(isEmpty)
    if DragDrop and DragDrop:IsDraggingCooldownAbility() then return true end
    if CooldownViewerSettings and CooldownViewerSettings:IsShown() then return true end
    if isEmpty and Orbit:IsEditMode() then return true end
    return false
end

-- [ TAB REGISTRATION ] --------------------------------------------------------
function Plugin:RegisterTabs()
    local CVE = Orbit:GetPlugin("Orbit_CooldownViewerExtensions")
    if not CVE then return end

    CVE:RegisterTab({
        id = TAB_ID_ICONS,
        atlas = TAB_ATLAS,
        vertexColor = TAB_TINT_ICONS,
        tooltipText = "Add a new Tracked Icon container",
        onClick = function() self:CreateIconContainer() end,
    })

    CVE:RegisterTab({
        id = TAB_ID_BARS,
        atlas = TAB_ATLAS,
        vertexColor = TAB_TINT_BARS,
        tooltipText = "Add a new Tracked Bar",
        onClick = function() self:CreateBar() end,
    })
end

-- [ CONTAINER CREATION ] ------------------------------------------------------
function Plugin:CreateIconContainer()
    local specID = self:GetCurrentSpecID()
    if not specID then return end
    if self:CountForSpec(specID, "icons") >= MAX_ICON_CONTAINERS then
        Orbit:Print("Tracked: max icon containers reached for this spec (" .. MAX_ICON_CONTAINERS .. ")")
        return
    end

    local id = self:AllocateId()
    local record = {
        id = id,
        mode = "icons",
        spec = specID,
        grid = {},
        settings = {},
    }
    self:GetStore()[id] = record
    local frame = self:BuildContainer(record)
    self:SetContainerActive(frame, true)
    return record
end

function Plugin:CreateBar()
    local specID = self:GetCurrentSpecID()
    if not specID then return end
    if self:CountForSpec(specID, "bar") >= MAX_BARS then
        Orbit:Print("Tracked: max bars reached for this spec (" .. MAX_BARS .. ")")
        return
    end

    local id = self:AllocateId()
    local record = {
        id = id,
        mode = "bar",
        spec = specID,
        payload = nil,
        settings = {},
    }
    self:GetStore()[id] = record
    local frame = self:BuildContainer(record)
    self:SetContainerActive(frame, true)
    return record
end

-- Builds a frame for the record, restores its anchor/position into the
-- AnchorGraph, and applies its settings. Does NOT toggle enabled/disabled
-- state — RefreshForCurrentSpec / SetContainerActive own that. Frames are
-- built once for EVERY record across all specs (not just the current one)
-- so that the anchor graph has a node for each frame; chain reconciliation
-- relies on disabled frames remaining in the graph as skipped nodes so it
-- can promote their children up to the nearest non-skipped ancestor.
--
-- RefreshContainerVirtualState is called BEFORE any explicit RestorePosition
-- so that the first SetFrameVirtual flip happens against a frame that's never
-- yet been positioned. RefreshContainerVirtualState calls RestorePosition
-- internally as part of its undo-the-park step, so the frame ends up at its
-- saved Anchor/Position with the virtual flag already correct. ApplySettings
-- then runs Apply → RefreshContainerVirtualState again, which is short-
-- circuited by the `_isVirtual == isEmpty` guard. One restore, one reconcile.
function Plugin:BuildContainer(record)
    local frame
    local defX, defY = 0, 0
    if record.mode == "icons" then
        frame = Orbit.TrackedContainer:Build(self, record)
        defX, defY = 0, DEFAULT_ICON_OFFSET_Y
    elseif record.mode == "bar" then
        frame = Orbit.TrackedBar:Build(self, record)
        defX, defY = DEFAULT_BAR_OFFSET_X, 0
    end
    if not frame then return end
    frame.defaultPosition = { point = "CENTER", relativeTo = UIParent, relativePoint = "CENTER", x = defX, y = defY }
    self.containers[record.id] = frame
    self:RefreshContainerVirtualState(frame)
    if self.ApplySettings then self:ApplySettings(frame) end
    return frame
end

-- [ ENABLE / DISABLE ] --------------------------------------------------------
-- Toggles a container's participation in the layout via the AnchorGraph's
-- skipped-frame mechanism (Anchor:SetFrameDisabled). Disabling parks the
-- frame at its defaultPosition, marks it skipped in the graph, and schedules
-- ReconcileChain which promotes any anchored children up to the nearest
-- non-skipped ancestor (their logical parent pointer is preserved via
-- skipLogical=true on the physical re-anchor). Re-enabling clears the skip
-- flag and re-applies the saved Anchor via RestorePosition (because
-- ParkFrame only changed the visual SetPoint, not the graph entry); the
-- next ReconcileChain pulls promoted children back home via
-- RestoreLogicalChildren. This is the same pattern PlayerResources /
-- PlayerPower use for plugin enable/disable.
function Plugin:SetContainerActive(frame, active)
    if not frame then return end
    if active then
        Orbit.Engine.FrameAnchor:SetFrameDisabled(frame, false)
        self:_SyncOrbitDisabledFlag(frame)
        Orbit.Engine.Frame:RestorePosition(frame, self, frame.recordId)
        frame:Show()
    else
        Orbit.Engine.FrameAnchor:SetFrameDisabled(frame, true)
        frame:Hide()
    end
end

-- [ ORBIT-DISABLED FLAG SYNC ] ------------------------------------------------
-- Anchor:SetFrameVirtual / SetFrameDisabled both write
--     frame.orbitDisabled = Graph:IsSkipped(frame)
-- which conflates the virtual axis (content-empty) and the disabled axis
-- (off-spec / plugin off) into a single flag. The Selection module reads
-- frame.orbitDisabled to decide whether to render the edit-mode selection
-- highlight — virtual-flagged frames get hidden from selection, which would
-- pin empty Tracked containers as un-clickable in edit mode.
--
-- We override the flag to reflect ONLY the disabled axis, so virtual-but-
-- on-spec frames stay selectable. Disabled frames (off-spec, plugin off)
-- still get the flag because IsDisabled returns true for them.
function Plugin:_SyncOrbitDisabledFlag(frame)
    frame.orbitDisabled = Orbit.Engine.AnchorGraph:IsDisabled(frame)
end

-- [ VIRTUAL STATE ] -----------------------------------------------------------
-- An empty tracked container (no grid items / no spell) must not be a valid
-- anchor TARGET. If FrameA > TrackedIcons (empty) > FrameC, FrameC needs to
-- promote up to FrameA so it doesn't end up anchored to a frame with no
-- content. We mark empty frames "virtual" in the AnchorGraph; ReconcileChain
-- treats virtual frames the same as disabled ones — promotes their children to
-- the nearest non-skipped ancestor and snaps them back when the frame becomes
-- non-virtual again.
--
-- BUT: the empty frame must still be selectable/movable in edit mode so the
-- user can position it BEFORE adding content. Three things are needed:
--   (1) Position: SetFrameVirtual(true) parks the frame at defaultPosition.
--       We immediately call RestorePosition to put it back at its saved
--       Anchor/Position. The graph keeps the skip flag (children still
--       promote past), but the frame's physical SetPoint is restored.
--   (2) Selection visibility: SetFrameVirtual sets frame.orbitDisabled = true,
--       which the Selection module uses to hide the edit-mode highlight.
--       _SyncOrbitDisabledFlag overrides it to reflect only the disabled
--       axis so the frame stays clickable.
--   (3) No-snap as CHILD: an empty container must also not become an anchored
--       child of another frame (the user can drag it, but it shouldn't snap
--       and create an anchor — just freeposition it). frame.orbitNoSnap = true
--       puts the Drag module into precision-mode for this frame (Drag.lua:143
--       skips snap detection, Drag.lua:344 saves a raw point/x/y instead of
--       creating an anchor). Cleared when the frame becomes non-empty so it
--       can re-join the chain.
--
-- Hooked into Container:Apply and Bar:Apply (which both run on every content
-- mutation: drop, item removal, spell clear, spec swap). The plugin-level
-- _isVirtual guard avoids redundant SetFrameVirtual calls — important because
-- Apply runs on every settings change too, and SetFrameVirtual(true) re-parks
-- unconditionally per the engine's idempotency rule.
function Plugin:RefreshContainerVirtualState(frame)
    if not frame or not frame.recordId then return end
    local record = self:GetContainerRecord(frame.recordId)
    if not record then return end
    local isEmpty
    if record.mode == "icons" then
        isEmpty = not record.grid or next(record.grid) == nil
    else
        isEmpty = not record.payload or not record.payload.id
    end
    if frame._isVirtual == isEmpty then return end
    frame._isVirtual = isEmpty
    frame.orbitNoSnap = isEmpty
    Orbit.Engine.FrameAnchor:SetFrameVirtual(frame, isEmpty)
    self:_SyncOrbitDisabledFlag(frame)
    Orbit.Engine.Frame:RestorePosition(frame, self, frame.recordId)
end

-- [ FLUSH CURRENT SPEC ] ------------------------------------------------------
-- Walks the store and removes every record matching the current spec, tearing
-- down live frames as it goes. Used to recover from a desync where the store
-- holds dormant records the user can't see (e.g. records seeded by an earlier
-- dev iteration that never got built into frames). Records for OTHER specs are
-- left untouched. Returns the number of records removed.
function Plugin:FlushCurrentSpec()
    local specID = self:GetCurrentSpecID()
    if not specID then return 0 end
    local toRemove = {}
    for id, record in pairs(self:GetStore()) do
        if record.spec == specID then toRemove[#toRemove + 1] = id end
    end
    for _, id in ipairs(toRemove) do self:DeleteContainer(id) end
    Orbit:Print("Tracked: flushed " .. #toRemove .. " container(s) for spec " .. specID)
    return #toRemove
end

-- [ CONTAINER DELETION ] ------------------------------------------------------
-- Detach physical and logical descendants before tearing down the frame.
-- Frames in WoW can't be destroyed (Lua reference + name persist), so without
-- this cleanup any frame that was anchored to (or logically routed past) the
-- deleted Tracked container would still resolve `_G[oldName]` on the next
-- /reload and re-attach to a hidden, no-longer-in-store ghost frame.
--
-- Physical children: BreakAnchor removes the graph entry and clears their
-- logical anchor. We then wipe their saved `Anchor` setting so /reload doesn't
-- replay the broken reference. Both the global plugin setting AND the current
-- spec's spec-data slot need to be checked, because Tracked containers carry
-- `orbitAnchorTargetPerSpec` and may have routed the consumer's saved anchor
-- to either store. Only clear an entry if its `target` actually names the
-- deleted frame — a child may have been re-anchored elsewhere since the live
-- graph entry was made, and we don't want to nuke an unrelated anchor.
--
-- Logical children: frames whose logical parent was this container but who are
-- currently physically routed past it (because the container was virtual).
-- Their physical anchor is fine; we only need to drop the dangling logical
-- intent so RestoreLogicalChildren never tries to pull them home.
local function ClearChildSavedAnchorIfTargets(child, deletedName)
    local p = child.orbitPlugin
    if not p or not child.systemIndex or not deletedName then return end
    if p.GetSpecData and p.SetSpecData then
        local sa = p:GetSpecData(child.systemIndex, "Anchor")
        if sa and sa.target == deletedName then
            p:SetSpecData(child.systemIndex, "Anchor", nil)
        end
    end
    if p.GetSetting and p.SetSetting then
        local ga = p:GetSetting(child.systemIndex, "Anchor")
        if ga and ga.target == deletedName then
            p:SetSetting(child.systemIndex, "Anchor", nil)
        end
    end
end

function Plugin:DeleteContainer(id)
    local record = self:GetStore()[id]
    if not record then return end
    local frame = self.containers[id]
    if frame then
        local deletedName = frame:GetName()
        local Anchor = Orbit.Engine.FrameAnchor
        if Anchor then
            for _, child in ipairs(Anchor:GetAnchoredChildren(frame)) do
                Anchor:BreakAnchor(child, true)
                ClearChildSavedAnchorIfTargets(child, deletedName)
            end
            for _, lchild in ipairs(Anchor:GetLogicalChildren(frame)) do
                Anchor:ClearLogicalAnchor(lchild)
                ClearChildSavedAnchorIfTargets(lchild, deletedName)
            end
            Anchor:BreakAnchor(frame, true)
        end
        frame:Hide()
        self.containers[id] = nil
    end
    self:GetStore()[id] = nil
end

-- [ SPEC REFRESH ] ------------------------------------------------------------
-- Old behavior tore down frames whose record didn't match the current spec and
-- rebuilt them on swap-back. That severed any anchor chain that ran THROUGH a
-- tracked frame: a child of the destroyed frame got orphaned at its old
-- position and never re-attached when the frame came back, because the
-- AnchorGraph entry for the destroyed frame was gone too.
--
-- New behavior keeps a live frame in the graph for every record across all
-- specs and uses Anchor:SetFrameDisabled to flip off-spec frames into the
-- "skipped" state. Skipped frames stay in the graph as routing nodes:
-- ReconcileChain promotes their children to the nearest non-skipped ancestor
-- (e.g. FrameA > TrackedIcon > FrameC collapses to FrameA > FrameC when the
-- TrackedIcon's spec doesn't match), and snaps them back when the swap brings
-- the frame home (RestoreLogicalChildren walks the original logical anchor).
function Plugin:RefreshForCurrentSpec()
    local specID = self:GetCurrentSpecID()
    if not specID then return end

    -- Build a live frame for any record that doesn't have one yet. This is
    -- the first-load path AND the path for records discovered mid-session
    -- (e.g. created on another character with a shared profile).
    for _, record in pairs(self:GetStore()) do
        if not self.containers[record.id] then
            self:BuildContainer(record)
        end
    end

    -- Two-pass toggle: disable off-spec frames FIRST, then enable on-spec
    -- frames. Without the split there's a window where two frames at the
    -- "same logical slot" (one per spec) are both live anchor targets — any
    -- intermediate ReconcileChain or saved-anchor lookup that runs in that
    -- window could route a child to the wrong target. Records whose store
    -- entry vanished are torn down in the first pass too (treated like
    -- disabled-and-then-removed).
    for id, frame in pairs(self.containers) do
        local record = self:GetStore()[id]
        if not record then
            if Orbit.Engine.FrameAnchor then
                Orbit.Engine.FrameAnchor:BreakAnchor(frame, true)
            end
            frame:Hide()
            self.containers[id] = nil
        elseif record.spec ~= specID then
            self:SetContainerActive(frame, false)
        end
    end
    for id, frame in pairs(self.containers) do
        local record = self:GetStore()[id]
        if record and record.spec == specID then
            self:SetContainerActive(frame, true)
        end
    end
end

-- [ TALENT REFRESH ] ----------------------------------------------------------
-- Talents can change a spell's maxCharges and the active override target, but
-- the bar payload caches maxCharges plus the tooltip-parsed durations at drop
-- time so DetermineMode and the charges-mode layout never see the new values.
-- Walks every bar record, rebuilds the payload via BuildTrackedBarPayload
-- (which re-resolves GetActiveSpellID and re-parses the tooltip), then re-
-- applies the bar so dividers, SetMinMaxValues, and the recharge segment width
-- pick up the new max. Items are refreshed too — cheap and consistent — even
-- though their durations don't depend on talents. Bars without a payload are
-- skipped (nothing to refresh). Icon containers don't cache maxCharges so they
-- don't need this pass.
--
-- TRAIT_CONFIG_UPDATED can fire several times per talent commit, so the public
-- entry point is debounced via _ScheduleBarPayloadRefresh — same pattern as
-- MetaTalents/ApplyBuild's state watcher.
function Plugin:_ScheduleBarPayloadRefresh()
    if self._talentRefreshPending then return end
    self._talentRefreshPending = true
    C_Timer.After(TALENT_REFRESH_DEBOUNCE, function()
        self._talentRefreshPending = false
        self:RefreshBarPayloads()
    end)
end

function Plugin:RefreshBarPayloads()
    for _, record in pairs(self:GetStore()) do
        if record.mode == "bar" and record.payload and record.payload.id then
            local newPayload = DragDrop:BuildTrackedBarPayload(record.payload.type, record.payload.id)
            if newPayload then
                record.payload = newPayload
                local frame = self.containers[record.id]
                if frame and Orbit.TrackedBar then
                    Orbit.TrackedBar:Apply(self, frame, record)
                end
            end
        end
    end
end

function Plugin:GetFrameBySystemIndex(systemIndex)
    return self.containers[systemIndex]
end

-- [ APPLY SETTINGS ] ----------------------------------------------------------
-- Dispatch to the per-mode renderer. Each mode is independently responsible for
-- its own apply path; this plugin just routes by record.mode. The settings
-- dialog passes a wrapper object ({systemFrame, systemIndex, system}) instead
-- of the live container frame, so we always resolve via GetFrameBySystemIndex.
function Plugin:ApplySettings(frame)
    if not frame then
        for _, f in pairs(self.containers) do self:ApplySettings(f) end
        return
    end
    local resolved = self:GetFrameBySystemIndex(frame.systemIndex)
    if resolved then frame = resolved end
    if not frame or not frame.systemIndex then return end

    local record = self:GetContainerRecord(frame.systemIndex)
    if not record then return end
    if record.mode == "icons" and Orbit.TrackedContainer then
        Orbit.TrackedContainer:Apply(self, frame, record)
    elseif record.mode == "bar" and Orbit.TrackedBar then
        Orbit.TrackedBar:Apply(self, frame, record)
    end
end
