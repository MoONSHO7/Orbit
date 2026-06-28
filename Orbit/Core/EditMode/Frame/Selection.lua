-- [ ORBIT FRAME SELECTION (CORE) ] ------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L
local Engine = Orbit.Engine
local C = Orbit.Constants



Engine.FrameSelection = Engine.FrameSelection or {}
local Selection = Engine.FrameSelection

-- [ STATE ]------------------------------------------------------------------------------------------
Selection.selections = Selection.selections or {}
Selection.dragCallbacks = Selection.dragCallbacks or {}
Selection.selectionCallbacks = Selection.selectionCallbacks or {}
Selection.symmetricPairs = Selection.symmetricPairs or {}

Selection.selectedFrame = nil
Selection.selectedFrames = {}
Selection.isNativeFrame = false
Selection.keyboardHandler = nil
Selection.editModeHooked = false
Selection.combatDeferredQueue = Selection.combatDeferredQueue or {}
Selection.combatDrainRegistered = false

-- [ VISIBILITY HELPERS ] ----------------------------------------------------------------------------
local function ShouldShowOrbitFrames()
    return Orbit.db.GlobalSettings.ShowOrbitFrames ~= false
end

local function ShouldShowBlizzardFrames()
    return Orbit.db.GlobalSettings.ShowBlizzardFrames ~= false
end

local function GetOrbitEditModeColor()
    local curveData = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.EditModeColorCurve
    return (Orbit.Engine.ColorCurve:GetFirstColorFromCurve(curveData)) or C.Frame.EditModeColor
end

-- [ SYMMETRIC PAIR REGISTRATION ] -------------------------------------------------------------------
function Selection:RegisterSymmetricPair(frameNameA, frameNameB)
    self.symmetricPairs[frameNameA] = frameNameB
    self.symmetricPairs[frameNameB] = frameNameA
end

function Selection:GetSymmetricPartner(frameName)
    return self.symmetricPairs[frameName]
end

-- [ STATE MANAGEMENT ]-------------------------------------------------------------------------------
function Selection:SetSelectedFrame(frame, isNative)
    self.selectedFrame = frame
    self.selectedFrames = {}
    if frame then self.selectedFrames[frame] = true end
    self.isNativeFrame = isNative or false
end

function Selection:GetSelectedFrame()
    return self.selectedFrame
end

function Selection:AddSelectedFrame(frame)
    self.selectedFrames[frame] = true
    local sel = self.selections[frame]
    if sel then
        sel.isSelected = true
        self:UpdateVisuals(frame, sel)
        if Engine.SelectionResize then Engine.SelectionResize:Show(sel) end
    end
end

function Selection:RemoveSelectedFrame(frame)
    self.selectedFrames[frame] = nil
    local sel = self.selections[frame]
    if sel then
        sel.isSelected = false
        sel:ShowHighlighted()
        self:UpdateVisuals(frame, sel)
        if Engine.SelectionResize then Engine.SelectionResize:Hide(sel) end
    end
end

function Selection:GetSelectedFrames()
    return self.selectedFrames
end

function Selection:IsMultiSelected()
    local count = 0
    for _ in pairs(self.selectedFrames) do count = count + 1; if count > 1 then return true end end
    return false
end

-- [ HELPERS ]----------------------------------------------------------------------------------------
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

-- One permanent combat-end drain; registering per-defer would leak a listener each time and clobber an earlier deferred action.
local function DeferUntilOutOfCombat(callback)
    if not InCombatLockdown() then
        callback()
        return
    end
    table.insert(Selection.combatDeferredQueue, callback)
    if Selection.combatDrainRegistered then return end
    Selection.combatDrainRegistered = true
    Orbit.CombatManager:RegisterCombatCallback(nil, function()
        local queue = Selection.combatDeferredQueue
        Selection.combatDeferredQueue = {}
        for _, fn in ipairs(queue) do fn() end
    end)
end

-- Anchor the selection over its parent, honouring an optional per-frame outset so the highlight can grow N px on every side.
local function AnchorSelectionToParent(selection, frame)
    frame = frame or selection.parent
    if not frame then return end
    selection:ClearAllPoints()
    local outset = frame.orbitSelectionOutset
    if outset and outset ~= 0 then
        selection:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
        selection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
    else
        selection:SetAllPoints(frame)
    end
