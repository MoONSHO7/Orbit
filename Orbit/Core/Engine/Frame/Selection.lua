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

-- [ VISIBILITY HELPERS ]--------------------------------------------------------------------------
-- DRY: Centralized visibility checks for Orbit and Blizzard frames

local function ShouldShowOrbitFrames()
    return Orbit.db.GlobalSettings.ShowOrbitFrames ~= false
end

local function ShouldShowBlizzardFrames()
    return Orbit.db.GlobalSettings.ShowBlizzardFrames ~= false
end

local function GetOrbitEditModeColor()
    local curveData = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.EditModeColorCurve
    return (Orbit.Engine.WidgetLogic and Orbit.Engine.WidgetLogic:GetFirstColorFromCurve(curveData)) or Engine.Constants.Frame.EditModeColor
end

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

local ANCHOR_ALIGN_COLORS = {
    LEFT = { 1.0, 0.55, 0.15 },
    RIGHT = { 0.8, 0.4, 1.0 },
    TOP = { 1.0, 0.55, 0.15 },
    BOTTOM = { 0.8, 0.4, 1.0 },
    CENTER = { 0.2, 0.9, 0.85 },
}
local DEFAULT_ANCHOR_COLOR = { 0, 1, 0 }

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
            if systemFrame ~= excludeFrame and systemFrame:IsVisible() and not systemFrame:IsForbidden() and not systemFrame.orbitSnapExclude then
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
    selection:SetAllPoints()
    selection:SetFrameStrata("HIGH")
    selection:SetFrameLevel(frame:GetFrameLevel() + 100)
    selection.isOrbitSelection = true

    -- Create anchor line textures
    local lineThickness = C.Selection.AnchorLineThickness

    local lineContainer = CreateFrame("Frame", nil, UIParent)
    lineContainer:SetFrameStrata("FULLSCREEN_DIALOG")
    lineContainer:SetFrameLevel(9999)
    lineContainer:SetAllPoints(selection)
    selection.AnchorLineFrame = lineContainer

    selection.AnchorLineTop = lineContainer:CreateTexture(nil, "OVERLAY")
    selection.AnchorLineTop:SetColorTexture(0, 1, 0, 1)
    selection.AnchorLineTop:SetPoint("TOPLEFT", selection, "TOPLEFT", 0, lineThickness)
    selection.AnchorLineTop:SetPoint("TOPRIGHT", selection, "TOPRIGHT", 0, lineThickness)
    selection.AnchorLineTop:SetHeight(lineThickness)
    selection.AnchorLineTop.isAnchorLine = true
    selection.AnchorLineTop:Hide()

    selection.AnchorLineBottom = lineContainer:CreateTexture(nil, "OVERLAY")
    selection.AnchorLineBottom:SetColorTexture(0, 1, 0, 1)
    selection.AnchorLineBottom:SetPoint("BOTTOMLEFT", selection, "BOTTOMLEFT", 0, -lineThickness)
    selection.AnchorLineBottom:SetPoint("BOTTOMRIGHT", selection, "BOTTOMRIGHT", 0, -lineThickness)
    selection.AnchorLineBottom:SetHeight(lineThickness)
    selection.AnchorLineBottom.isAnchorLine = true
    selection.AnchorLineBottom:Hide()

    selection.AnchorLineLeft = lineContainer:CreateTexture(nil, "OVERLAY")
    selection.AnchorLineLeft:SetColorTexture(0, 1, 0, 1)
    selection.AnchorLineLeft:SetPoint("TOPLEFT", selection, "TOPLEFT", -lineThickness, 0)
    selection.AnchorLineLeft:SetPoint("BOTTOMLEFT", selection, "BOTTOMLEFT", -lineThickness, 0)
    selection.AnchorLineLeft:SetWidth(lineThickness)
    selection.AnchorLineLeft.isAnchorLine = true
    selection.AnchorLineLeft:Hide()

    selection.AnchorLineRight = lineContainer:CreateTexture(nil, "OVERLAY")
    selection.AnchorLineRight:SetColorTexture(0, 1, 0, 1)
    selection.AnchorLineRight:SetPoint("TOPRIGHT", selection, "TOPRIGHT", lineThickness, 0)
    selection.AnchorLineRight:SetPoint("BOTTOMRIGHT", selection, "BOTTOMRIGHT", lineThickness, 0)
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

        -- Show Canvas Mode hint if plugin supports it
        if self.parent and self.parent.orbitPlugin and self.parent.orbitPlugin.canvasMode then
            GameTooltip:AddLine("Right-click: Open Canvas Mode", 0.6, 0.9, 0.6)
        end

        if self.parent and self.parent.editModeTooltipLines then
            for _, line in ipairs(self.parent.editModeTooltipLines) do
                GameTooltip:AddLine(line, 0.8, 0.8, 0.8)
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
            if not frame.disableMovement then
                frame:SetMovable(true)
            end
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
        if selection.AnchorLineFrame then
            selection.AnchorLineFrame:Hide()
        end
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

