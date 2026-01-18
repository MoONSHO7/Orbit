-- [ ORBIT SELECTION - DRAG HANDLERS ]--------------------------------------------------------------
-- Handles drag start, stop, mouse wheel padding, and mouse down selection

local _, Orbit = ...
local Engine = Orbit.Engine
local C = Orbit.Constants

local Drag = {}
Engine.SelectionDrag = Drag

-- [ DRAG START ]-------------------------------------------------------------------------------------

-- [ DRAG UPDATE (VISUALS) ]-------------------------------------------------------------------------

local function OnDragUpdate(selectionOverlay, elapsed)
    local parent = selectionOverlay.parent
    local Selection = Engine.FrameSelection

    -- Optimization: Throttle check?
    -- For smoothness, every frame is better, logic is cheap enough.

    local targets = Selection:GetSnapTargets(parent)
    local closestX, closestY, anchorTarget, anchorEdge = Engine.FrameSnap:DetectSnap(
        parent,
        true,
        targets, -- showGuides=true (prevents applying snap, red lines are disabled)
        nil -- No locked-frame filter needed
    )

    if anchorTarget and anchorEdge and anchorTarget ~= selectionOverlay.lastAnchorTarget then
        -- Clear previous
        if selectionOverlay.lastAnchorTarget then
            local oldSel = Selection.selections[selectionOverlay.lastAnchorTarget]
            Selection:ShowAnchorLine(oldSel, nil)
        end

        -- Show new
        local targetSel = Selection.selections[anchorTarget]
        Selection:ShowAnchorLine(targetSel, anchorEdge)

        selectionOverlay.lastAnchorTarget = anchorTarget
    elseif not anchorTarget and selectionOverlay.lastAnchorTarget then
        -- Lost target, clear line
        local oldSel = Selection.selections[selectionOverlay.lastAnchorTarget]
        Selection:ShowAnchorLine(oldSel, nil)
        selectionOverlay.lastAnchorTarget = nil
    end

    -- Show dynamic position tooltip
    Engine.SelectionTooltip:ShowPosition(parent, Selection, true)
end

-- [ DRAG START (FUNCTION) ]------------------------------------------------------------------------

function Drag:OnDragStart(selectionOverlay)
    if InCombatLockdown() then
        return
    end
    local parent = selectionOverlay.parent

    if Engine.ComponentEdit:IsActive(parent) then
        return
    end

    if parent:IsMovable() then
        parent:StartMoving()
        parent.orbitIsDragging = true

        -- Start Visual Update Loop
        selectionOverlay.lastAnchorTarget = nil
        selectionOverlay:SetScript("OnUpdate", OnDragUpdate)
    end
end

-- [ DRAG STOP ]-------------------------------------------------------------------------------------

function Drag:OnDragStop(selectionOverlay)
    -- Clean up visuals immediately
    if selectionOverlay.lastAnchorTarget then
        local Selection = Engine.FrameSelection
        local oldSel = Selection.selections[selectionOverlay.lastAnchorTarget]
        Selection:ShowAnchorLine(oldSel, nil)
        selectionOverlay.lastAnchorTarget = nil
    end
    selectionOverlay:SetScript("OnUpdate", nil)

    if InCombatLockdown() then
        return
    end

    local parent = selectionOverlay.parent
    parent:StopMovingOrSizing()

    if Engine.ComponentEdit:IsActive(parent) then
        parent.orbitIsDragging = nil
        return
    end

    -- Break existing anchor
    Engine.FrameAnchor:BreakAnchor(parent, true)

    -- Detect snap
    local Selection = Engine.FrameSelection
    local targets = Selection:GetSnapTargets(parent)
    local closestX, closestY, anchorTarget, anchorEdge, anchorAlign = Engine.FrameSnap:DetectSnap(
        parent,
        false,
        targets,
        nil -- No locked-frame filter needed
    )

    -- Check if anchoring is enabled
    local anchoringEnabled = not Orbit.db or not Orbit.db.GlobalSettings 
        or Orbit.db.GlobalSettings.AnchoringEnabled ~= false

    if anchorTarget and anchorEdge and anchoringEnabled then
        local padding = nil
        local name = parent:GetName()
        local partnerName = Selection:GetSymmetricPartner(name)
        if partnerName then
            local partner = _G[partnerName]
            if partner and Engine.FrameAnchor.anchors[partner] then
                -- If partner is anchored, inherit their padding
                padding = Engine.FrameAnchor.anchors[partner].padding or 0
            end
        end

        Engine.FrameAnchor:CreateAnchor(parent, anchorTarget, anchorEdge, padding, nil, anchorAlign)

        if Selection.dragCallbacks[parent] then
            Selection.dragCallbacks[parent](parent, "ANCHORED", anchorTarget, anchorEdge)
        end
    else
        local point, x, y = Engine.FrameSnap:NormalizePosition(parent)
        parent:ClearAllPoints()
        parent:SetPoint(point, x, y)

        if Selection.dragCallbacks[parent] then
            Selection.dragCallbacks[parent](parent, point, x, y)
        end
    end

    Selection:UpdateVisuals(parent)

    -- Show final position in tooltip (with fade)
    Engine.SelectionTooltip:ShowPosition(parent, Selection)

    if selectionOverlay.ShowTooltip then
        selectionOverlay:ShowTooltip()
    end

    parent.orbitIsDragging = nil
end

-- [ MOUSE DOWN (SELECTION) ]------------------------------------------------------------------------

function Drag:OnMouseDown(selectionOverlay)
    if InCombatLockdown() then
        return
    end

    -- Already selected, do nothing
    if selectionOverlay.isSelected then
        return
    end

    local Selection = Engine.FrameSelection
    local clickedFrame = selectionOverlay.parent
    
    -- Exit Canvas Mode on any other frame when clicking a different frame
    if Engine.ComponentEdit and Engine.ComponentEdit.currentFrame then
        local currentCanvasFrame = Engine.ComponentEdit.currentFrame
        if currentCanvasFrame ~= clickedFrame then
            Engine.ComponentEdit:Exit(currentCanvasFrame, function(f)
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

    if Engine.ComponentEdit:IsActive(parent) then
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
    local minPadding = -((Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderSize) or 4)

    if anchor.syncOptions and anchor.syncOptions.mergeBorders then
        minPadding = 0
    end

    local newPadding = Clamp(currentPadding + change, minPadding, 500)

    if newPadding ~= currentPadding then
        Engine.FrameAnchor:CreateAnchor(
            parent,
            anchor.parent,
            anchor.edge,
            newPadding,
            anchor.syncOptions,
            anchor.align
        )
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
                Engine.FrameAnchor:CreateAnchor(
                    partner,
                    pAnchor.parent,
                    pAnchor.edge,
                    newPadding,
                    pAnchor.syncOptions,
                    pAnchor.align
                )
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
