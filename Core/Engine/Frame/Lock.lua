-- [ FRAMELOCK MODULE ]------------------------------------------------------------------------------
-- Handles frame locking functionality for Edit Mode
-- Locked frames are grey, immovable, and cannot be anchored to

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameLock = Engine.FrameLock or {}
local FrameLock = Engine.FrameLock

-- Lock state storage (weak keys to prevent memory leaks)
FrameLock.locks = FrameLock.locks or setmetatable({}, { __mode = "k" })

-- Store original positions for locked native frames (weak keys)
FrameLock.nativePositions = FrameLock.nativePositions or setmetatable({}, { __mode = "k" })

-- Constants

-- [ HELPERS ]---------------------------------------------------------------------------------------

-- Get a unique key for a frame (for persistence)
local function GetFrameKey(frame)
    if not frame then
        return nil
    end
    -- Try multiple methods to get a unique identifier
    if frame.editModeName then
        return frame.editModeName
    end
    if frame.GetName and frame:GetName() then
        return frame:GetName()
    end
    if frame.systemIndex then
        return "System_" .. tostring(frame.systemIndex)
    end
    -- Fallback: generate key from table address
    local addr = tostring(frame):match("table: (.+)")
    return addr and ("Frame_" .. addr) or nil
end

-- [ CORE API ]--------------------------------------------------------------------------------------

function FrameLock:LockFrame(frame, updateVisualsCallback)
    if not frame then
        return
    end
    self.locks[frame] = true

    -- Persist to SavedVariables
    local key = GetFrameKey(frame)
    if key and Orbit.runtime and Orbit.runtime.Locks then
        Orbit.runtime.Locks[key] = true
    end

    -- Callback to update visuals
    if updateVisualsCallback then
        updateVisualsCallback(frame)
    end
end

function FrameLock:UnlockFrame(frame, updateVisualsCallback)
    if not frame then
        return
    end
    self.locks[frame] = nil

    -- Persist to SavedVariables
    local key = GetFrameKey(frame)
    if key and Orbit.runtime and Orbit.runtime.Locks then
        Orbit.runtime.Locks[key] = nil
    end

    -- Callback to update visuals
    if updateVisualsCallback then
        updateVisualsCallback(frame)
    end
end

function FrameLock:IsLocked(frame)
    return self.locks[frame] == true
end

function FrameLock:ToggleLock(frame, updateVisualsCallback)
    if self:IsLocked(frame) then
        self:UnlockFrame(frame, updateVisualsCallback)
    else
        self:LockFrame(frame, updateVisualsCallback)
    end
end

-- Restore lock states from SavedVariables
function FrameLock:RestoreLocks(selectionsTable, updateOrbitVisualCallback, updateNativeVisualCallback)
    if not Orbit.runtime or not Orbit.runtime.Locks then
        return
    end

    -- Restore Orbit frames
    if selectionsTable then
        for frame in pairs(selectionsTable) do
            local key = GetFrameKey(frame)
            if key and Orbit.runtime.Locks[key] then
                self.locks[frame] = true
                if updateOrbitVisualCallback then
                    updateOrbitVisualCallback(frame)
                end
            end
        end
    end

    -- Restore native frames
    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        for _, systemFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            local key = GetFrameKey(systemFrame)
            if key and Orbit.runtime.Locks[key] then
                self.locks[systemFrame] = true
                if updateNativeVisualCallback then
                    updateNativeVisualCallback(systemFrame)
                end
            end
        end
    end
end

-- [ NATIVE FRAME SUPPORT ]--------------------------------------------------------------------------

-- Update visual for locked native frames
function FrameLock:UpdateNativeFrameVisual(systemFrame)
    -- Combat guard to prevent taint
    if InCombatLockdown() then
        return
    end
    if not systemFrame or not systemFrame.Selection then
        return
    end

    local selection = systemFrame.Selection
    local inset = Engine.Constants.Frame.LockInset

    if self:IsLocked(systemFrame) then
        -- Locked: Show Overlay, Hide Border

        -- Create/Show Overlay
        if not selection.LockOverlay then
            selection.LockOverlay = selection:CreateTexture(nil, "OVERLAY")
            selection.LockOverlay:SetAllPoints()
        end
        local lc = Engine.Constants.Frame.LockColor
        selection.LockOverlay:SetColorTexture(lc.r, lc.g, lc.b, 0.4)
        selection.LockOverlay:Show()

        -- Hide Border textures
        for _, region in ipairs({ selection:GetRegions() }) do
            if region:IsObjectType("Texture") and region ~= selection.LockOverlay then
                region:SetAlpha(0)
            end
        end

        -- Inset border (still useful for overlay sizing)
        if not selection.orbitInset then
            selection:ClearAllPoints()
            selection:SetPoint("TOPLEFT", inset, -inset)
            selection:SetPoint("BOTTOMRIGHT", -inset, inset)
            selection.orbitInset = true
        end
    else
        -- Unlocked: Hide Overlay, Show Border
        if selection.LockOverlay then
            selection.LockOverlay:Hide()
        end

        -- Restore Border textures
        for _, region in ipairs({ selection:GetRegions() }) do
            if region:IsObjectType("Texture") and region ~= selection.LockOverlay then
                region:SetAlpha(1)
                region:SetDesaturated(false)
                region:SetVertexColor(1, 1, 1, 1)
            end
        end

        -- Restore full border
        if selection.orbitInset then
            selection:ClearAllPoints()
            selection:SetAllPoints()
            selection.orbitInset = nil
        end
    end
