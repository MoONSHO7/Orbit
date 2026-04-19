-- [ ORBIT TRACKED PLUGIN ] --------------------------------------------------------------------------
-- User-authored cooldown containers (icon grids + bars) as flat records in GlobalSettings.TrackedContainers.
local _, Orbit = ...

local Constants = Orbit.Constants
local DragDrop = Orbit.CooldownDragDrop

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local MAX_ICON_CONTAINERS = Constants.Tracked.MaxIconContainers
local MAX_BARS = Constants.Tracked.MaxBars
local SYSTEM_ID_BASE = Constants.Tracked.SystemIndexBase
local TAB_ATLAS = "communities-chat-icon-plus"
local TAB_ID_ICONS = "Orbit_Tracked.Icons"
local TAB_ID_BARS = "Orbit_Tracked.Bars"
-- Tab tints match empty-state dropzone colors (green = icons, yellow = bars).
local TAB_TINT_ICONS = { r = 0.40, g = 0.85, b = 0.40 }
local TAB_TINT_BARS = { r = 1.00, g = 0.82, b = 0.00 }
local DEFAULT_ICON_OFFSET_Y = 0
local DEFAULT_BAR_OFFSET_X = 250
local TALENT_REFRESH_DEBOUNCE = 0.1

-- [ PLUGIN REGISTRATION ] ---------------------------------------------------------------------------
-- settingsArePerSpec: records own their spec field, so Persistence's spec-data routing is skipped.
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
        Orbit.EventBus:On("ORBIT_PROFILE_CHANGED", function() self:RefreshForCurrentSpec() end, self)
        Orbit.EventBus:On("TRAIT_CONFIG_UPDATED", function() self:_ScheduleBarPayloadRefresh() end, self)
    end,
})
Plugin.canvasMode = true

-- [ STORE BOOTSTRAP ] -------------------------------------------------------------------------------
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

-- [ RECORD QUERIES ] --------------------------------------------------------------------------------
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

-- [ SETTINGS REDIRECT ] -----------------------------------------------------------------------------
-- Container records own settings inline; non-container keys fall through to standard layout DB.
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

-- [ COMPONENT DISABLED OVERRIDE ] -------------------------------------------------------------------
-- Reads DisabledComponents from the active Canvas Mode transaction's systemIndex, not self.frame.
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

-- [ GLOBAL FONT ] -----------------------------------------------------------------------------------
-- Returns the LSM-resolved path for GlobalSettings.Font.
function Plugin:GetGlobalFont()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    if fontName and LSM then
        return LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    end
    return STANDARD_TEXT_FONT
end

-- [ DROP HINT VISIBILITY ] --------------------------------------------------------------------------
-- Show drop hints when dragging or in edit-mode with an empty frame.
function Plugin:ShouldShowDropHints(isEmpty)
    if DragDrop and DragDrop:IsDraggingCooldownAbility() then return true end
    if isEmpty and Orbit:IsEditMode() then return true end
    return false
end

-- [ TAB REGISTRATION ] ------------------------------------------------------------------------------
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

-- [ CONTAINER CREATION ] ----------------------------------------------------------------------------
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

-- Builds a frame for the record across all specs; virtual state set before RestorePosition.
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

-- [ ENABLE / DISABLE ] ------------------------------------------------------------------------------
-- Toggles container via AnchorGraph skip mechanism; mirrors PlayerResources enable/disable pattern.
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

-- [ ORBIT-DISABLED FLAG SYNC ] ----------------------------------------------------------------------
-- Override orbitDisabled to reflect only the disabled axis, keeping virtual-but-on-spec frames selectable.
function Plugin:_SyncOrbitDisabledFlag(frame)
    frame.orbitDisabled = Orbit.Engine.AnchorGraph:IsDisabled(frame)
end

-- [ VIRTUAL STATE ] ---------------------------------------------------------------------------------
-- Empty containers are marked virtual (children promote past) but stay selectable and movable.
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

-- [ FLUSH CURRENT SPEC ] ----------------------------------------------------------------------------
-- Removes all records for the current spec; recovery tool for desync states.
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

-- [ CONTAINER DELETION ] ----------------------------------------------------------------------------
-- Detach physical and logical descendants and clear saved anchors before teardown.
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

-- [ SPEC REFRESH ] ----------------------------------------------------------------------------------
-- All-spec frames stay in the graph; off-spec frames are skipped so chains route past them.
function Plugin:RefreshForCurrentSpec()
    local specID = self:GetCurrentSpecID()
    if not specID then return end

    -- Build frames for any record not yet live (first-load and mid-session discovery).
    for _, record in pairs(self:GetStore()) do
        if not self.containers[record.id] then
            self:BuildContainer(record)
        end
    end

    -- Two-pass: disable off-spec first, then enable on-spec to avoid dual-live anchor races.
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

-- [ TALENT REFRESH ] --------------------------------------------------------------------------------
-- Rebuild bar payloads on talent change (maxCharges/overrides may shift); debounced.
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

-- [ APPLY SETTINGS ] --------------------------------------------------------------------------------
-- Dispatch to per-mode renderer; resolves wrapper objects via GetFrameBySystemIndex.
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
