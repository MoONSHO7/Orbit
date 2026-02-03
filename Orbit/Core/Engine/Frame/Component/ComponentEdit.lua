-- [ CANVAS MODE MODULE ]----------------------------------------------------------------------------
-- Handles Canvas Mode for Edit Mode
-- Allows internal elements of a frame to be dragged/repositioned
-- Only ONE frame can be in Canvas Mode at a time
-- Frame is moved to center and scaled 2x for easier editing

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.CanvasMode = Engine.CanvasMode or {}
local CanvasMode = Engine.CanvasMode

-- Currently active frame (only one at a time)
CanvasMode.currentFrame = nil

-- Visual constants
local CANVAS_BORDER_COLOR = { r = 0.3, g = 0.8, b = 0.3, a = 1.0 } -- Green border for canvas mode
local CANVAS_BORDER_SIZE = 3 -- Thicker border for visibility
local CANVAS_BACKGROUND_COLOR = { r = 0, g = 0, b = 0, a = 0.4 } -- Dark background at 40% opacity
local OVERLAY_COLOR = { r = 0.3, g = 0.8, b = 0.3, a = 0.3 } -- Green overlay for native frames in canvas mode
local CANVAS_PADDING = 25 -- Must match ComponentDrag PADDING
local INSET = 4

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function GetFrameKey(frame)
    if not frame then
        return nil
    end
    if frame.editModeName then
        return frame.editModeName
    end
    if frame.GetName and frame:GetName() then
        return frame:GetName()
    end
    if frame.systemIndex then
        return "System_" .. tostring(frame.systemIndex)
    end
    return nil
end

-- [ CORE API ]--------------------------------------------------------------------------------------

-- Visual feedback when canvas mode is denied (simple red blink)
-- Uses pooled frame to avoid memory leak from repeated CreateFrame calls
local flashPool = nil -- Single reusable flash frame

local function PlayDeniedFeedback(frame)
    -- Try Orbit's selection registry first, then fall back to frame.Selection (for native frames)
    -- This order prevents issues where frame.Selection might be a Texture instead of the Selection frame
    local selection
    if Engine.FrameSelection then
        selection = Engine.FrameSelection.selections[frame]
    end
    if not selection then
        selection = frame.Selection
    end
    if not selection then
        return
    end

    -- Guard: don't start new flash if one is already running
    if flashPool and flashPool:GetScript("OnUpdate") then
        return
    end

    -- Track if selection was already visible before we started
    local wasShown = selection:IsShown()

    -- Ensure selection is visible for the flash
    if not wasShown then
        selection:Show()
    end

    -- Create or reuse flash frame
    if not flashPool then
        flashPool = CreateFrame("Frame")
    end

    -- Helper to tint all textures in the selection (like TintSelection in Selection.lua)
    -- Handles both Frame selections (with child textures) and direct Texture selections
    local function TintSelectionTextures(sel, r, g, b, a)
        -- If selection is a Frame with GetRegions, iterate over child textures
        if sel.GetRegions then
            for i = 1, select("#", sel:GetRegions()) do
                local region = select(i, sel:GetRegions())
                if region:IsObjectType("Texture") and not region.isAnchorLine then
                    region:SetVertexColor(r, g, b, a)
                end
            end
        -- If selection is a Texture directly, tint it
        elseif sel.SetVertexColor then
            sel:SetVertexColor(r, g, b, a)
        end
    end

    -- Flash red twice (no shake)
    local flashCount = 0
    flashPool.elapsed = 0
    flashPool.targetFrame = frame
    flashPool.targetSelection = selection
    flashPool.wasShown = wasShown
    flashPool.tintFunc = TintSelectionTextures

    flashPool:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed

        if self.elapsed > 0.1 then
            self.elapsed = 0
            flashCount = flashCount + 1

            local sel = self.targetSelection
            local tint = self.tintFunc
            if flashCount % 2 == 1 then
                tint(sel, 1, 0.2, 0.2, 0.8) -- Red
            else
                tint(sel, 1, 1, 1, 1) -- Neutral
            end

            if flashCount >= 4 then -- 2 complete flashes
                -- Force proper color restoration via Selection module
                if Engine.FrameSelection and Engine.FrameSelection.UpdateVisuals then
                    Engine.FrameSelection:UpdateVisuals(self.targetFrame)
                else
                    tint(sel, 1, 1, 1, 1)
                end

                -- If Edit Mode is not active, ensure selection is hidden
                if not (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then
                    if sel.Hide then
                        sel:Hide()
                    end
                -- If Edit Mode is still open but selection wasn't shown before, hide it
                elseif not self.wasShown then
                    if sel.Hide then
                        sel:Hide()
                    end
                    -- Also call UpdateVisuals to restore proper state
                    if Engine.FrameSelection and Engine.FrameSelection.UpdateVisuals then
                        Engine.FrameSelection:UpdateVisuals(self.targetFrame)
                    end
                end

                self:SetScript("OnUpdate", nil)
                self.targetFrame = nil
                self.targetSelection = nil
                self.wasShown = nil
                self.tintFunc = nil
            end
        end
    end)
