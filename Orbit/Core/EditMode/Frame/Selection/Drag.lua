-- [ ORBIT SELECTION - DRAG HANDLERS ]--------------------------------------------------------------
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
local OPPOSITE_EDGES = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }
local function GetOppositeEdge(edge)
    return OPPOSITE_EDGES[edge]
end

-- [ BLIZZARD EDIT MODE TAP-IN ]----------------------------------------------------------------------
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

-- [ PRECISION MODE (SHIFT-DRAG OVERLAY SUPPRESSION) ]----------------------------------------------

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

-- [ DRAG UPDATE (VISUALS) ]-------------------------------------------------------------------------

local function RestorePreviewSize(selectionOverlay, isDragging)
    local parent = selectionOverlay.parent
    local needsReposition = selectionOverlay.previewOrigWidth or selectionOverlay.previewOrigHeight
    if not needsReposition then return end
    if isDragging then parent:StopMovingOrSizing() end
    local l, b = parent:GetLeft(), parent:GetBottom()
    local dw, dh = 0, 0
    if selectionOverlay.previewOrigWidth then
        dw = parent:GetWidth() - selectionOverlay.previewOrigWidth
        parent:SetWidth(selectionOverlay.previewOrigWidth)
        selectionOverlay.previewOrigWidth = nil
    end
    if selectionOverlay.previewOrigHeight then
        dh = parent:GetHeight() - selectionOverlay.previewOrigHeight
        parent:SetHeight(selectionOverlay.previewOrigHeight)
        selectionOverlay.previewOrigHeight = nil
    end
    parent:ClearAllPoints()
    parent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + dw / 2, b + dh / 2)
    if isDragging then parent:StartMoving() end
end

local function OnDragUpdate(selectionOverlay, elapsed)
    local parent = selectionOverlay.parent
    local Selection = Engine.FrameSelection

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

    local targets = Selection:GetSnapTargets(parent)
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
            Selection:ShowAnchorLine(oldSel, nil)
        end
        Selection:ShowAnchorLine(selectionOverlay, nil)
        RestorePreviewSize(selectionOverlay, true)

        local targetSel = Selection.selections[anchorTarget]
        Selection:ShowAnchorLine(targetSel, anchorEdge, lineAlign)
        Selection:ShowAnchorLine(selectionOverlay, GetOppositeEdge(anchorEdge), lineAlign)

        selectionOverlay.lastAnchorTarget = anchorTarget
        selectionOverlay.lastAnchorAlign = lineAlign
    elseif not anchorTarget and selectionOverlay.lastAnchorTarget then
        local oldSel = Selection.selections[selectionOverlay.lastAnchorTarget]
        Selection:ShowAnchorLine(oldSel, nil)
        Selection:ShowAnchorLine(selectionOverlay, nil)
        RestorePreviewSize(selectionOverlay, true)
        selectionOverlay.lastAnchorTarget = nil
        selectionOverlay.lastAnchorAlign = nil
    end

    local anchorLabel = selectionOverlay.lastAnchorAlign and Engine.SelectionTooltip:BuildAnchorLabel(selectionOverlay.lastAnchorAlign) or nil
    Engine.SelectionTooltip:ShowPosition(parent, Selection, true, anchorLabel)
end

-- [ DRAG START (FUNCTION) ]------------------------------------------------------------------------

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

        local anchor = Engine.FrameAnchor.anchors[parent]
        if anchor then
            -- Capture visual center before break. BreakAnchor fires
            -- OnAnchorChanged which may resize the frame (e.g. TrackedBar
            -- reverts from synced width to its saved width). Repositioning
            -- after break keeps the visual center stable under the cursor.
            local preCX = (parent:GetLeft() + parent:GetRight()) / 2
            local preCY = (parent:GetBottom() + parent:GetTop()) / 2
            local oldParent = anchor.parent
            local oldAxis = Engine.Axis.ForEdge(anchor.edge)
            local root = oldAxis and oldParent and Engine.FrameAnchor:GetRootParent(oldParent) or nil

            Engine.FrameAnchor:BreakAnchor(parent, true, true)
            Orbit.EventBus:Fire("BORDER_LAYOUT_CHANGED")

            if root then
                Engine.FrameAnchor:SyncChildren(root)
            end

            -- Reanchor so visual center matches pre-break position
            local postW, postH = parent:GetWidth(), parent:GetHeight()
            parent:ClearAllPoints()
            parent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", preCX - postW / 2, preCY - postH / 2)
            parent:StartMoving()
        else
            parent:StartMoving()
        end

        if parent.orbitAutoOrient and Engine.FrameOrientation then
            Engine.FrameOrientation:StartTracking(parent)
        end

        selectionOverlay.lastAnchorTarget = nil
        selectionOverlay.lastAnchorAlign = nil
        selectionOverlay.precisionMode = false

        if IsShiftKeyDown() then
            SetNonSelectedOverlaysVisible(selectionOverlay, false)
        elseif ShouldUseBlizzardPreview(parent) then
            SetBlizzardSnapPreview(parent, true)
        end

        selectionOverlay:SetScript("OnUpdate", OnDragUpdate)
    end
