-- [ ORBIT SELECTION - DRAG HANDLERS ] ---------------------------------------------------------------
-- Handles drag start, stop, mouse wheel padding, and mouse down selection

local _, Orbit = ...
local Engine = Orbit.Engine
local C = Orbit.Constants

local Drag = {}
Engine.SelectionDrag = Drag
Drag.isDragging = false

-- Suppress GameTooltip universally while ANY frame dragging is active
if GameTooltip then
    GameTooltip:HookScript("OnShow", function(self)
        if Drag.isDragging then
            self:Hide()
        end
    end)
end

local MAX_PADDING = 500
local SNAP_THROTTLE = 1 / 30
local OPPOSITE_EDGES = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }
local function GetOppositeEdge(edge)
    return OPPOSITE_EDGES[edge]
end

-- [ BLIZZARD EDIT MODE TAP-IN ] ---------------------------------------------------------------------
local function GetUIParentSpaceRatio(frame)
    local uiScale = UIParent:GetEffectiveScale()
    if uiScale == 0 then return 1 end
    return frame:GetEffectiveScale() / uiScale
end

local function OrbitGetScaledSelectionSides(self)
    local left, bottom, width, height = self:GetRect()
    if not left then return 0, 0, 0, 0 end
    local r = GetUIParentSpaceRatio(self)
    return left * r, (left + width) * r, bottom * r, (bottom + height) * r
end

local function OrbitGetScaledSelectionCenter(self)
    local cx, cy = self:GetCenter()
    if not cx then return 0, 0 end
    local r = GetUIParentSpaceRatio(self)
    return cx * r, cy * r
end

-- nil excludes from magnetic pool; UIParent is hardcoded by EditModeMagnetismManager so edges still render.
local function OrbitGetFrameMagneticEligibility(self, other)
    return nil, nil
end

local function InstallBlizzardMagnetismShims(frame)
    if frame.orbitMagnetismShimsInstalled then return end
    frame.orbitMagnetismShimsInstalled = true
    frame.GetScaledSelectionSides = OrbitGetScaledSelectionSides
    frame.GetScaledSelectionCenter = OrbitGetScaledSelectionCenter
    frame.GetFrameMagneticEligibility = OrbitGetFrameMagneticEligibility
end

local function ShouldUseBlizzardPreview(parent)
    if not EditModeManagerFrame or not EditModeManagerFrame.SetSnapPreviewFrame then return false end
    if not EditModeManagerFrame:IsShown() then return false end
    if parent.orbitNoSnap then return false end
    local anchoringEnabled = not Orbit.db or not Orbit.db.GlobalSettings or Orbit.db.GlobalSettings.AnchoringEnabled ~= false
    return anchoringEnabled
end

local function SetBlizzardSnapPreview(parent, active)
    if not EditModeManagerFrame or not EditModeManagerFrame.SetSnapPreviewFrame then return end
    if active then
        if not EditModeManagerFrame:IsShown() then return end
        InstallBlizzardMagnetismShims(parent)
        EditModeManagerFrame:SetSnapPreviewFrame(parent)
    else
        EditModeManagerFrame:ClearSnapPreviewFrame()
    end
end

-- [ PRECISION MODE (SHIFT-DRAG OVERLAY SUPPRESSION) ]------------------------------------------------
local function SetNonSelectedOverlaysVisible(selectionOverlay, visible)
    local Selection = Engine.FrameSelection
    for frame, sel in pairs(Selection.selections) do
        if sel ~= selectionOverlay then
            if visible then
                sel:SetAlpha(1)
                sel:EnableMouse(true)
            else
                sel:SetAlpha(0)
                sel:EnableMouse(false)
            end
        end
    end
    selectionOverlay.precisionMode = not visible
end

-- [ FRAME MOVE ]-------------------------------------------------------------------------------------
-- Manual mode (drag.manual) is the fallback when StartMoving fails to re-latch a follow point — UpdateMove then tracks the cursor by hand instead of via WoW's native move.
local function BeginMove(parent)
    local drag = parent._drag
    local preL, preB = parent:GetLeft(), parent:GetBottom()
    parent:StartMoving()
    drag.manual = nil
    if parent:GetNumPoints() > 0 then return end

    -- Clear WoW's internal "moving" flag — left set, it fights the manual SetPoints and the drag-stop StopMovingOrSizing strips the frame's point (lands at 0,0).
    parent:StopMovingOrSizing()

    local scale = parent:GetEffectiveScale()
    if not scale or scale < 0.01 then scale = 1 end
    preL, preB = preL or 0, preB or 0
    local cx, cy = GetCursorPosition()
    drag.manual = true
    drag.manualOffX = preL - cx / scale
    drag.manualOffY = preB - cy / scale
    -- Re-anchor immediately so the frame is never left point-less.
    parent:ClearAllPoints()
    parent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", preL, preB)