end

function CanvasMode:Enter(frame, updateVisualsCallback)
    if not frame then
        return
    end

    -- Combat guard
    if InCombatLockdown() then
        return
    end

    -- Check if frame's plugin allows canvas mode
    local allowCanvasMode = false
    if frame.orbitPlugin then
        allowCanvasMode = frame.orbitPlugin.canvasMode == true
    end

    if not allowCanvasMode then
        -- Play denied feedback (red flash + shake)
        PlayDeniedFeedback(frame)
        return
    end

    -- Exit any previously active frame first (exclusive mode)
    if self.currentFrame and self.currentFrame ~= frame then
        self:Exit(self.currentFrame)
    end

    self.currentFrame = frame

    -- Open the Canvas Mode Dialog
    local dialog = Engine.CanvasModeDialog or Orbit.CanvasModeDialog
    if dialog then
        local plugin = frame.orbitPlugin
        local systemIndex = frame.systemIndex or (plugin and plugin.system) or 1
        dialog:Open(frame, plugin, systemIndex)
    end

    -- Callback to update visuals (hide Edit Mode selection)
    if updateVisualsCallback then
        updateVisualsCallback(frame)
    end
end

function CanvasMode:Exit(frame, updateVisualsCallback)
    if not frame then
        return
    end

    -- Only exit if this is the active frame
    if self.currentFrame ~= frame then
        return
    end

    self.currentFrame = nil

    -- Close the Canvas Mode Dialog (it handles frame restoration internally)
    local dialog = Engine.CanvasModeDialog or Orbit.CanvasModeDialog
    if dialog and dialog:IsShown() then
        -- Use Cancel to restore positions if exiting externally
        dialog:Cancel()
    end

    -- Restore selection visuals to standard Edit Mode appearance
    if Engine.FrameSelection then
        Engine.FrameSelection:UpdateVisuals(frame)
    end

    -- Callback to update visuals
    if updateVisualsCallback then
        updateVisualsCallback(frame)
    end
end

function CanvasMode:IsActive(frame)
    return self.currentFrame == frame
end

-- Public API: Check if ANY frame is in canvas mode, or a specific frame
function CanvasMode:IsFrameInCanvasMode(frame)
    if frame then
        return self.currentFrame == frame
    end
    return self.currentFrame ~= nil
end

function CanvasMode:Toggle(frame, updateVisualsCallback)
    if self:IsActive(frame) then
        self:Exit(frame, updateVisualsCallback)
    else
        self:Enter(frame, updateVisualsCallback)
    end
end

function CanvasMode:ExitAll()
    if self.currentFrame then
        self:Exit(self.currentFrame)
    end
    -- Also disable all drag handles
    if Engine.ComponentDrag then
        Engine.ComponentDrag:DisableAll()
    end
end

function CanvasMode:GetCurrentFrame()
    return self.currentFrame
end

-- [ VISUAL UPDATES ]--------------------------------------------------------------------------------

-- Create border-only overlay (no fill) that covers the full editable area
local function CreateCanvasBorder(parent)
    local border = {}
    local c = CANVAS_BORDER_COLOR
    local size = CANVAS_BORDER_SIZE

    -- Top border
    border.top = parent:CreateTexture(nil, "OVERLAY")
    border.top:SetColorTexture(c.r, c.g, c.b, c.a)
    border.top:SetHeight(size)
    border.top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    -- Bottom border
    border.bottom = parent:CreateTexture(nil, "OVERLAY")
    border.bottom:SetColorTexture(c.r, c.g, c.b, c.a)
    border.bottom:SetHeight(size)
    border.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    -- Left border
    border.left = parent:CreateTexture(nil, "OVERLAY")
    border.left:SetColorTexture(c.r, c.g, c.b, c.a)
    border.left:SetWidth(size)
    border.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)

    -- Right border
    border.right = parent:CreateTexture(nil, "OVERLAY")
    border.right:SetColorTexture(c.r, c.g, c.b, c.a)
    border.right:SetWidth(size)
    border.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    return border
end

local function SetCanvasBorderShown(border, shown)
    if not border then
        return
    end
    local method = shown and "Show" or "Hide"
    if border.top then
        border.top[method](border.top)
    end
    if border.bottom then
        border.bottom[method](border.bottom)
    end
    if border.left then
        border.left[method](border.left)
    end
    if border.right then
        border.right[method](border.right)
    end
end