end

-- [ DRAG STOP ]-------------------------------------------------------------------------------------

function Drag:OnDragStop(selectionOverlay)
    Drag.isDragging = false
    local parent = selectionOverlay.parent
    
    if selectionOverlay.lastAnchorTarget then
        local Selection = Engine.FrameSelection
        local oldSel = Selection.selections[selectionOverlay.lastAnchorTarget]
        Selection:ShowAnchorLine(oldSel, nil)
        selectionOverlay.lastAnchorTarget = nil
        selectionOverlay.lastAnchorAlign = nil
    end
    RestorePreviewSize(selectionOverlay)
    Engine.FrameSelection:ShowAnchorLine(selectionOverlay, nil)
    selectionOverlay:SetScript("OnUpdate", nil)
    SetBlizzardSnapPreview(parent, false)

    -- Restore overlays if precision mode was active
    if selectionOverlay.precisionMode then
        SetNonSelectedOverlaysVisible(selectionOverlay, true)
        Engine.FrameSelection:RefreshVisuals()
    end

    if InCombatLockdown() then
        return
    end

    local parent = selectionOverlay.parent
    parent:StopMovingOrSizing()

    if Engine.CanvasMode:IsActive(parent) then
        parent.orbitIsDragging = nil
        return
    end

    -- Break existing anchor
    Engine.FrameAnchor:BreakAnchor(parent, true)

    local Selection = Engine.FrameSelection
    local precisionMode = IsShiftKeyDown() or parent.orbitNoSnap

    if precisionMode then
        -- Precision mode: save raw position, skip all snapping
        local point, _, _, x, y = parent:GetPoint(1)
        parent:ClearAllPoints()
        parent:SetPoint(point or "CENTER", x or 0, y or 0)

        if Selection.dragCallbacks[parent] then
            Selection.dragCallbacks[parent](parent, point or "CENTER", x or 0, y or 0)
        end
    else
        -- Detect snap
        local targets = Selection:GetSnapTargets(parent)
        local closestX, closestY, anchorTarget, anchorEdge, anchorAlign = Engine.FrameSnap:DetectSnap(
            parent,
            false,
            targets,
            nil -- No locked-frame filter needed
        )

        -- Check if anchoring is enabled globally
        local anchoringEnabled = not Orbit.db or not Orbit.db.GlobalSettings or Orbit.db.GlobalSettings.AnchoringEnabled ~= false

        -- Only allow anchoring to Orbit frames (in Selection.selections registry)
        local isOrbitFrame = Selection.selections[anchorTarget] ~= nil

        if anchorTarget and anchorEdge and anchoringEnabled and isOrbitFrame then
            local padding = nil
            local name = parent:GetName()
            local partnerName = Selection:GetSymmetricPartner(name)
            if partnerName then
                local partner = _G[partnerName]
                if partner and Engine.FrameAnchor.anchors[partner] then
                    padding = Engine.FrameAnchor.anchors[partner].padding or 0
                end
            end

            Engine.FrameAnchor:CreateAnchor(parent, anchorTarget, anchorEdge, padding, nil, anchorAlign)

            -- Defer group border update after new anchor is established
            Orbit.EventBus:Fire("BORDER_LAYOUT_CHANGED")

            if Selection.dragCallbacks[parent] then
                Selection.dragCallbacks[parent](parent, "ANCHORED", anchorTarget, anchorEdge)
            end
        else
            local point, x, y = Engine.FrameSnap:NormalizePosition(parent)
            if not point then
                point, _, _, x, y = parent:GetPoint(1)
            end

            if Selection.dragCallbacks[parent] then
                Selection.dragCallbacks[parent](parent, point, x, y)
            end

            parent:ClearAllPoints()
            parent:SetPoint(point or "CENTER", x or 0, y or 0)

            if parent.orbitPlugin and parent.orbitPlugin.ApplySettings then
                parent.orbitPlugin:ApplySettings(parent)
            end
        end
    end

    Selection:UpdateVisuals(parent)

    -- Show final position in tooltip (with fade)
    Engine.SelectionTooltip:ShowPosition(parent, Selection)

    if selectionOverlay.ShowTooltip then
        selectionOverlay:ShowTooltip()
    end

    parent.orbitIsDragging = nil

    -- Stop orientation tracking
    if parent.orbitAutoOrient and Engine.FrameOrientation then
        Engine.FrameOrientation:StopTracking(parent)
    end
end

-- [ MOUSE DOWN (SELECTION) ]------------------------------------------------------------------------

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

-- [ MOUSE WHEEL (PADDING ADJUSTMENT) ]-------------------------------------------------------------

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
            Selection.dragCallbacks[parent](parent, "ANCHORED", anchor.parent, anchor.edge)
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
                    Selection.dragCallbacks[partner](partner, "ANCHORED", pAnchor.parent, pAnchor.edge)
                end
            end
        end

        if selectionOverlay.ShowTooltip then
            selectionOverlay:ShowTooltip()
        end
    end
end