end

-- Per-frame cursor follow — a no-op unless BeginMove fell back to manual mode.
local function UpdateMove(parent)
    local drag = parent._drag
    if not (drag and drag.manual) or InCombatLockdown() then return end
    local scale = parent:GetEffectiveScale()
    if not scale or scale < 0.01 then scale = 1 end
    local cx, cy = GetCursorPosition()
    parent:ClearAllPoints()
    parent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
        cx / scale + drag.manualOffX, cy / scale + drag.manualOffY)
end

-- Ends the move: stops WoW's native move (harmless if it never engaged) and clears the mode.
local function EndMove(parent)
    parent:StopMovingOrSizing()
    parent._drag.manual = nil
end

-- [ DRAG UPDATE (VISUALS) ]--------------------------------------------------------------------------
local function OnDragUpdate(selectionOverlay, elapsed)
    local parent = selectionOverlay.parent
    local Selection = Engine.FrameSelection

    UpdateMove(parent)

    local shiftHeld = IsShiftKeyDown()
    if shiftHeld and not selectionOverlay.precisionMode then
        SetNonSelectedOverlaysVisible(selectionOverlay, false)
        SetBlizzardSnapPreview(parent, false)
    elseif not shiftHeld and selectionOverlay.precisionMode then
        SetNonSelectedOverlaysVisible(selectionOverlay, true)
        Selection:RefreshVisuals()
        if ShouldUseBlizzardPreview(parent) then
            SetBlizzardSnapPreview(parent, true)
        end
    end

    local anchoringEnabled = not Orbit.db or not Orbit.db.GlobalSettings or Orbit.db.GlobalSettings.AnchoringEnabled ~= false
    if not anchoringEnabled or parent.orbitNoSnap or shiftHeld then
        Engine.SelectionTooltip:ShowPosition(parent, Selection, true)
        return
    end

    -- Snap detection + anchor-line rendering is the expensive path; throttle it. Cursor-follow above stays every-frame.
    selectionOverlay.snapElapsed = (selectionOverlay.snapElapsed or 0) + (elapsed or 0)
    if selectionOverlay.snapElapsed < SNAP_THROTTLE then return end
    selectionOverlay.snapElapsed = 0

    local targets = parent._drag and parent._drag.snapTargets or Selection:GetSnapTargets(parent)
    local closestX, closestY, anchorTarget, anchorEdge, anchorAlign = Engine.FrameSnap:DetectSnap(parent, true, targets, nil)

    local isOrbitFrame = Selection.selections[anchorTarget] ~= nil
    local edgeAxis = anchorEdge and Engine.Axis.ForEdge(anchorEdge)
    local Anchor = Engine.FrameAnchor
    local crossAxis = edgeAxis and edgeAxis.perpendicular
    local rawIndependentCross = crossAxis and parent.anchorOptions and parent.anchorOptions[crossAxis.independentFlag]
    local parentSyncsCross = crossAxis and Engine.Axis.SyncEnabled(parent, crossAxis)
    local willSyncCross = edgeAxis and parentSyncsCross and not rawIndependentCross
    local lineAlign = willSyncCross and "CENTER" or anchorAlign

    if
        anchorTarget
        and anchorEdge
        and isOrbitFrame
        and (anchorTarget ~= selectionOverlay.lastAnchorTarget or lineAlign ~= selectionOverlay.lastAnchorAlign)
    then
        if selectionOverlay.lastAnchorTarget then
            local oldSel = Selection.selections[selectionOverlay.lastAnchorTarget]
            Engine.AnchorLines:Hide(oldSel)
        end
        Engine.AnchorLines:Hide(selectionOverlay)

        local targetSel = Selection.selections[anchorTarget]
        Engine.AnchorLines:ShowOn(targetSel, anchorEdge, lineAlign)
        Engine.AnchorLines:ShowOn(selectionOverlay, GetOppositeEdge(anchorEdge), lineAlign)

        selectionOverlay.lastAnchorTarget = anchorTarget
        selectionOverlay.lastAnchorAlign = lineAlign
    elseif not anchorTarget and selectionOverlay.lastAnchorTarget then
        local oldSel = Selection.selections[selectionOverlay.lastAnchorTarget]
        Engine.AnchorLines:Hide(oldSel)
        Engine.AnchorLines:Hide(selectionOverlay)
        selectionOverlay.lastAnchorTarget = nil
        selectionOverlay.lastAnchorAlign = nil
    end

    -- Orbit anchor line suppresses Blizzard's red snap preview so they don't compete visually; unconditional clear also covers the shift-release tick where precision-mode re-enabled preview above.
    local hasAnchorLine = selectionOverlay.lastAnchorTarget ~= nil
    if hasAnchorLine then
        SetBlizzardSnapPreview(parent, false)
        selectionOverlay.anchorSuppressedPreview = true
    elseif selectionOverlay.anchorSuppressedPreview then
        selectionOverlay.anchorSuppressedPreview = false
        if ShouldUseBlizzardPreview(parent) then
            SetBlizzardSnapPreview(parent, true)
        end
    end

    local anchorLabel = selectionOverlay.lastAnchorAlign and Engine.SelectionTooltip:BuildAnchorLabel(selectionOverlay.lastAnchorAlign) or nil
    Engine.SelectionTooltip:ShowPosition(parent, Selection, true, anchorLabel)