local ANCHOR_LINE_KEY = { TOP = "AnchorLineTop", BOTTOM = "AnchorLineBottom", LEFT = "AnchorLineLeft", RIGHT = "AnchorLineRight" }

function Selection:ShowAnchorLine(selection, side, align)
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

    if not side then
        if selection.AnchorLineFrame then
            selection.AnchorLineFrame:Hide()
        end
        return
    end

    local line = selection[ANCHOR_LINE_KEY[side]]
    if line then
        local c = (align and ANCHOR_ALIGN_COLORS[align]) or DEFAULT_ANCHOR_COLOR
        line:SetColorTexture(c[1], c[2], c[3], 1)
        if selection.AnchorLineFrame then
            selection.AnchorLineFrame:Show()
        end
        line:Show()
    end
end

-- [ FORCE UPDATE ]----------------------------------------------------------------------------------

function Selection:ForceUpdate(frame)
    local selection = self.selections[frame]
    if selection and selection:IsShown() then
        selection:ClearAllPoints()
        selection:SetAllPoints(frame)
        self:UpdateVisuals(frame, selection)
    end
end

function Selection:RefreshVisuals()
    -- 1. Update Orbit Selections
    local showOrbit = ShouldShowOrbitFrames()

    for frame, selection in pairs(self.selections) do
        if selection.isOrbitSelection then
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

    -- Canvas Mode: Show green selection to indicate editable state
    local isComponentEdit = Engine.ComponentEdit:IsActive(selection.parent)
    if isComponentEdit then
        -- Show selection with green tint for Canvas Mode
        selection:Show()
        selection:SetFrameStrata("HIGH")

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

        Selection:ShowAnchorLine(selection, nil)
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
            selection:ClearAllPoints()
            selection:SetAllPoints(selection.parent)
            selection.orbitInset = nil
            selection.orbitCanvasInset = nil
        end

        local isAnchored = Engine.FrameAnchor:GetAnchorParent(selection.parent) ~= nil
        if isAnchored then
            local anchor = Engine.FrameAnchor.anchors[selection.parent]
            if anchor and anchor.edge then
                Selection:ShowAnchorLine(selection, GetOppositeEdge(anchor.edge), anchor.align)
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

        ForEachRegion(selection, function(region)
            if region:IsObjectType("Texture") and region ~= selection.ComponentEditOverlay then
                region:SetAlpha(1)
            end
        end)

        selection:ShowHighlighted()
        if selection.Label then selection.Label:SetText("") end

        if selection.orbitInset or selection.orbitCanvasInset then
            selection:ClearAllPoints()
            selection:SetAllPoints(selection.parent)
            selection.orbitInset = nil
            selection.orbitCanvasInset = nil
        end

        local isAnchored = Engine.FrameAnchor:GetAnchorParent(selection.parent) ~= nil

        if isAnchored then
            if selection.isOrbitSelection then
                if ShouldShowOrbitFrames() then
                    local c = GetOrbitEditModeColor()
                    TintSelection(selection, c.r, c.g, c.b, true)
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
                Selection:ShowAnchorLine(selection, GetOppositeEdge(anchor.edge), anchor.align)
            end
        else
            if selection.isOrbitSelection then
                if ShouldShowOrbitFrames() then
                    local c = GetOrbitEditModeColor()
                    TintSelection(selection, c.r, c.g, c.b, true)
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
            Selection:ShowAnchorLine(selection, nil)
        end
    else
        selection:Hide()
    end
end