end

-- Hook all registered native Edit Mode frames
function FrameLock:HookNativeFrames()
    if not EditModeManagerFrame or not EditModeManagerFrame.registeredSystemFrames then
        return
    end

    for _, systemFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
        -- Skip if already hooked
        if not systemFrame.orbitLockHooked then
            systemFrame.orbitLockHooked = true

            -- Hook the Selection frame for right-click and visuals
            if systemFrame.Selection then
                -- Right-click to toggle lock
                systemFrame.Selection:HookScript("OnMouseUp", function(selFrame, button)
                    if button == "RightButton" then
                        local parent = selFrame:GetParent()
                        FrameLock:ToggleLock(parent)
                        FrameLock:UpdateNativeFrameVisual(parent)
                    end
                end)

                -- Save position on mouse down (BEFORE drag starts)
                systemFrame.Selection:HookScript("OnMouseDown", function(selFrame, button)
                    if button == "LeftButton" then
                        local parent = selFrame:GetParent()
                        if FrameLock:IsLocked(parent) then
                            -- Save current position before any movement
                            local point, relativeTo, relativePoint, x, y = parent:GetPoint(1)
                            FrameLock.nativePositions[parent] = { point, relativeTo, relativePoint, x, y }
                        end
                    end
                end)

                -- Update visual on enter (for grey tint)
                systemFrame.Selection:HookScript("OnEnter", function(selFrame)
                    local parent = selFrame:GetParent()
                    if FrameLock:IsLocked(parent) then
                        FrameLock:UpdateNativeFrameVisual(parent)
                    end
                end)
            end

            -- Hook drag start to immediately stop movement for locked frames
            if systemFrame.OnDragStart then
                hooksecurefunc(systemFrame, "OnDragStart", function(sysFrame)
                    -- Prevent taint if frame is secure and we are in combat
                    if InCombatLockdown() then
                        return
                    end

                    if FrameLock:IsLocked(sysFrame) and FrameLock.nativePositions[sysFrame] then
                        -- Immediately stop moving and restore position
                        sysFrame:StopMovingOrSizing()
                        local pos = FrameLock.nativePositions[sysFrame]
                        sysFrame:ClearAllPoints()
                        sysFrame:SetPoint(pos[1], pos[2], pos[3], pos[4], pos[5])
                        sysFrame.isDragging = false -- Reset native drag state
                    end
                end)
            end

            -- Hook drag stop to restore position if somehow moved
            if systemFrame.OnDragStop then
                hooksecurefunc(systemFrame, "OnDragStop", function(sysFrame)
                    if InCombatLockdown() then
                        return
                    end

                    if FrameLock:IsLocked(sysFrame) and FrameLock.nativePositions[sysFrame] then
                        -- Restore saved position
                        local pos = FrameLock.nativePositions[sysFrame]
                        sysFrame:ClearAllPoints()
                        sysFrame:SetPoint(pos[1], pos[2], pos[3], pos[4], pos[5])

                        -- Trigger native position save with restored position
                        if sysFrame.OnSystemPositionChange then
                            sysFrame:OnSystemPositionChange()
                        end
                    end
                    -- Clear saved position after drag ends
                    FrameLock.nativePositions[sysFrame] = nil
                end)
            end
        end
    end
end

-- [ INITIALIZATION ]--------------------------------------------------------------------------------

-- Initialize native frame hooks when Edit Mode opens
function FrameLock:Initialize()
    if not EditModeManagerFrame then
        return
    end

    EditModeManagerFrame:HookScript("OnShow", function()
        FrameLock:HookNativeFrames()
        -- RestoreLocks is called by Frame module which has access to selections
    end)
end