end

-- [ DRAG START (FUNCTION) ] -------------------------------------------------------------------------
function Drag:OnDragStart(selectionOverlay)
    if InCombatLockdown() then
        return
    end
    Drag.isDragging = true
    if GameTooltip then GameTooltip:Hide() end
    
    local parent = selectionOverlay.parent

    if Engine.CanvasMode:IsActive(parent) then
        return
    end

    if parent:IsMovable() and not parent.orbitNoDrag then
        parent.orbitIsDragging = true
        -- Transient drag state in one table, destroyed in OnDragStop; orbitIsDragging stays a separate flag external code reads.
        parent._drag = {}
        parent._drag.mergeSuspendGroup = Orbit.Skin:SuspendMergeGroup(parent)

        local anchor = Engine.FrameAnchor.anchors[parent]
        parent._drag.prevAnchor = anchor and { parent = anchor.parent, edge = anchor.edge, padding = anchor.padding } or nil
        if anchor then
            -- Capture visual center pre-break: BreakAnchor fires OnAnchorChanged which may resize (e.g. TrackedBar reverts to saved width); repositioning after break holds the center under the cursor.
            local preCX = (parent:GetLeft() + parent:GetRight()) / 2
            local preCY = (parent:GetBottom() + parent:GetTop()) / 2
            local oldParent = anchor.parent
            local oldAxis = Engine.Axis.ForEdge(anchor.edge)
            local root = oldAxis and oldParent and Engine.FrameAnchor:GetRootParent(oldParent) or nil

            Engine.FrameAnchor:BreakAnchor(parent, true, true)
            Orbit.EventBus:Fire("ORBIT_BORDER_LAYOUT_CHANGED")

            if root then
                Engine.FrameAnchor:SyncChildren(root)
            end

            -- Reanchor so visual center matches pre-break position
            local postW, postH = parent:GetWidth(), parent:GetHeight()
            parent:ClearAllPoints()
            local scale = parent:GetEffectiveScale()
            parent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Engine.Pixel:Snap(preCX - postW / 2, scale), Engine.Pixel:Snap(preCY - postH / 2, scale))
        end

        -- Pre-drag snapshot — OnDragStop restores this if the drop can't otherwise resolve a point, instead of dumping the frame to screen origin.
        local rPoint, _, _, rX, rY = parent:GetPoint(1)
        parent._drag.restorePoint = rPoint and { point = rPoint, x = rX, y = rY } or nil

        BeginMove(parent)

        if parent.orbitAutoOrient and Engine.FrameOrientation then
            Engine.FrameOrientation:StartTracking(parent)
        end

        -- Snap-target membership doesn't change during a single drag; cache it so OnDragUpdate doesn't rebuild the list every frame.
        parent._drag.snapTargets = Engine.FrameSelection:GetSnapTargets(parent)

        selectionOverlay.lastAnchorTarget = nil
        selectionOverlay.lastAnchorAlign = nil
        selectionOverlay.precisionMode = false
        selectionOverlay.anchorSuppressedPreview = false
        selectionOverlay.snapElapsed = 0

        if IsShiftKeyDown() then
            SetNonSelectedOverlaysVisible(selectionOverlay, false)
        elseif ShouldUseBlizzardPreview(parent) then
            SetBlizzardSnapPreview(parent, true)
        end

        selectionOverlay:SetScript("OnUpdate", OnDragUpdate)
    end
