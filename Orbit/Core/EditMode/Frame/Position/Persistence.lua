-- [ ORBIT FRAME PERSISTENCE ]------------------------------------------------------------------------
-- Handles saving and restoring frame positions and anchors

local _, Orbit = ...
local Engine = Orbit.Engine

---@class OrbitFramePersistence
Engine.FramePersistence = {}
local Persistence = Engine.FramePersistence

-- [ PENDING ANCHOR QUEUE ] --------------------------------------------------------------------------
-- Stash anchors whose target doesn't exist yet; drained when the target registers via AttachSettingsListener.
Persistence.pendingByTarget = Persistence.pendingByTarget or {}

function Persistence:QueuePendingAnchor(childFrame, targetName, edge, padding, align)
    if not childFrame or not targetName then return end
    local bucket = self.pendingByTarget[targetName]
    if not bucket then
        bucket = {}
        self.pendingByTarget[targetName] = bucket
    end
    bucket[#bucket + 1] = {
        child = childFrame,
        edge = edge,
        padding = padding or 0,
        align = align,
    }
end

function Persistence:DrainPendingFor(targetName)
    if not targetName then return end
    local bucket = self.pendingByTarget[targetName]
    if not bucket then return end
    self.pendingByTarget[targetName] = nil
    local targetFrame = _G[targetName]
    if not targetFrame then return end
    for _, entry in ipairs(bucket) do
        if entry.child then
            Engine.FrameAnchor:CreateAnchor(entry.child, targetFrame, entry.edge, entry.padding, nil, entry.align, true)
        end
    end
end

