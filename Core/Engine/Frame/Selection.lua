-- [ ORBIT FRAME SELECTION (CORE) ]-----------------------------------------------------------------
-- This is the refactored core module. Drag/Nudge/Tooltip/NativeHook
-- have been extracted into separate files in Selection/ subdirectory.

local _, Orbit = ...
local Engine = Orbit.Engine
local C = Orbit.Constants

Engine.FrameSelection = Engine.FrameSelection or {}
local Selection = Engine.FrameSelection

-- [ STATE ]-----------------------------------------------------------------------------------------

Selection.selections = Selection.selections or {}
Selection.dragCallbacks = Selection.dragCallbacks or {}
Selection.selectionCallbacks = Selection.selectionCallbacks or {}
Selection.symmetricPairs = Selection.symmetricPairs or {}

Selection.selectedFrame = nil
Selection.isNativeFrame = false
Selection.keyboardHandler = nil
Selection.editModeHooked = false
Selection.combatDeferredCallback = nil

-- [ SYMMETRIC PAIR REGISTRATION ]------------------------------------------------------------------

function Selection:RegisterSymmetricPair(frameNameA, frameNameB)
    self.symmetricPairs[frameNameA] = frameNameB
    self.symmetricPairs[frameNameB] = frameNameA
end

function Selection:GetSymmetricPartner(frameName)
    return self.symmetricPairs[frameName]
end

-- [ STATE MANAGEMENT ]------------------------------------------------------------------------------

function Selection:SetSelectedFrame(frame, isNative)
    self.selectedFrame = frame
    self.isNativeFrame = isNative or false
end

function Selection:GetSelectedFrame()
    return self.selectedFrame
end

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function TintSelection(selection, r, g, b, desaturate)
    if not selection then
        return
    end
    for i = 1, select("#", selection:GetRegions()) do
        local region = select(i, selection:GetRegions())
        if region:IsObjectType("Texture") and not region.isAnchorLine then
            region:SetDesaturated(desaturate)
            region:SetVertexColor(r, g, b, 1)
        end
    end
end

local function ForEachRegion(selection, callback)
    if not selection then
        return
    end
    for i = 1, select("#", selection:GetRegions()) do
        local region = select(i, selection:GetRegions())
        callback(region)
    end
end

local OPPOSITE_EDGES = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }
local function GetOppositeEdge(edge)
    return OPPOSITE_EDGES[edge]
end

local function DeferUntilOutOfCombat(callback)
    if not InCombatLockdown() then
        callback()
        return
    end
    Selection.combatDeferredCallback = callback
    Orbit.CombatManager:RegisterCombatCallback(nil, function()
        if Selection.combatDeferredCallback then
            Selection.combatDeferredCallback()
            Selection.combatDeferredCallback = nil
        end
    end)
end

-- [ MAIN API ]--------------------------------------------------------------------------------------

function Selection:GetSnapTargets(excludeFrame)
    local targets = {}

    -- Unified Dependency Check (BFS)
    -- Checks if target depends on root via ANY combination of Orbit Anchors or UI Parentage.
    -- This prevents circular dependencies even in complex interleaved chains.
    local function IsDependent(target, root)
        if not target or not root then
            return false
        end

        local visited = {}
        local queue = { target }
        local head = 1

        while head <= #queue do
            local current = queue[head]
            head = head + 1

            if current == root then
                return true
            end

            if not visited[current] then
                visited[current] = true

                -- Add Orbit Parent to check
                local orbitParent = Engine.FrameAnchor:GetAnchorParent(current)
                if orbitParent then
                    table.insert(queue, orbitParent)
                end

                -- Add UI Parent to check
                local uiParent = current:GetParent()
                if uiParent then
                    table.insert(queue, uiParent)
                end
            end
        end

        return false
    end

    for f in pairs(self.selections) do
        if f ~= excludeFrame and not f:IsForbidden() and f:IsVisible() then
            -- Skip children/descendants of the dragged frame
            if not IsDependent(f, excludeFrame) then
                table.insert(targets, f)
            end
        end
    end

    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        for _, systemFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if systemFrame ~= excludeFrame and systemFrame:IsVisible() and not systemFrame:IsForbidden() then
                if not IsDependent(systemFrame, excludeFrame) then
                    table.insert(targets, systemFrame)
                end
            end
        end
    end

    return targets