end

-- [ DRAG STOP ]--------------------------------------------------------------------------------------
-- Unconditional visual/state teardown — runs even when the position commit is blocked below.
local function TeardownDrag(selectionOverlay, parent)
    local drag = parent._drag

    -- Resumed before any combat/canvas early-return so combat starting mid-drag can't strand it.
    if drag.mergeSuspendGroup then
        Orbit.Skin:ResumeMergeGroup(drag.mergeSuspendGroup)
        drag.mergeSuspendGroup = nil
    end

    local Selection = Engine.FrameSelection
    if selectionOverlay.lastAnchorTarget then
        Engine.AnchorLines:Hide(Selection.selections[selectionOverlay.lastAnchorTarget])
        selectionOverlay.lastAnchorTarget = nil
        selectionOverlay.lastAnchorAlign = nil
    end
    Engine.AnchorLines:Hide(selectionOverlay)
    selectionOverlay:SetScript("OnUpdate", nil)
    SetBlizzardSnapPreview(parent, false)

    -- Paired with StartTracking in OnDragStart; teardown runs before any combat/canvas early-return so a combat-interrupted drag can't strand the orientation OnUpdate.
    if parent.orbitAutoOrient and Engine.FrameOrientation then
        Engine.FrameOrientation:StopTracking(parent)
    end

    if selectionOverlay.precisionMode then
        SetNonSelectedOverlaysVisible(selectionOverlay, true)
        Selection:RefreshVisuals()
    end
end

-- Read-only — partner re-anchoring is OnMouseWheel's responsibility, not the drop's.
local function SymmetricPartnerPadding(parent)
    local partnerName = Engine.FrameSelection:GetSymmetricPartner(parent:GetName())
    local partner = partnerName and _G[partnerName]
    local pAnchor = partner and Engine.FrameAnchor.anchors[partner]
    return pAnchor and (pAnchor.padding or 0) or nil
end

-- Falls back to the pre-drag snapshot so a transiently-unresolved drop never dumps the frame to screen origin.
local function FallbackPoint(parent, point, x, y)
    local s = parent._drag.restorePoint
    if point or not s then return point, x, y end
    return s.point, s.x, s.y
end

-- Detects snap, applies it to the frame (NormalizePosition below reads the snapped position), and returns a decision { kind = "anchor" | "free" | "precision", ... } for CommitDrop to apply.
local function ResolveDrop(parent)
    local Selection = Engine.FrameSelection

    if IsShiftKeyDown() or parent.orbitNoSnap then
        -- Precision mode: raw position, no snapping.
        local point, _, _, x, y = parent:GetPoint(1)
        point, x, y = FallbackPoint(parent, point, x, y)
        return { kind = "precision", point = point, x = x, y = y }
    end

    local targets = parent._drag and parent._drag.snapTargets or Selection:GetSnapTargets(parent)
    local closestX, closestY, anchorTarget, anchorEdge, anchorAlign = Engine.FrameSnap:DetectSnap(parent, false, targets, nil)
    Engine.FrameSnap:ApplySnap(parent, closestX, closestY)

    local anchoringEnabled = not Orbit.db or not Orbit.db.GlobalSettings or Orbit.db.GlobalSettings.AnchoringEnabled ~= false
    if anchorTarget and anchorEdge and anchoringEnabled and Selection.selections[anchorTarget] then
        -- Re-drop onto same target keeps user's existing gap; else inherit symmetric partner's gap; else CreateAnchor's default.
        local padding
        local prev = parent._drag.prevAnchor
        if prev and prev.parent == anchorTarget and prev.edge == anchorEdge then
            padding = prev.padding
        end
        if padding == nil then
            padding = SymmetricPartnerPadding(parent)
        end
        return { kind = "anchor", target = anchorTarget, edge = anchorEdge, align = anchorAlign, padding = padding }
    end

    local point, x, y = Engine.FrameSnap:NormalizePosition(parent)
    if not point then
        point, _, _, x, y = parent:GetPoint(1)
    end
    point, x, y = FallbackPoint(parent, point, x, y)
    return { kind = "free", point = point, x = x, y = y }
end

