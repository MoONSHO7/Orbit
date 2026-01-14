-- [ ORBIT FRAME SYSTEM ]----------------------------------------------------------------------------
-- Main orchestrator for the frame management system
-- Delegates to specialized modules:
--   - FrameAnchor: Anchor relationships
--   - FrameSnap: Snap detection
--   - FrameSelection: Selection overlays and drag handling
--   - FrameLock: Frame locking
--   - FramePersistence: Position/anchor saving
--   - FrameFactory: Frame creation helpers

local _, Orbit = ...
local Engine = Orbit.Engine

---@class OrbitFrameManager
Engine.Frame = {}
local Frame = Engine.Frame

-- [ MODULE REFERENCES ]-----------------------------------------------------------------------------
-- These are set after all modules load
local Anchor, Snap, Selection, Lock, Persistence, Guard

local function EnsureModules()
    Anchor = Anchor or Engine.FrameAnchor
    Snap = Snap or Engine.FrameSnap
    Selection = Selection or Engine.FrameSelection
    Lock = Lock or Engine.FrameLock
    Persistence = Persistence or Engine.FramePersistence
    Guard = Guard or Engine.FrameGuard
end

-- [ ANCHOR API ]------------------------------------------------------------------------------------

--- Creates an anchor between two frames
---@param child frame
---@param parent frame
---@param edge string
---@param padding number?
---@param syncOptions table?
---@return boolean success
function Frame:CreateAnchor(child, parent, edge, padding, syncOptions)
    EnsureModules()
    local success = Anchor:CreateAnchor(child, parent, edge, padding, syncOptions)
    if success then
        Selection:UpdateVisuals(child)
    end
    return success
end

function Frame:BreakAnchor(child)
    EnsureModules()
    local success = Anchor:BreakAnchor(child)
    if success then
        Selection:UpdateVisuals(child)
    end
    return success
end

function Frame:GetAnchorParent(child)
    EnsureModules()
    return Anchor:GetAnchorParent(child)
end

function Frame:GetRootParent(frame)
    EnsureModules()
    return Anchor:GetRootParent(frame)
end

function Frame:GetAnchoredChildren(parent)
    EnsureModules()
    return Anchor:GetAnchoredChildren(parent)
end

function Frame:SyncChildren(parent)
    EnsureModules()
    Anchor:SyncChildren(parent)
end

-- Returns "x" or "y" based on how a frame is anchored to its parent
-- Useful for determining orientation when a frame is anchored to another
function Frame:GetAnchorAxis(frame)
    if not frame or not frame.GetPoint then
        return nil
    end
    if not frame:GetPoint() then
        return nil
    end

    local point, relativeTo, relativePoint = frame:GetPoint()
    if not point or not relativePoint then
        return nil
    end

    -- Vertical Stack: TOP connecting to BOTTOM (or vice versa)
    if (point:find("TOP") and relativePoint:find("BOTTOM")) or (point:find("BOTTOM") and relativePoint:find("TOP")) then
        return "y"
    end

    return "x"
end

-- [ SNAP API ]--------------------------------------------------------------------------------------

--- Attempts to snap a frame to nearby guides
---@param frame frame
---@param showGuides boolean?
---@return boolean snapped
function Frame:Snap(frame, showGuides)
    EnsureModules()
    local targets = Selection:GetSnapTargets(frame)
    return Snap:DetectSnap(frame, showGuides, targets, function(f)
        return Lock:IsLocked(f)
    end)
end

-- [ SELECTION API ]---------------------------------------------------------------------------------

-- Expose selections table for compatibility
Frame.selections = {}

function Frame:Attach(frame, dragCallback, selectionCallback)
    EnsureModules()
    Selection:Attach(frame, dragCallback, selectionCallback)
    -- Keep local reference updated
    Frame.selections = Selection.selections
end

function Frame:DeselectAll()
    EnsureModules()
    Selection:DeselectAll()
end

function Frame:ForceUpdateSelection(frame)
    EnsureModules()
    Selection:ForceUpdate(frame)
end

function Frame:UpdateSelectionVisuals(frame, selection)
    EnsureModules()
    Selection:UpdateVisuals(frame, selection)
end

function Frame:OnEditModeEnter()
    EnsureModules()
    Selection:OnEditModeEnter()
end

function Frame:OnEditModeExit()
    EnsureModules()
    Selection:OnEditModeExit()
