-- [ ORBIT FRAME SYSTEM ]----------------------------------------------------------------------------
-- Main orchestrator for the frame management system
-- Delegates to specialized modules:
--   - FrameAnchor: Anchor relationships
--   - FrameSnap: Snap detection
--   - FrameSelection: Selection overlays and drag handling
--   - ComponentEdit: Component edit mode
--   - FramePersistence: Position/anchor saving
--   - FrameFactory: Frame creation helpers

local _, Orbit = ...
local Engine = Orbit.Engine

---@class OrbitFrameManager
Engine.Frame = {}
local Frame = Engine.Frame

-- [ MODULE REFERENCES ]-----------------------------------------------------------------------------
-- These are set after all modules load
local Anchor, Snap, Selection, CanvasMode, Persistence, Guard

local function EnsureModules()
    Anchor = Anchor or Engine.FrameAnchor
    Snap = Snap or Engine.FrameSnap
    Selection = Selection or Engine.FrameSelection
    CanvasMode = CanvasMode or Engine.CanvasMode
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
    return Snap:DetectSnap(frame, showGuides, targets, nil)
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

-- [ CANVAS MODE API ]-------------------------------------------------------------------------------

--- Enters canvas mode for a frame
---@param frame frame
function Frame:EnterCanvasMode(frame)
    EnsureModules()
    CanvasMode:Enter(frame, function(f)
        Selection:UpdateVisuals(f)
    end)
end

function Frame:ExitCanvasMode(frame)
    EnsureModules()
    CanvasMode:Exit(frame, function(f)
        Selection:UpdateVisuals(f)
    end)
end

function Frame:IsCanvasModeActive(frame)
    EnsureModules()
    return CanvasMode:IsActive(frame)
end

function Frame:ToggleCanvasMode(frame)
    EnsureModules()
    CanvasMode:Toggle(frame, function(f)
        Selection:UpdateVisuals(f)
    end)
end

-- Legacy aliases for compatibility
Frame.EnterComponentEdit = Frame.EnterCanvasMode
Frame.ExitComponentEdit = Frame.ExitCanvasMode
Frame.IsComponentEditActive = Frame.IsCanvasModeActive
Frame.ToggleComponentEdit = Frame.ToggleCanvasMode

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

-- [ ORIENTATION API ]-------------------------------------------------------------------------------

--- Get the current orientation of a frame based on screen position
---@param frame frame
---@return string orientation "LEFT", "RIGHT", "TOP", or "BOTTOM"
function Frame:GetOrientation(frame)
    EnsureModules()
    if Engine.FrameOrientation then
        return Engine.FrameOrientation:DetectOrientation(frame)
    end
    return "LEFT"
end

--- Register a callback for orientation changes during Edit Mode drag
---@param frame frame
---@param callback function Called with (orientation) when orientation changes
function Frame:RegisterOrientationCallback(frame, callback)
    EnsureModules()
    if Engine.FrameOrientation then
        Engine.FrameOrientation:RegisterCallback(frame, callback)
    end
end

--- Unregister orientation callback
---@param frame frame
function Frame:UnregisterOrientationCallback(frame)
    EnsureModules()
    if Engine.FrameOrientation then
        Engine.FrameOrientation:UnregisterCallback(frame)
    end
end

-- [ NATIVE FRAME INTEGRATION ]----------------------------------------------------------------------

-- Native frame visuals handled by CanvasMode if needed
function Frame:UpdateNativeFrameVisual(systemFrame)
    EnsureModules()
    if CanvasMode and CanvasMode.UpdateNativeFrameVisual then
        CanvasMode:UpdateNativeFrameVisual(systemFrame)
    end
end

-- [ CLICK-THROUGH ]---------------------------------------------------------------------------------
function Frame:DisableMouseRecursive(frame)
    if not frame then
        return
    end
    frame:EnableMouse(false)
    frame.orbitClickThrough = true
    for _, child in ipairs({ frame:GetChildren() }) do
        self:DisableMouseRecursive(child)
    end
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

    -- Initialize CanvasMode
    if Engine.CanvasMode then
        Engine.CanvasMode:Initialize()
    end
end

-- [ PROPERTY ALIASES ]------------------------------------------------------------------------------

-- Expose anchor/canvas tables through Frame module
setmetatable(Frame, {
    __index = function(t, k)
        if k == "anchors" then
            EnsureModules()
            return Anchor and Anchor.anchors or {}
        elseif k == "currentCanvasModeFrame" then
            EnsureModules()
            return CanvasMode and CanvasMode.currentFrame or nil
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