local function CommitDrop(parent, decision)
    local cb = Engine.FrameSelection.dragCallbacks[parent]

    if decision.kind == "anchor" then
        Engine.FrameAnchor:CreateAnchor(parent, decision.target, decision.edge, decision.padding, nil, decision.align)
        -- Ordering: anchor must exist before the event and the callback, both of which read FrameAnchor.anchors[parent].
        Orbit.EventBus:Fire("ORBIT_BORDER_LAYOUT_CHANGED")
        if cb then cb(parent, { kind = "anchor", target = decision.target, edge = decision.edge }) end
        return
    end

    if decision.kind == "precision" then
        parent:ClearAllPoints()
        parent:SetPoint(decision.point or "CENTER", decision.x or 0, decision.y or 0)
        if cb then cb(parent, { kind = "free", point = decision.point or "CENTER", x = decision.x or 0, y = decision.y or 0 }) end
        return
    end

    -- "free": SetPoint before ApplySettings — ApplySettings re-reads geometry and must see the drop.
    if cb then cb(parent, { kind = "free", point = decision.point, x = decision.x, y = decision.y }) end
    parent:ClearAllPoints()
    parent:SetPoint(decision.point or "CENTER", decision.x or 0, decision.y or 0)
    if parent.orbitPlugin and parent.orbitPlugin.ApplySettings then
        parent.orbitPlugin:ApplySettings(parent)
    end
end

function Drag:OnDragStop(selectionOverlay)
    Drag.isDragging = false
    local parent = selectionOverlay.parent
    -- WoW fires OnDragStop for any drag gesture, so it can run without a matching OnDragStart — nil-safe defaulting.
    parent._drag = parent._drag or {}

    TeardownDrag(selectionOverlay, parent)
    -- End the move unconditionally — a combat-interrupted drag must not leave the frame latched.
    EndMove(parent)

    -- Combat and canvas mode block the position commit; the teardown above always runs.
    if InCombatLockdown() or Engine.CanvasMode:IsActive(parent) then
        parent.orbitIsDragging = nil
        parent._drag = nil
        return
    end

    -- Deliberately in the commit tier — don't detach the anchor unless the commit below can re-place it.
    Engine.FrameAnchor:BreakAnchor(parent, true)

    CommitDrop(parent, ResolveDrop(parent))

    local Selection = Engine.FrameSelection
    Selection:UpdateVisuals(parent)
    Engine.SelectionTooltip:ShowPosition(parent, Selection)
    if selectionOverlay.ShowTooltip then
        selectionOverlay:ShowTooltip()
    end

    parent.orbitIsDragging = nil
    parent._drag = nil
end

-- [ MOUSE DOWN (SELECTION) ]-------------------------------------------------------------------------
function Drag:OnMouseDown(selectionOverlay)
    if InCombatLockdown() then
        return
    end

    local Selection = Engine.FrameSelection
    local clickedFrame = selectionOverlay.parent

    -- Shift-click: add/remove from group selection if same plugin
    if IsShiftKeyDown() and Selection.selectedFrame then
        local existingPlugin = Selection.selectedFrame.orbitPlugin
        local clickedPlugin = clickedFrame.orbitPlugin
        if existingPlugin and clickedPlugin and existingPlugin == clickedPlugin
            and not clickedFrame.orbitNoGroupSelect
            and not Selection.selectedFrame.orbitNoGroupSelect then
            if selectionOverlay.isSelected then
                -- Deselect from group (only if more than 1 remain)
                local count = 0
                for _ in pairs(Selection.selectedFrames) do count = count + 1 end
                if count > 2 then
                    Selection:RemoveSelectedFrame(clickedFrame)
                    if Selection.selectionCallbacks[clickedFrame] then
                        Selection.selectionCallbacks[clickedFrame](clickedFrame, true)
                    end
                elseif count == 2 then
                    -- Removing leaves one frame — revert to single-select
                    Selection:RemoveSelectedFrame(clickedFrame)
                    local remainingFrame
                    for f in pairs(Selection.selectedFrames) do remainingFrame = f; break end
                    if remainingFrame and Selection.selectionCallbacks[remainingFrame] then
                        Selection.selectionCallbacks[remainingFrame](remainingFrame)
                    end
                end
            else
                Selection:AddSelectedFrame(clickedFrame)
                if Selection.selectionCallbacks[clickedFrame] then
                    Selection.selectionCallbacks[clickedFrame](clickedFrame, true)
                end
            end
            return
        end
    end

    -- Already selected (non-shift), do nothing
    if selectionOverlay.isSelected then
        return
    end

    -- Exit Canvas Mode on any other frame when clicking a different frame
    if Engine.CanvasMode and Engine.CanvasMode.currentFrame then
        local currentCanvasFrame = Engine.CanvasMode.currentFrame
        if currentCanvasFrame ~= clickedFrame then
            Engine.CanvasMode:Exit(currentCanvasFrame, function(f)
                Selection:UpdateVisuals(f)
            end)
        end
    end

    -- Clear native selection
    if not InCombatLockdown() then
        if EditModeManagerFrame then
            Selection.isClearingNativeSelection = true
            EditModeManagerFrame:ClearSelectedSystem()
            Selection.isClearingNativeSelection = false
        end
        if EditModeSystemSettingsDialog then
            EditModeSystemSettingsDialog:Hide()
        end
    end

    Selection:DeselectAll()

    if not selectionOverlay.parent.disableMovement then
        selectionOverlay.parent:SetMovable(true)
    end
    selectionOverlay.isSelected = true

    Selection:SetSelectedFrame(selectionOverlay.parent, false)
    Selection:EnableKeyboardNudge()
    Selection:UpdateVisuals(nil, selectionOverlay)

    if Engine.SelectionResize then Engine.SelectionResize:Show(selectionOverlay) end

    if Selection.selectionCallbacks[selectionOverlay.parent] then
        Selection.selectionCallbacks[selectionOverlay.parent](selectionOverlay.parent)
    end