end

-- [ MAIN API ]---------------------------------------------------------------------------------------
function Selection:GetSnapTargets(excludeFrame)
    local targets = {}

    -- BFS through Orbit anchors AND UI parentage — catches circular deps across interleaved chains. Scratch tables are reused per candidate to avoid per-call allocation.
    local visited, queue = {}, {}
    local function IsDependent(target, root)
        if not target or not root then
            return false
        end

        wipe(visited)
        wipe(queue)
        queue[1] = target
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

    -- Skip AnchorGraph-skipped frames (virtual/disabled) — ReconcileChain would promote the anchor away from the drop point. Empty Tracked containers are the canonical case.
    local Graph = Engine.AnchorGraph
    for f in pairs(self.selections) do
        if f ~= excludeFrame and not f:IsForbidden() and f:IsVisible() and not Graph:IsSkipped(f) then
            -- Skip children/descendants of the dragged frame
            if not IsDependent(f, excludeFrame) then
                table.insert(targets, f)
            end
        end
    end

    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        for _, systemFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if systemFrame ~= excludeFrame and systemFrame:IsVisible() and not systemFrame:IsForbidden() and not systemFrame.orbitSnapExclude and not Graph:IsSkipped(systemFrame) then
                if not IsDependent(systemFrame, excludeFrame) then
                    table.insert(targets, systemFrame)
                end
            end
        end
    end

    return targets
end