end

function Frame:NudgeFrame(frame, direction)
    EnsureModules()
    return Selection:NudgeFrame(frame, direction)
end

function Frame:GetSelectedFrame()
    EnsureModules()
    return Selection:GetSelectedFrame()
end

-- [ LOCK API ]--------------------------------------------------------------------------------------

--- Locks a frame in place
---@param frame frame
function Frame:LockFrame(frame)
    EnsureModules()
    Lock:LockFrame(frame, function(f)
        Selection:UpdateVisuals(f)
    end)
end

function Frame:UnlockFrame(frame)
    EnsureModules()
    Lock:UnlockFrame(frame, function(f)
        Selection:UpdateVisuals(f)
    end)
end

function Frame:IsLocked(frame)
    EnsureModules()
    return Lock:IsLocked(frame)
end

function Frame:ToggleLock(frame)
    EnsureModules()
    Lock:ToggleLock(frame, function(f)
        Selection:UpdateVisuals(f)
    end)
end

function Frame:RestoreLocks()
    EnsureModules()
    Lock:RestoreLocks(Selection.selections, function(f)
        Selection:UpdateVisuals(f)
    end, function(f)
        Lock:UpdateNativeFrameVisual(f)
    end)
end

-- [ PERSISTENCE API ]-------------------------------------------------------------------------------

function Frame:RestorePosition(frame, plugin, systemIndex)
    EnsureModules()
    return Persistence:RestorePosition(frame, plugin, systemIndex)
end

-- [ GUARD API ]-------------------------------------------------------------------------------------

function Frame:Protect(frame, parent, onRestoreFunc, options)
    EnsureModules()
    Guard:Protect(frame, parent)
    Guard:UpdateProtection(frame, parent, onRestoreFunc, options)
end

function Frame:AttachSettingsListener(frame, plugin, systemIndex)
    EnsureModules()
    Persistence:AttachSettingsListener(frame, plugin, systemIndex)
end

-- [ NATIVE FRAME INTEGRATION ]----------------------------------------------------------------------

-- Delegate native frame methods to FrameLock
function Frame:HookNativeFrames()
    EnsureModules()
    Lock:HookNativeFrames()
end

function Frame:UpdateNativeFrameVisual(systemFrame)
    EnsureModules()
    Lock:UpdateNativeFrameVisual(systemFrame)
end

-- [ INITIALIZATION ]--------------------------------------------------------------------------------

-- Hook Edit Mode to integrate modules
if EditModeManagerFrame then
    hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
        if Engine.FrameSelection then
            Engine.FrameSelection:DeselectAll()
        end
    end)

    hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
        if Engine.FrameSelection and not Engine.FrameSelection.isClearingNativeSelection then
            local foci = GetMouseFoci and GetMouseFoci() or {}
            for _, focus in ipairs(foci) do
                if focus and focus.isOrbitSelection then
                    return
                end
            end

            Engine.FrameSelection:DeselectAll()
        end
    end)

    -- Initialize FrameLock
    if Engine.FrameLock then
        Engine.FrameLock:Initialize()
    end

    -- Restore locks when Edit Mode opens
    EditModeManagerFrame:HookScript("OnShow", function()
        if Engine.FrameLock and Engine.FrameSelection then
            Engine.FrameLock:RestoreLocks(Engine.FrameSelection.selections, function(f)
                Engine.FrameSelection:UpdateVisuals(f)
            end, function(f)
                Engine.FrameLock:UpdateNativeFrameVisual(f)
            end)
        end
    end)
end

-- [ PROPERTY ALIASES ]------------------------------------------------------------------------------

-- Expose anchor/lock tables through Frame module
setmetatable(Frame, {
    __index = function(t, k)
        if k == "anchors" then
            EnsureModules()
            return Anchor and Anchor.anchors or {}
        elseif k == "locks" then
            EnsureModules()
            return Lock and Lock.locks or {}
        elseif k == "nativePositions" then
            EnsureModules()
            return Lock and Lock.nativePositions or {}
        elseif k == "dragCallbacks" then
            EnsureModules()
            return Selection and Selection.dragCallbacks or {}
        elseif k == "selectionCallbacks" then
            EnsureModules()
            return Selection and Selection.selectionCallbacks or {}
        end
        return rawget(t, k)
    end,
})