-- Update visual overlay for Orbit frames in Canvas Mode
function CanvasMode:UpdateOrbitFrameVisual(frame)
    if not frame then
        return
    end

    local selection = frame.Selection
    if not selection then
        return
    end

    if self:IsActive(frame) then
        -- Create canvas background frame (dark overlay at BACKGROUND strata)
        if not CanvasMode.backgroundFrame then
            CanvasMode.backgroundFrame = CreateFrame("Frame", "OrbitCanvasBackgroundFrame", UIParent)
            CanvasMode.backgroundFrame:SetFrameStrata("BACKGROUND")
            CanvasMode.backgroundFrame:SetFrameLevel(0)

            -- Create dark background texture
            CanvasMode.backgroundTexture = CanvasMode.backgroundFrame:CreateTexture(nil, "BACKGROUND")
            CanvasMode.backgroundTexture:SetAllPoints()
            local bg = CANVAS_BACKGROUND_COLOR
            CanvasMode.backgroundTexture:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
        end

        -- Create canvas border frame - parent to UIParent to avoid scale inheritance
        if not CanvasMode.borderFrame then
            CanvasMode.borderFrame = CreateFrame("Frame", "OrbitCanvasBorderFrame", UIParent)
            CanvasMode.borderFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            CanvasMode.borderFrame:SetFrameLevel(150)
            CanvasMode.border = CreateCanvasBorder(CanvasMode.borderFrame)
        end

        -- Position frames using screen coordinates (accounts for frame scale)
        local function UpdateCanvasPosition()
            if not frame or not frame:IsShown() then
                return
            end

            local scale = frame:GetEffectiveScale()
            local uiScale = UIParent:GetEffectiveScale()
            local scaleRatio = scale / uiScale

            -- Get frame's screen position
            local left = frame:GetLeft()
            local right = frame:GetRight()
            local top = frame:GetTop()
            local bottom = frame:GetBottom()

            if not left or not right or not top or not bottom then
                return
            end

            -- Convert to UIParent space and add padding
            local padding = CANVAS_PADDING * scaleRatio
            local uiLeft = (left * scale / uiScale) - padding
            local uiBottom = (bottom * scale / uiScale) - padding
            local uiRight = (right * scale / uiScale) + padding
            local uiTop = (top * scale / uiScale) + padding
            local width = uiRight - uiLeft
            local height = uiTop - uiBottom

            -- Update border frame
            CanvasMode.borderFrame:ClearAllPoints()
            CanvasMode.borderFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", uiLeft, uiBottom)
            CanvasMode.borderFrame:SetSize(width, height)

            -- Update background frame (same position and size)
            CanvasMode.backgroundFrame:ClearAllPoints()
            CanvasMode.backgroundFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", uiLeft, uiBottom)
            CanvasMode.backgroundFrame:SetSize(width, height)
        end

        -- Update position immediately and on each frame (in case of movement)
        UpdateCanvasPosition()
        CanvasMode.borderFrame:SetScript("OnUpdate", UpdateCanvasPosition)

        -- Show canvas elements
        CanvasMode.backgroundFrame:Show()
        CanvasMode.borderFrame:Show()
        SetCanvasBorderShown(CanvasMode.border, true)

        -- Note: Selection visual is handled by Selection:UpdateVisuals() which
        -- makes textures transparent but keeps frame interactive for right-click exit
    else
        -- Not active: Hide canvas elements
        if CanvasMode.backgroundFrame then
            CanvasMode.backgroundFrame:Hide()
        end
        if CanvasMode.borderFrame then
            CanvasMode.borderFrame:Hide()
            CanvasMode.borderFrame:SetScript("OnUpdate", nil)
            SetCanvasBorderShown(CanvasMode.border, false)
        end
    end
end

-- Update visual for native Blizzard frames
function CanvasMode:UpdateNativeFrameVisual(systemFrame)
    if InCombatLockdown() then
        return
    end
    if not systemFrame or not systemFrame.Selection then
        return
    end

    local selection = systemFrame.Selection

    if self:IsActive(systemFrame) then
        -- Active: Show green overlay
        if not selection.CanvasModeOverlay then
            selection.CanvasModeOverlay = selection:CreateTexture(nil, "OVERLAY")
            selection.CanvasModeOverlay:SetAllPoints()
        end
        selection.CanvasModeOverlay:SetColorTexture(OVERLAY_COLOR.r, OVERLAY_COLOR.g, OVERLAY_COLOR.b, OVERLAY_COLOR.a)
        selection.CanvasModeOverlay:Show()

        -- Dim the border
        for _, region in ipairs({ selection:GetRegions() }) do
            if region:IsObjectType("Texture") and region ~= selection.CanvasModeOverlay then
                region:SetAlpha(0.3)
            end
        end
    else
        -- Not active: Hide overlay
        if selection.CanvasModeOverlay then
            selection.CanvasModeOverlay:Hide()
        end

        -- Restore border
        for _, region in ipairs({ selection:GetRegions() }) do
            if region:IsObjectType("Texture") and region ~= selection.CanvasModeOverlay then
                region:SetAlpha(1)
            end
        end
    end
end

-- [ INITIALIZATION ]--------------------------------------------------------------------------------

function CanvasMode:Initialize()
    if not EditModeManagerFrame then
        return
    end

    -- Exit canvas mode when Edit Mode closes
    EditModeManagerFrame:HookScript("OnHide", function()
        CanvasMode:ExitAll()
    end)
end

-- Alias for backwards compatibility
Engine.ComponentEdit = Engine.CanvasMode