-- Read-only snapshot of registered Orbit frames (visible, anchorable) for external snap consumers like datatexts.
function Selection:GetRegisteredFrames()
    local Graph = Engine.AnchorGraph
    local frames = {}
    for f in pairs(self.selections) do
        if not f:IsForbidden() and f:IsVisible() and not Graph:IsSkipped(f) then
            frames[#frames + 1] = f
        end
    end
    return frames
end

function Selection:Attach(frame, dragCallback, selectionCallback)
    if self.selections[frame] then
        return
    end

    local selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
    AnchorSelectionToParent(selection, frame)
    selection:SetToplevel(false) -- template has toplevel=true; disable to prevent auto-Raise on Show()
    selection:SetFrameStrata(Orbit.Constants.Strata.Overlay)
    selection:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.EditModeSelection)
    selection.isOrbitSelection = true

    Engine.AnchorLines:Ensure(selection)

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
            Engine.CanvasMode:Toggle(self.parent, function(f)
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
        if not self.parent or self.parent.orbitIsDragging then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:AddLine(self.system.GetSystemName(), 1, 0.82, 0)
        GameTooltip:AddLine(EDIT_MODE_CLICK_TO_EDIT, 1, 1, 1)

        -- Show Canvas Mode hint if plugin supports it
        if self.parent and self.parent.orbitPlugin and self.parent.orbitPlugin.canvasMode then
            GameTooltip:AddLine(L.CFG_EM_TIP_OPEN_CANVAS, 0.6, 0.9, 0.6)
        end

        if self.parent and self.parent.editModeTooltipLines then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine(L.CFG_EM_TIP_EXIT_AND, 0.6, 0.6, 0.6)
            for _, line in ipairs(self.parent.editModeTooltipLines) do
                GameTooltip:AddLine(line, 0.6, 0.6, 0.6)
            end
            if self.parent.isTrackedBar then
                GameTooltip:AddLine(L.CFG_EM_TIP_DELETE_ICONS, 0.6, 0.6, 0.6)
            elseif self.parent.isChargeBar then
                GameTooltip:AddLine(L.CFG_EM_TIP_DELETE_BARS, 0.6, 0.6, 0.6)
            end
        end
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

    -- Attach resize handle for plugins with Width/Height settings
    if Engine.SelectionResize then Engine.SelectionResize:Attach(selection, frame) end

    if not self.editModeHooked then
        EventRegistry:RegisterCallback("EditMode.Enter", function() self:OnEditModeEnter() end, self)
        EventRegistry:RegisterCallback("EditMode.Exit", function() self:OnEditModeExit() end, self)

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

-- [ EDIT MODE HANDLERS ]-----------------------------------------------------------------------------
function Selection:OnEditModeEnter()
    Engine.SelectionPeekHide:Enable(self)
    DeferUntilOutOfCombat(function()
        if not (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then
            return
        end
        local showOrbit = ShouldShowOrbitFrames()
        for frame, selection in pairs(Selection.selections) do
            if frame.orbitDisabled then
                selection:Hide()
            elseif selection.isOrbitSelection and not showOrbit then
                selection:SetAlpha(0)
                selection:EnableMouse(false)
            else
                Selection:UpdateVisuals(frame, selection)
                if not frame.disableMovement then
                    frame:SetMovable(true)
                end
            end
        end

        -- Update native Blizzard frames
        if EditModeManagerFrame.registeredSystemFrames then
            local showNative = ShouldShowBlizzardFrames()
            for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
                if frame.Selection then
                    frame.Selection:SetAlpha(showNative and 1 or 0)
                    frame.Selection:EnableMouse(showNative)
                end
            end
        end

        -- Auto-start Edit Mode tour for first-time users
        if Orbit.db and Orbit.db.AccountSettings and not Orbit.db.AccountSettings.TourComplete then
            if Engine.EditModeTour then Engine.EditModeTour:StartTour() end
        end

        -- Phase 3 implementation
        if Engine.FrameAnchor then
            Engine.FrameAnchor:ReconcileAll()
        end
    end)
end

function Selection:OnEditModeExit()
    Engine.SelectionPeekHide:Disable(self)
    -- End tour if active
    if Engine.EditModeTour then Engine.EditModeTour:EndTour() end
    -- Immediate Visual Cleanup (Safe in Combat)
    for frame, selection in pairs(Selection.selections) do
        selection:Hide()
        if selection.AnchorLineFrame then
            selection.AnchorLineFrame:Hide()
        end
        if Engine.SelectionResize then Engine.SelectionResize:Hide(selection) end
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

        -- Phase 3 implementation
        if Engine.FrameAnchor then
            Engine.FrameAnchor:ReconcileAll()
        end
    end)
end

function Selection:DeselectAll()
    self.selectedFrame = nil
    self.selectedFrames = {}
    self.isNativeFrame = false
    self:DisableKeyboardNudge()

    for _, selection in pairs(self.selections) do
        if selection.isSelected then
            selection.isSelected = false
            selection:ShowSelected(false)
            selection:ShowHighlighted()
            if Engine.SelectionResize then Engine.SelectionResize:Hide(selection) end

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

-- [ KEYBOARD NUDGE (DELEGATES TO MODULE) ]-----------------------------------------------------------
function Selection:EnableKeyboardNudge()
    Engine.SelectionNudge:Enable(self)
end

function Selection:DisableKeyboardNudge()
    Engine.SelectionNudge:Disable(self)
end

-- [ FORCE UPDATE ]-----------------------------------------------------------------------------------
function Selection:ForceUpdate(frame)
    local selection = self.selections[frame]
    if selection and selection:IsShown() then
        AnchorSelectionToParent(selection, frame)
        self:UpdateVisuals(frame, selection)
    end
end

function Selection:RefreshVisuals()
    -- 1. Update Orbit Selections
    local showOrbit = ShouldShowOrbitFrames()

    for frame, selection in pairs(self.selections) do
        if frame.orbitDisabled then
            selection:Hide()
        elseif selection.isOrbitSelection then
            if showOrbit then
                self:UpdateVisuals(frame, selection)
            else
                selection:SetAlpha(0)
                selection:EnableMouse(false)
            end
        else
            self:UpdateVisuals(frame, selection)
        end
    end

    -- 2. Update Native Blizzard Frames
    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        local showNative = ShouldShowBlizzardFrames()

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

-- [ UPDATE VISUALS ]---------------------------------------------------------------------------------
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

    -- Canvas Mode: Show green selection to indicate editable state
    local isComponentEdit = Engine.CanvasMode:IsActive(selection.parent)
    if isComponentEdit then
        -- Show selection with green tint for Canvas Mode
        selection:Show()
        selection:SetFrameStrata(Orbit.Constants.Strata.Overlay)

        -- Green tint for canvas mode
        ForEachRegion(selection, function(region)
            if region:IsObjectType("Texture") and region ~= selection.ComponentEditOverlay then
                region:SetDesaturated(false)
                region:SetVertexColor(0.3, 0.9, 0.3, 1)
                region:SetAlpha(1)
            end
        end)

        -- Hide label in canvas mode
        if selection.Label then
            selection.Label:Hide()
        end

        Engine.AnchorLines:Hide(selection)
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
        selection:SetFrameStrata(Orbit.Constants.Strata.Overlay)
        selection:EnableMouse(true)

        ForEachRegion(selection, function(region)
            if region:IsObjectType("Texture") and region ~= selection.ComponentEditOverlay then
                region:SetDesaturated(false)
                region:SetVertexColor(1, 1, 1, 1)
                region:SetAlpha(1)
            end
        end)

        selection:ShowSelected(true)
        if selection.Label then selection.Label:SetText("") end
        if selection.Highlight then
            selection.Highlight:SetVertexColor(1, 1, 1, 1)
            selection.Highlight:SetAlpha(1)
        end

        if selection.orbitInset or selection.orbitCanvasInset then
            AnchorSelectionToParent(selection, selection.parent)
            selection.orbitInset = nil
            selection.orbitCanvasInset = nil
        end

        local isAnchored = Engine.FrameAnchor:GetAnchorParent(selection.parent) ~= nil
        if isAnchored then
            local anchor = Engine.FrameAnchor.anchors[selection.parent]
            if anchor and anchor.edge then
                Engine.AnchorLines:ShowOn(selection, GetOppositeEdge(anchor.edge), anchor.align)
            end
        else
            Engine.AnchorLines:Hide(selection)
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
        selection:SetFrameStrata(Orbit.Constants.Strata.Overlay)
        selection:EnableMouse(true)

        ForEachRegion(selection, function(region)
            if region:IsObjectType("Texture") and region ~= selection.ComponentEditOverlay then
                region:SetAlpha(1)
            end
        end)

        selection:ShowHighlighted()
        if selection.Label then selection.Label:SetText("") end

        if selection.orbitInset or selection.orbitCanvasInset then
            AnchorSelectionToParent(selection, selection.parent)
            selection.orbitInset = nil
            selection.orbitCanvasInset = nil
        end

        local isAnchored = Engine.FrameAnchor:GetAnchorParent(selection.parent) ~= nil

        if isAnchored then
            if selection.isOrbitSelection then
                if ShouldShowOrbitFrames() then
                    local c = GetOrbitEditModeColor()
                    TintSelection(selection, c.r, c.g, c.b, true)
                    selection:Show()
                    selection:SetAlpha(1)
                    selection:EnableMouse(true)
                else
                    selection:SetAlpha(0)
                    selection:EnableMouse(false)
                    return
                end
            else
                -- Always hide native selection to prevent z-fighting/persistence
                if frame.Selection then
                    frame.Selection:Hide()
                end

                if ShouldShowBlizzardFrames() then
                    TintSelection(selection, 1, 1, 1, false)
                    selection:Show()
                else
                    selection:Hide() -- Hide entirely if native frames disabled
                    return
                end
            end
            local anchor = Engine.FrameAnchor.anchors[selection.parent]
            if anchor and anchor.edge then
                Engine.AnchorLines:ShowOn(selection, GetOppositeEdge(anchor.edge), anchor.align)
            end
        else
            if selection.isOrbitSelection then
                if ShouldShowOrbitFrames() then
                    local c = GetOrbitEditModeColor()
                    TintSelection(selection, c.r, c.g, c.b, true)
                    selection:Show()
                    selection:SetAlpha(1)
                    selection:EnableMouse(true)
                else
                    selection:SetAlpha(0)
                    selection:EnableMouse(false)
                    return
                end
            else
                -- Always hide native selection to prevent z-fighting/persistence
                if frame.Selection then
                    frame.Selection:Hide()
                end

                if ShouldShowBlizzardFrames() then
                    TintSelection(selection, 1, 1, 1, false)
                    selection:Show() -- Ensure Orbit's proxy is shown
                else
                    selection:Hide()
                    return
                end
            end
            Engine.AnchorLines:Hide(selection)
        end
    else
        selection:Hide()
    end
end