end

function Selection:Attach(frame, dragCallback, selectionCallback)
    if self.selections[frame] then
        return
    end

    local selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")

    local parentScale = frame:GetScale()
    if parentScale ~= 1 then
        selection:SetScale(1 / parentScale)
    end

    selection:SetAllPoints()
    selection:SetFrameStrata("HIGH")
    selection:SetFrameLevel(frame:GetFrameLevel() + 100)
    selection.isOrbitSelection = true

    -- Create anchor line textures
    local lineThickness = C.Selection.AnchorLineThickness

    selection.AnchorLineTop = selection:CreateTexture(nil, "OVERLAY")
    selection.AnchorLineTop:SetColorTexture(0, 1, 0, 1)
    selection.AnchorLineTop:SetPoint("TOPLEFT", 0, 1)
    selection.AnchorLineTop:SetPoint("TOPRIGHT", 0, 1)
    selection.AnchorLineTop:SetHeight(lineThickness)
    selection.AnchorLineTop.isAnchorLine = true
    selection.AnchorLineTop:Hide()

    selection.AnchorLineBottom = selection:CreateTexture(nil, "OVERLAY")
    selection.AnchorLineBottom:SetColorTexture(0, 1, 0, 1)
    selection.AnchorLineBottom:SetPoint("BOTTOMLEFT", 0, -1)
    selection.AnchorLineBottom:SetPoint("BOTTOMRIGHT", 0, -1)
    selection.AnchorLineBottom:SetHeight(lineThickness)
    selection.AnchorLineBottom.isAnchorLine = true
    selection.AnchorLineBottom:Hide()

    selection.AnchorLineLeft = selection:CreateTexture(nil, "OVERLAY")
    selection.AnchorLineLeft:SetColorTexture(0, 1, 0, 1)
    selection.AnchorLineLeft:SetPoint("TOPLEFT", -1, 0)
    selection.AnchorLineLeft:SetPoint("BOTTOMLEFT", -1, 0)
    selection.AnchorLineLeft:SetWidth(lineThickness)
    selection.AnchorLineLeft.isAnchorLine = true
    selection.AnchorLineLeft:Hide()

    selection.AnchorLineRight = selection:CreateTexture(nil, "OVERLAY")
    selection.AnchorLineRight:SetColorTexture(0, 1, 0, 1)
    selection.AnchorLineRight:SetPoint("TOPRIGHT", 1, 0)
    selection.AnchorLineRight:SetPoint("BOTTOMRIGHT", 1, 0)
    selection.AnchorLineRight:SetWidth(lineThickness)
    selection.AnchorLineRight.isAnchorLine = true
    selection.AnchorLineRight:Hide()

    -- Wire up event handlers using extracted modules
    local Drag = Engine.SelectionDrag

    selection:SetScript("OnMouseDown", function(self)
        Drag:OnMouseDown(self)
    end)
    selection:SetScript("OnDragStart", function(self)
        Drag:OnDragStart(self)
    end)
    selection:SetScript("OnDragStop", function(self)
        Drag:OnDragStop(self)
    end)
    selection:EnableMouseWheel(true)
    selection:SetScript("OnMouseWheel", function(self, delta)
        Drag:OnMouseWheel(self, delta)
    end)

    selection:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            Engine.ComponentEdit:Toggle(self.parent, function(f)
                Selection:UpdateVisuals(f)
            end)
        end
    end)

    selection:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self:ShowHighlighted()
        end
        self:ShowTooltip()
    end)

    selection:SetScript("OnLeave", function(self)
        if not self.isSelected then
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
                self:ShowHighlighted()
            else
                self:Hide()
            end
        end
        GameTooltip:Hide()
    end)

    function selection:ShowTooltip()
        if not self.parent then
            return
        end

        -- Edge-aware anchor selection
        local anchor = "ANCHOR_TOP"
        local selfTop = self:GetTop()
        local selfRight = self:GetRight()
        local screenHeight = GetScreenHeight()
        local screenWidth = GetScreenWidth()

        -- If too close to top, anchor below instead
        if selfTop and screenHeight and selfTop > (screenHeight * 0.85) then
            anchor = "ANCHOR_BOTTOM"
        end
        -- If too close to right edge, flip to left-anchored variant
        if selfRight and screenWidth and selfRight > (screenWidth * 0.85) then
            if anchor == "ANCHOR_TOP" then
                anchor = "ANCHOR_TOPLEFT"
            else
                anchor = "ANCHOR_BOTTOMLEFT"
            end
        end

        GameTooltip:SetOwner(self, anchor)
        GameTooltip:AddLine(self:GetLabelText(), 1, 0.82, 0)
        GameTooltip:AddLine(EDIT_MODE_CLICK_TO_EDIT, 1, 1, 1)
        GameTooltip:Show()
    end

    selection:Hide()

    if selection.Label then
        selection.Label:SetText(frame.editModeName or frame:GetName() or "Frame")
    end

    selection.parent = frame

    -- Copy editModeName and systemIndex from parent for dialog title support
    selection.editModeName = frame.editModeName
    selection.systemIndex = frame.systemIndex

    if not selection.system then
        selection.system = {
            GetSystemName = function()
                return frame.editModeName or frame:GetName() or "Frame"
            end,
        }
    end

    function selection:GetLabelText()
        if self.Label then
            return self.Label:GetText()
        end
        return self.system.GetSystemName()
    end

    self.selections[frame] = selection
    self.dragCallbacks[frame] = dragCallback
    self.selectionCallbacks[frame] = selectionCallback

    if not self.editModeHooked then
        EditModeManagerFrame:HookScript("OnShow", function()
            self:OnEditModeEnter()
        end)
        EditModeManagerFrame:HookScript("OnHide", function()
            self:OnEditModeExit()
        end)

        -- Register combat callback to force visual cleanup and reuse
        Orbit.CombatManager:RegisterCombatCallback(function()
            -- On Combat Start: Force visual exit
            self:OnEditModeExit()
        end, function()
            -- On Combat End: Restore visual state if Edit Mode is still open
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
                self:OnEditModeEnter()
            end
        end)

        self.editModeHooked = true
    end