end

-- [ MOUSE WHEEL (PADDING ADJUSTMENT) ] --------------------------------------------------------------
function Drag:OnMouseWheel(selectionOverlay, delta)
    if selectionOverlay.wheelDebounce then
        return
    end
    selectionOverlay.wheelDebounce = true
    C_Timer.After(C.Selection.WheelDebounce, function()
        selectionOverlay.wheelDebounce = nil
    end)

    if InCombatLockdown() then
        return
    end
    local parent = selectionOverlay.parent
    local Selection = Engine.FrameSelection

    if Engine.CanvasMode:IsActive(parent) then
        return
    end
    if not Engine.FrameAnchor then
        return
    end

    local anchor = Engine.FrameAnchor.anchors[parent]
    if not anchor then
        return
    end

    local change = delta > 0 and 1 or -1
    if IsShiftKeyDown() then
        change = change * C.Selection.ShiftMultiplier
    end

    local currentPadding = anchor.padding or 0
    local minPadding = -MAX_PADDING

    local anchorParentOpts = Engine.FrameAnchor.GetFrameOptions(anchor.parent)
    local anchorChildOpts = Engine.FrameAnchor.GetFrameOptions(parent)
    local ShouldMergeBorders = Engine.FrameAnchor.ShouldMergeBorders
    if ShouldMergeBorders(anchorParentOpts, anchor.edge) and ShouldMergeBorders(anchorChildOpts, anchor.edge) then
        minPadding = 0
    end

    local newPadding = Clamp(currentPadding + change, minPadding, MAX_PADDING)

    if newPadding ~= currentPadding then
        Engine.FrameAnchor:CreateAnchor(parent, anchor.parent, anchor.edge, newPadding, anchor.syncOptions, anchor.align)
        if Selection.dragCallbacks[parent] then
            Selection.dragCallbacks[parent](parent, { kind = "anchor", target = anchor.parent, edge = anchor.edge })
        end

        -- Show position tooltip (matches nudge and drag behavior)
        Engine.SelectionTooltip:ShowPosition(parent, Selection)

        -- Sync symmetric partner
        local name = parent:GetName()
        local partnerName = Selection:GetSymmetricPartner(name)
        if partnerName then
            local partner = _G[partnerName]
            if partner and Engine.FrameAnchor.anchors[partner] then
                local pAnchor = Engine.FrameAnchor.anchors[partner]
                Engine.FrameAnchor:CreateAnchor(partner, pAnchor.parent, pAnchor.edge, newPadding, pAnchor.syncOptions, pAnchor.align)
                Selection:UpdateVisuals(partner)
                if Selection.dragCallbacks[partner] then
                    Selection.dragCallbacks[partner](partner, { kind = "anchor", target = pAnchor.parent, edge = pAnchor.edge })
                end
            end
        end

        if selectionOverlay.ShowTooltip then
            selectionOverlay:ShowTooltip()
        end
    end
end
