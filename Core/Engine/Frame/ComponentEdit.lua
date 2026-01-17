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
local OVERLAY_COLOR = { r = 0.3, g = 0.8, b = 0.3, a = 0.3 } -- Green tint for canvas mode
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
local flashPool = nil  -- Single reusable flash frame

local function PlayDeniedFeedback(frame)
    local selection = frame.Selection
    if not selection then return end
    
    -- Guard: don't start new flash if one is already running
    if flashPool and flashPool:GetScript("OnUpdate") then
        return
    end
    
    -- Ensure selection is visible for the flash
    if not selection:IsShown() then
        selection:Show()
    end
    
    -- Create or reuse flash frame
    if not flashPool then
        flashPool = CreateFrame("Frame")
    end
    
    -- Flash red twice (no shake)
    local flashCount = 0
    flashPool.elapsed = 0
    flashPool.targetFrame = frame
    
    flashPool:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        
        if self.elapsed > 0.1 then
            self.elapsed = 0
            flashCount = flashCount + 1
            
            if flashCount % 2 == 1 then
                selection:SetVertexColor(1, 0.2, 0.2, 0.8)  -- Red
            else
                selection:SetVertexColor(1, 1, 1, 1)  -- Neutral
            end
            
            if flashCount >= 4 then  -- 2 complete flashes
                -- Force proper color restoration via Selection module
                if Engine.FrameSelection and Engine.FrameSelection.UpdateVisuals then
                    Engine.FrameSelection:UpdateVisuals(self.targetFrame)
                else
                    selection:SetVertexColor(1, 1, 1, 1)
                end
                self:SetScript("OnUpdate", nil)
                self.targetFrame = nil
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
        -- Check if plugin has canvasMode enabled in defaults or runtime
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
    
    -- [ CANVAS MODE ] - Move frame to center and scale up for easier editing
    -- Store original position and scale
    if frame.GetPoint and frame.GetScale then
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        if point then
            -- Generate unique session ID for this canvas entry
            local sessionId = GetTime()
            
            frame.orbitCanvasOriginal = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y,
                scale = frame:GetScale(),
                width = frame:GetWidth(),
                height = frame:GetHeight(),
                children = {},  -- Store child positions for isolation
                sessionId = sessionId,  -- Track session to prevent stale callbacks
            }
            
            -- [ CHILD ISOLATION ] - Store children's CURRENT absolute screen positions
            -- We capture these before moving the parent
            if Engine.FrameAnchor then
                local children = Engine.FrameAnchor:GetAnchoredChildren(frame)
                for _, child in ipairs(children) do
                    if child and child.GetLeft then
                        -- Store child's absolute screen position
                        local childLeft = child:GetLeft()
                        local childBottom = child:GetBottom()
                        local childScale = child:GetScale()
                        
                        if childLeft and childBottom then
                            table.insert(frame.orbitCanvasOriginal.children, {
                                child = child,
                                left = childLeft,
                                bottom = childBottom,
                                scale = childScale,
                            })
                        end
                    end
                end
            end
            
            -- Move parent to canvas position (center + 100px up, 2x scale)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
            frame:SetScale((frame.orbitCanvasOriginal.scale or 1) * 2)
            
            -- [ CHILD ISOLATION ] - Defer child repositioning to next frame
            -- This ensures the parent's move is fully processed first
            -- Use session ID to prevent stale callbacks from affecting new sessions
            C_Timer.After(0, function()
                -- Verify canvas mode is still active with same session
                if not frame.orbitCanvasOriginal then return end
                if frame.orbitCanvasOriginal.sessionId ~= sessionId then return end
                
                for _, childData in ipairs(frame.orbitCanvasOriginal.children) do
                    local child = childData.child
                    if child and child.ClearAllPoints then
                        -- Anchor child to UIParent at its original absolute position
                        child:ClearAllPoints()
                        child:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", childData.left, childData.bottom)
                        child:SetScale(childData.scale)  -- Restore original scale
                    end
                end
            end)
        end
    end

    -- Enable component drag handles for this frame
    if Engine.ComponentDrag then
        Engine.ComponentDrag:SetEnabledForFrame(frame, true)
    end

    -- Callback to update visuals
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
    
    -- [ CANVAS MODE ] - Restore original position and scale
    if frame.orbitCanvasOriginal and not InCombatLockdown() then
        local orig = frame.orbitCanvasOriginal
        
        -- Restore scale first
        frame:SetScale(orig.scale or 1)
        
        -- Restore position
        frame:ClearAllPoints()
        if orig.relativeTo and orig.relativeTo.GetName then
            frame:SetPoint(orig.point, orig.relativeTo, orig.relativePoint, orig.x, orig.y)
        else
            -- Fallback if relativeTo is invalid
            frame:SetPoint(orig.point, UIParent, orig.relativePoint or orig.point, orig.x, orig.y)
        end
        
        -- Sync children positions now that parent is restored
        -- This will recalculate all children's positions based on their anchors
        if Engine.FrameAnchor then
            Engine.FrameAnchor:SyncChildren(frame)
        end
        
        -- Cleanup canvas data
        frame.orbitCanvasOriginal = nil
    end

    -- Disable component drag handles
    if Engine.ComponentDrag then
        Engine.ComponentDrag:SetEnabledForFrame(frame, false)
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
-- External modules should use this instead of checking orbitCanvasOriginal directly
function CanvasMode:IsFrameInCanvasMode(frame)
    if frame then
        return frame.orbitCanvasOriginal ~= nil
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
        -- Active: Show green overlay for canvas mode
        if not selection.CanvasModeOverlay then
            selection.CanvasModeOverlay = selection:CreateTexture(nil, "OVERLAY")
            selection.CanvasModeOverlay:SetAllPoints()
        end
        selection.CanvasModeOverlay:SetColorTexture(
            OVERLAY_COLOR.r, OVERLAY_COLOR.g, OVERLAY_COLOR.b, OVERLAY_COLOR.a
        )
        selection.CanvasModeOverlay:Show()

        -- Inset the selection frame
        if not selection.orbitCanvasModeInset then
            selection:ClearAllPoints()
            selection:SetPoint("TOPLEFT", INSET, -INSET)
            selection:SetPoint("BOTTOMRIGHT", -INSET, INSET)
            selection.orbitCanvasModeInset = true
        end
    else
        -- Not active: Hide overlay
        if selection.CanvasModeOverlay then
            selection.CanvasModeOverlay:Hide()
        end

        -- Restore selection frame
        if selection.orbitCanvasModeInset then
            selection:ClearAllPoints()
            selection:SetAllPoints()
            selection.orbitCanvasModeInset = nil
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
        selection.CanvasModeOverlay:SetColorTexture(
            OVERLAY_COLOR.r, OVERLAY_COLOR.g, OVERLAY_COLOR.b, OVERLAY_COLOR.a
        )
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

-- Aliases for backwards compatibility
Engine.ComponentEdit = Engine.CanvasMode
Engine.FrameLock = Engine.CanvasMode