end

-- [ EDIT MODE HANDLERS ]----------------------------------------------------------------------------

function Selection:OnEditModeEnter()
    DeferUntilOutOfCombat(function()
        if not (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then
            return
        end
        for frame, selection in pairs(Selection.selections) do
            Selection:UpdateVisuals(frame, selection)
            frame:SetMovable(true)
        end
        
        -- Force refresh to apply native visibility settings immediately
        Selection:RefreshVisuals()

        Engine.SelectionNativeHook:Hook(Selection)
    end)
end

function Selection:OnEditModeExit()
    -- Immediate Visual Cleanup (Safe in Combat)
    for frame, selection in pairs(Selection.selections) do
        selection:Hide()
    end

    -- Deferred State/Logic Cleanup (Unsafe in Combat)
    DeferUntilOutOfCombat(function()
        if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
            return
        end

        for frame, selection in pairs(Selection.selections) do
            -- Ensure hidden (redundant but safe)
            selection:Hide()
            selection.isSelected = false

            -- Protected calls
            if frame.SetMovable then
                frame:SetMovable(false)
            end
        end
        Selection:DisableKeyboardNudge()
    end)
end

function Selection:DeselectAll()
    self:SetSelectedFrame(nil, false)
    self:DisableKeyboardNudge()

    for _, selection in pairs(self.selections) do
        if selection.isSelected then
            selection.isSelected = false
            selection:ShowSelected(false)
            selection:ShowHighlighted()

            if EditModeManagerFrame:IsShown() then
                self:UpdateVisuals(nil, selection)
                if selection.parent then
                    selection.parent:SetMovable(true)
                end
            else
                selection:Hide()
                if selection.parent then
                    selection.parent:SetMovable(false)
                end
            end
        end
    end
end

-- [ KEYBOARD NUDGE (DELEGATES TO MODULE) ]----------------------------------------------------------

function Selection:EnableKeyboardNudge()
    Engine.SelectionNudge:Enable(self)
end

function Selection:DisableKeyboardNudge()
    Engine.SelectionNudge:Disable(self)
end

-- [ ANCHOR LINE VISIBILITY ]----------------------------------------------------------------------

function Selection:ShowAnchorLine(selection, side)
    if not selection then
        return
    end

    if selection.AnchorLineTop then
        selection.AnchorLineTop:Hide()
    end
    if selection.AnchorLineBottom then
        selection.AnchorLineBottom:Hide()
    end
    if selection.AnchorLineLeft then
        selection.AnchorLineLeft:Hide()
    end
    if selection.AnchorLineRight then
        selection.AnchorLineRight:Hide()
    end

    if side == "TOP" and selection.AnchorLineTop then
        selection.AnchorLineTop:Show()
    end
    if side == "BOTTOM" and selection.AnchorLineBottom then
        selection.AnchorLineBottom:Show()
    end
    if side == "LEFT" and selection.AnchorLineLeft then
        selection.AnchorLineLeft:Show()
    end
    if side == "RIGHT" and selection.AnchorLineRight then
        selection.AnchorLineRight:Show()
    end
end

-- [ FORCE UPDATE ]----------------------------------------------------------------------------------

function Selection:ForceUpdate(frame)
    local selection = self.selections[frame]
    if selection and selection:IsShown() then
        local parentScale = frame:GetScale()

        selection:ClearAllPoints()

        if parentScale ~= 1 and selection:GetParent() == frame then
            selection:SetScale(1 / parentScale)
        end

        selection:SetAllPoints(frame)
        self:UpdateVisuals(frame, selection)
    end
end

function Selection:RefreshVisuals()
    -- 1. Update Orbit Selections
    for frame, selection in pairs(self.selections) do
        if selection:IsShown() then
            self:UpdateVisuals(frame, selection)
        end
    end

    -- 2. Update Native Blizzard Frames
    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        local showNative = true
        if Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.ShowBlizzardFrames == false then
            showNative = false
        end

        for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if frame.Selection then
                if showNative then
                    frame.Selection:SetAlpha(1)
                    frame.Selection:EnableMouse(true)
                else
                    frame.Selection:SetAlpha(0)
                    frame.Selection:EnableMouse(false)
                end
            end
        end
    end
end

-- [ UPDATE VISUALS ]--------------------------------------------------------------------------------

function Selection:UpdateVisuals(frame, selection)
    if not selection then
        if not frame then
            return
        end
        selection = self.selections[frame]
    end
    if not selection then
        return
    end

    -- Compensate for parent scale
    local parentScale = selection.parent:GetScale()
    if parentScale and parentScale > 0.01 then
        selection:SetScale(1 / parentScale)
    else
        selection:SetScale(1)
    end

    -- Canvas Mode is now handled by CanvasModeDialog - no special visuals needed here
    -- Just check if frame is in canvas mode (dialog is open) and skip standard visuals
    local isComponentEdit = Engine.ComponentEdit:IsActive(selection.parent)
    if isComponentEdit then
        -- Hide selection while in Canvas Mode (frame is in dialog)
        selection:Hide()
        return
    end

    if selection.isSelected then
        -- Selected: Yellow
        if selection.ComponentEditOverlay then
            selection.ComponentEditOverlay:Hide()
        end
        if selection.CanvasBorderFrame then
            selection.CanvasBorderFrame:Hide()
        end
        
        -- Restore strata and mouse interaction
        selection:SetFrameStrata("HIGH")
        selection:EnableMouse(true)
        
        -- Show the label again
        if selection.Label then
            selection.Label:Show()
        end
        
        ForEachRegion(selection, function(region)
            if region:IsObjectType("Texture") and region ~= selection.ComponentEditOverlay then
                region:SetAlpha(1)
            end
        end)

        selection:ShowSelected(true)
        if selection.Highlight then
            selection.Highlight:SetVertexColor(1, 1, 1, 1)
            selection.Highlight:SetAlpha(1)
        end

        if selection.orbitInset or selection.orbitCanvasInset then
            selection:ClearAllPoints()
            selection:SetAllPoints(selection.parent)
            selection.orbitInset = nil
            selection.orbitCanvasInset = nil
        end

        local isAnchored = Engine.FrameAnchor:GetAnchorParent(selection.parent) ~= nil
        if isAnchored then
            local anchor = Engine.FrameAnchor.anchors[selection.parent]
            if anchor and anchor.edge then
                Selection:ShowAnchorLine(selection, GetOppositeEdge(anchor.edge))
            end
        else
            Selection:ShowAnchorLine(selection, nil)
        end
    elseif EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        -- Edit Mode Active (not selected)
        if selection.ComponentEditOverlay then
            selection.ComponentEditOverlay:Hide()
        end
        if selection.CanvasBorderFrame then
            selection.CanvasBorderFrame:Hide()
        end
        
        -- Restore strata and mouse interaction
        selection:SetFrameStrata("HIGH")
        selection:EnableMouse(true)
        
        -- Show the label again
        if selection.Label then
            selection.Label:Show()
        end
        
        ForEachRegion(selection, function(region)
            if region:IsObjectType("Texture") and region ~= selection.ComponentEditOverlay then
                region:SetAlpha(1)
            end
        end)

        selection:ShowHighlighted()

        if selection.orbitInset or selection.orbitCanvasInset then
            selection:ClearAllPoints()
            selection:SetAllPoints(selection.parent)
            selection.orbitInset = nil
            selection.orbitCanvasInset = nil
        end

        local isAnchored = Engine.FrameAnchor:GetAnchorParent(selection.parent) ~= nil

        if isAnchored then
            if selection.isOrbitSelection then
                local c = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.EditModeColor or Engine.Constants.Frame.EditModeColor
                TintSelection(selection, c.r, c.g, c.b, true)
            else
                local showNative = true
                if Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.ShowBlizzardFrames == false then
                    showNative = false
                end
                
                -- Always hide native selection to prevent z-fighting/persistence
                if frame.Selection then frame.Selection:Hide() end

                if showNative then
                     TintSelection(selection, 1, 1, 1, false)
                     selection:Show()
                else
                     selection:Hide() -- Hide entirely if native frames disabled
                     return
                end
            end
            local anchor = Engine.FrameAnchor.anchors[selection.parent]
            if anchor and anchor.edge then
                Selection:ShowAnchorLine(selection, GetOppositeEdge(anchor.edge))
            end
        else
            if selection.isOrbitSelection then
                local c = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.EditModeColor or Engine.Constants.Frame.EditModeColor
                TintSelection(selection, c.r, c.g, c.b, true)
            else
                local showNative = true
                if Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.ShowBlizzardFrames == false then
                    showNative = false
                end

                 -- Always hide native selection to prevent z-fighting/persistence
                 if frame.Selection then frame.Selection:Hide() end

                 if showNative then
                     TintSelection(selection, 1, 1, 1, false)
                     selection:Show() -- Ensure Orbit's proxy is shown
                else
                     selection:Hide()
                     return
                end
            end
            Selection:ShowAnchorLine(selection, nil)
        end
    else
        selection:Hide()
    end
end