function Persistence:DrainAllPending()
    local names = {}
    for targetName in pairs(self.pendingByTarget) do
        names[#names + 1] = targetName
    end
    for _, targetName in ipairs(names) do
        self:DrainPendingFor(targetName)
    end
end

-- [ SPEC-SCOPED STORAGE HELPERS ]--------------------------------------------------------------------
-- Spec-scoped plugins use SetSpecData; settingsArePerSpec plugins skip spec routing entirely.
local function HasGetSpecData(plugin)
    if not plugin then return false end
    if plugin.settingsArePerSpec then return false end
    return plugin.GetSpecData and plugin.SetSpecData
end

local function IsBuiltinSpecScoped(plugin, systemIndex)
    return plugin.IsSpecScopedIndex and plugin:IsSpecScopedIndex(systemIndex)
end

-- Only clear existing spec-data slots to avoid creating empty {} entries.
local function ClearSpecDataIfPresent(plugin, systemIndex, key)
    if plugin:GetSpecData(systemIndex, key) ~= nil then
        plugin:SetSpecData(systemIndex, key, nil)
    end
end

function Persistence:WriteAnchor(plugin, systemIndex, anchor)
    if not plugin or not systemIndex or not anchor then return end
    local useSpec = HasGetSpecData(plugin) and IsBuiltinSpecScoped(plugin, systemIndex)
    if useSpec then
        plugin:SetSpecData(systemIndex, "Anchor", anchor)
        plugin:SetSpecData(systemIndex, "Position", nil)
        return
    end
    if plugin.SetSetting then
        plugin:SetSetting(systemIndex, "Anchor", anchor)
        plugin:SetSetting(systemIndex, "Position", nil)
    end
    if HasGetSpecData(plugin) then
        ClearSpecDataIfPresent(plugin, systemIndex, "Anchor")
        ClearSpecDataIfPresent(plugin, systemIndex, "Position")
    end
end

function Persistence:WritePosition(plugin, systemIndex, pos)
    if not plugin or not systemIndex or not pos then return end
    local useSpec = HasGetSpecData(plugin) and IsBuiltinSpecScoped(plugin, systemIndex)
    if useSpec then
        plugin:SetSpecData(systemIndex, "Position", pos)
        plugin:SetSpecData(systemIndex, "Anchor", false)
        return
    end
    if plugin.SetSetting then
        plugin:SetSetting(systemIndex, "Position", pos)
        plugin:SetSetting(systemIndex, "Anchor", false)
    end
    if HasGetSpecData(plugin) then
        ClearSpecDataIfPresent(plugin, systemIndex, "Position")
        ClearSpecDataIfPresent(plugin, systemIndex, "Anchor")
    end
end

-- nil = no spec override (fall back to global); false = spec uses Position instead of Anchor.
function Persistence:ReadAnchor(plugin, systemIndex)
    if not plugin or not systemIndex then return nil end
    if HasGetSpecData(plugin) then
        local v = plugin:GetSpecData(systemIndex, "Anchor")
        if v ~= nil then return v end
    end
    if plugin.GetSetting then
        return plugin:GetSetting(systemIndex, "Anchor")
    end
    return nil
end

function Persistence:ReadPosition(plugin, systemIndex)
    if not plugin or not systemIndex then return nil end
    if HasGetSpecData(plugin) then
        local v = plugin:GetSpecData(systemIndex, "Position")
        if v ~= nil then return v end
    end
    if plugin.GetSetting then
        return plugin:GetSetting(systemIndex, "Position")
    end
    return nil
end

-- Restore frame position or anchor from plugin settings
function Persistence:RestorePosition(frame, plugin, systemIndex)
    if not frame or not plugin then
        return false
    end

    -- Safety: Do not restore position while user is actively dragging the frame.
    if frame.orbitIsDragging then
        return false
    end

    -- Safety: Do not attempt to move protected frames during combat
    if InCombatLockdown() and frame:IsProtected() then
        return false
    end

    systemIndex = systemIndex or 1

    -- If the saved anchor target is currently virtualized/disabled, physically
    -- route through the nearest non-skipped ancestor so the child appears at
    -- the ancestor's edge instead of following the parked target off-screen.
    -- Logical intent is preserved on `targetFrame` so RestoreLogicalChildren
    -- pulls the child home when the target becomes visible again. Returns
    -- true only if CreateAnchor actually succeeds — if no non-skipped ancestor
    -- exists, or if IsEdgeOccupied/cycle check blocks the attach, returns
    -- false so the caller falls through to Position/defaultPosition. Logical
    -- intent is set unconditionally so the child returns home later.
    local function RouteAroundSkipped(targetFrame, edge, padding, align)
        Engine.FrameAnchor:SetLogicalAnchor(frame, targetFrame, edge, padding, nil, align)
        local ancestor = Engine.FrameAnchor:GetAnchorParent(targetFrame)
        while ancestor and Engine.AnchorGraph:IsSkipped(ancestor) do
            ancestor = Engine.FrameAnchor:GetAnchorParent(ancestor)
        end
        if not ancestor then return false end
        return Engine.FrameAnchor:CreateAnchor(frame, ancestor, edge, padding, nil, align, true, true)
    end

    -- Try to restore ephemeral state first (Edit Mode Dirty State)
    if Engine.PositionManager then
        local anchor = Engine.PositionManager:GetAnchor(frame)
        if anchor and anchor.target then
            local targetFrame = _G[anchor.target]
            if targetFrame then
                local padding = anchor.padding or 0
                if Engine.AnchorGraph:IsSkipped(targetFrame) then
                    if RouteAroundSkipped(targetFrame, anchor.edge, padding, anchor.align) then
                        return true
                    end
                else
                    Engine.FrameAnchor:CreateAnchor(frame, targetFrame, anchor.edge, padding, nil, anchor.align, true)
                    return true
                end
            end
        end

        local pos = Engine.PositionManager:GetPosition(frame)
        if pos and pos.point then
            local x, y = pos.x, pos.y
            if Engine.Pixel then
                x, y = Engine.Pixel:SnapPosition(x, y, pos.point, frame:GetWidth(), frame:GetHeight(), frame:GetEffectiveScale())
            end
            frame:ClearAllPoints()
            frame:SetPoint(pos.point, x, y)
            return true
        end
    end

    -- Try to restore SavedVariables Anchor first. ReadAnchor checks the
    -- current spec's per-spec store before falling back to the global plugin
    -- setting, so plugins whose target is per-spec (Tracked containers) load
    -- the right anchor for the current spec.
    local anchor = self:ReadAnchor(plugin, systemIndex)
    if anchor and anchor.target then
        local targetFrame = _G[anchor.target]
        if targetFrame then
            local padding = anchor.padding or 0
            if Engine.AnchorGraph:IsSkipped(targetFrame) then
                if RouteAroundSkipped(targetFrame, anchor.edge, padding, anchor.align) then
                    return true
                end
                -- RouteAroundSkipped set logical anchor but couldn't create physical
                -- anchor (no non-skipped ancestor). If DrainPendingFor already wired a
                -- valid physical anchor to this target, preserve it — falling through
                -- to Position/defaultPosition would break the anchor that DrainPending
                -- established during the cross-plugin load-order race.
                local existingAnchor = Engine.FrameAnchor.anchors[frame]
                if existingAnchor and existingAnchor.parent == targetFrame then
                    return true
                end
                -- Fall through: no non-skipped ancestor and no existing anchor
            else
                Engine.FrameAnchor:CreateAnchor(frame, targetFrame, anchor.edge, padding, nil, anchor.align, true)
                return true
            end
        else
            -- Target plugin hasn't loaded yet. Stash the intent so DrainPendingFor
            -- can wire it up the moment the target frame registers.
            self:QueuePendingAnchor(frame, anchor.target, anchor.edge, anchor.padding or 0, anchor.align)
        end
    end

    -- Restore Position (also spec-data-aware via ReadPosition)
    local pos = self:ReadPosition(plugin, systemIndex)
    if pos and pos.point then
        if Engine.FrameAnchor and Engine.FrameAnchor:GetAnchorParent(frame) then
            Engine.FrameAnchor:BreakAnchor(frame, true)
        end
        local x, y = pos.x, pos.y
        if Engine.Pixel then
            x, y = Engine.Pixel:SnapPosition(x, y, pos.point, frame:GetWidth(), frame:GetHeight(), frame:GetEffectiveScale())
        end
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, x, y)
        return true
    end

    -- Fallback: Reset to Default Position
    if frame.defaultPosition then
        -- Break any stale physical anchor before parking. Reaching this
        -- branch means no saved position/anchor wired up, so any leftover
        -- graph entry (e.g. from a prior spec) would lie about where the
        -- frame is and mislead a subsequent ReconcileChain into promoting
        -- children of a frame that is visually parked off-screen.
        if Engine.FrameAnchor and Engine.FrameAnchor:GetAnchorParent(frame) then
            Engine.FrameAnchor:BreakAnchor(frame, true)
        end
        local x = frame.defaultPosition.x
        local y = frame.defaultPosition.y
        if Engine.Pixel then
            x, y = Engine.Pixel:SnapPosition(x, y, frame.defaultPosition.point, frame:GetWidth(), frame:GetHeight(), frame:GetEffectiveScale())
        end

        frame:ClearAllPoints()
        frame:SetPoint(frame.defaultPosition.point, frame.defaultPosition.relativeTo, frame.defaultPosition.relativePoint, x, y)
        return true
    end

    return false
end

-- [ ATTACHED FRAME REGISTRY ] -----------------------------------------------------------------------
-- Weak-keyed registry of frames for spec-change re-restore.
Persistence._attachedFrames = Persistence._attachedFrames or setmetatable({}, { __mode = "k" })

-- Attach listener for standard Orbit position/anchor saving
function Persistence:AttachSettingsListener(frame, plugin, systemIndex)
    if not frame or not plugin then
        return
    end
    systemIndex = systemIndex or 1

    -- Ensure the frame identifies its system for plugin lookup
    if not frame.system then
        frame.system = plugin.system or plugin.name
    end

    -- Ensure PositionManager has access to the plugin for saving
    -- (Fixes data loss for frames created manually without FrameFactory)
    frame.orbitPlugin = plugin
    frame.systemIndex = systemIndex

    self._attachedFrames[frame] = { plugin = plugin, systemIndex = systemIndex }

    -- Eager anchor seeding: if any child was waiting on this frame's name, wire it now.
    local frameName = frame:GetName()
    if frameName then
        self:DrainPendingFor(frameName)
    end

    -- Shared logic to refresh dialog (Trailing Debounce)
    local refreshTimer
    local function RefreshDialog()
        -- Reset timer on every call (Trailing Debounce)
        -- We only update the dialog when the user STOPS moving/nudging for 0.2s
        if refreshTimer then
            refreshTimer:Cancel()
        end

        refreshTimer = C_Timer.NewTimer(0.2, function()
            refreshTimer = nil
            -- Use Orbit's own settings dialog instead of Blizzard's
            if Orbit.SettingsDialog and Orbit.SettingsDialog:IsShown() then
                -- Only refresh if this frame is currently selected
                if Engine.FrameSelection:GetSelectedFrame() == frame then
                    local context = {
                        system = plugin.name or frame.orbitName,
                        systemIndex = systemIndex,
                        systemFrame = frame,
                    }
                    if plugin.system then
                        context.system = plugin.system
                    end
                    Orbit.SettingsDialog:UpdateDialog(context)
                end
            end
        end)
    end

    Engine.FrameSelection:Attach(frame, function(f, point, x, y)
        if Engine.PositionManager then
            if point == "ANCHORED" then
                -- Retrieve padding/align from anchor to pass to PositionManager
                local padding = 0
                local align = nil
                local fallback = nil
                if Engine.FrameAnchor then
                    if Engine.FrameAnchor.anchors[f] then
                        padding = Engine.FrameAnchor.anchors[f].padding or 0
                        align = Engine.FrameAnchor.anchors[f].align
                    end
                    local targetFrame = type(x) == "table" and x or _G[x]
                    if targetFrame then
                        local rootParent = targetFrame
                        if Engine.FrameAnchor.GetRootParent then
                            rootParent = Engine.FrameAnchor:GetRootParent(targetFrame)
                        end
                        if rootParent and rootParent:GetName() then
                            fallback = rootParent:GetName()
                        end
                    end
                end
                Engine.PositionManager:SetAnchor(f, x, y, padding, align, fallback)
            else
                Engine.PositionManager:SetPosition(f, point, x, y)
            end
            Engine.PositionManager:MarkDirty(f)
            -- Immediate write for spec-scoped plugins. FlushToStorage runs on
            -- edit-mode close, but a /reload between drag-stop and flush would
            -- lose spec-scoped writes. Global writes are left to FlushToStorage.
            local p = f.orbitPlugin
            local sysIdx = f.systemIndex
            if p and sysIdx and HasGetSpecData(p) and IsBuiltinSpecScoped(p, sysIdx) then
                if point == "ANCHORED" then
                    local anch = Engine.PositionManager:GetAnchor(f)
                    if anch then Persistence:WriteAnchor(p, sysIdx, anch) end
                else
                    Persistence:WritePosition(p, sysIdx, { point = point, x = x, y = y })
                end
            end
        end

        -- Refresh settings (e.g. show/hide width/height sliders based on anchor)
        RefreshDialog()
    end, function(f, isGroupAdd)
        -- Selection callback: Open Orbit's settings dialog
        if Orbit.SettingsDialog then
            if isGroupAdd then
                Orbit.SettingsDialog:UpdateGroupDialog(plugin, Engine.FrameSelection:GetSelectedFrames())
                Orbit.SettingsDialog:Show()
                return
            end

            -- Deselect any native Blizzard frames first
            if EditModeManagerFrame then
                EditModeManagerFrame:ClearSelectedSystem()
            end

            local context = {
                system = plugin.name or frame.orbitName,
                systemIndex = systemIndex,
                systemFrame = f,
            }
            if plugin.system then
                context.system = plugin.system
            end

            -- Update and show Orbit's dialog
            Orbit.SettingsDialog:UpdateDialog(context)
            Orbit.SettingsDialog:Show()
            Orbit.SettingsDialog:PositionNearButton()
        end
    end)
end

-- [ SPEC-CHANGE RE-RESTORE ] ------------------------------------------------------------------------
-- Re-restore positions on spec swap for spec-data plugins; settingsArePerSpec plugins skipped.
-- Only re-restore frames whose plugin has OPTED IN to spec-scoped positions via
-- `IsSpecScopedIndex`. Plugins that merely inherit GetSpecData/SetSpecData from
-- PluginMixin (i.e. everyone) are not automatically eligible — walking every
-- attached frame on every spec change is the pattern that caused the group-join
-- stall. Subscribers that own their own positioning (e.g. GroupFrames' per-tier
-- storage) simply never opt in.
function Persistence:RestoreAffectedBySpecChange()
    for frame, info in pairs(self._attachedFrames) do
        if HasGetSpecData(info.plugin) and IsBuiltinSpecScoped(info.plugin, info.systemIndex) then
            self:RestorePosition(frame, info.plugin, info.systemIndex)
        end
    end
end

-- Safety net: drain all pending anchors after PLAYER_ENTERING_WORLD.
if Orbit.EventBus then
    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        Persistence:DrainAllPending()
    end)

    -- Two-frame defer so ReconcileChain and SetContainerActive settle before re-anchoring.
    Orbit.EventBus:On("PLAYER_SPECIALIZATION_CHANGED", function()
        C_Timer.After(0, function()
            C_Timer.After(0, function()
                Persistence:RestoreAffectedBySpecChange()
            end)
        end)
    end)
end
