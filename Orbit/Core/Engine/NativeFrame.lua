-- [ ORBIT NATIVE FRAME ]----------------------------------------------------------------------------
-- Centralized utilities for working with Blizzard's native frames
-- Supports three scenarios:
--   1. Hide & Replace: Hide native, create custom replacement
--   2. Disable Only: Stop events, prevent showing
--   3. Modify In-Place: Hook and modify native properties

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.NativeFrame = Engine.NativeFrame or {}
local NativeFrame = Engine.NativeFrame

-- Shared hidden parent for all hidden native frames
NativeFrame.hiddenParent = nil

-- Track hidden frames for potential restoration
NativeFrame.hidden = {}
NativeFrame.disabled = {}
NativeFrame.modified = {}
NativeFrame.protected = {}

-- [ SCENARIO 1: HIDE & REPLACE ]--------------------------------------------------------------------
-- Completely hides the native frame by reparenting to invisible container
-- Use when creating a full custom replacement

--- Hide a native frame completely
-- @param nativeFrame Frame: The native Blizzard frame to hide
-- @param options table: Optional settings
--   - unregisterEvents boolean: Unregister all events (default: true)
--   - clearScripts boolean: Clear OnEvent/OnUpdate scripts (default: true)
-- @return boolean: true if successful
function NativeFrame:Hide(nativeFrame, options)
    if not nativeFrame then
        return false
    end
    options = options or {}

    local unregisterEvents = options.unregisterEvents ~= false
    local clearScripts = options.clearScripts ~= false

    -- Create hidden parent once
    if not self.hiddenParent then
        self.hiddenParent = CreateFrame("Frame", "OrbitHiddenParent", UIParent)
        self.hiddenParent:Hide()
        self.hiddenParent:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
    end

    -- Store original state for potential restore
    local backup = {
        parent = nativeFrame:GetParent(),
        shown = nativeFrame:IsShown(),
        events = {},
    }

    -- Reparent to hidden container
    nativeFrame:SetParent(self.hiddenParent)
    nativeFrame:Hide()

    -- Unregister events
    if unregisterEvents then
        nativeFrame:UnregisterAllEvents()
    end

    -- Clear scripts
    if clearScripts then
        if nativeFrame:GetScript("OnEvent") then
            backup.onEvent = nativeFrame:GetScript("OnEvent")
            nativeFrame:SetScript("OnEvent", nil)
        end
        if nativeFrame:GetScript("OnUpdate") then
            backup.onUpdate = nativeFrame:GetScript("OnUpdate")
            nativeFrame:SetScript("OnUpdate", nil)
        end
    end

    -- Track for restore
    self.hidden[nativeFrame] = backup

    return true
end

--- Hide multiple native frames at once
-- @param frames table: Array of frames to hide
-- @param options table: Options to apply to all
function NativeFrame:HideMany(frames, options)
    for _, frame in ipairs(frames) do
        self:Hide(frame, options)
    end
end

-- [ SCENARIO 2: DISABLE ONLY ]----------------------------------------------------------------------
-- Prevents the frame from showing without reparenting
-- Use for frames like TalkingHead that should be toggleable

--- Disable a native frame (prevent showing)
-- @param nativeFrame Frame: The native frame to disable
-- @param options table: Optional settings
--   - unregisterEvents boolean: Unregister all events (default: false)
-- @return boolean: true if successful
function NativeFrame:Disable(nativeFrame, options)
    if not nativeFrame then
        return false
    end
    options = options or {}

    local unregisterEvents = options.unregisterEvents or false

    -- Store original state
    local backup = {
        onShow = nativeFrame:GetScript("OnShow"),
        shown = nativeFrame:IsShown(),
    }

    -- Hide and prevent future shows
    nativeFrame:Hide()
    nativeFrame:SetScript("OnShow", function(self)
        self:Hide()
    end)

    -- Optionally unregister events
    if unregisterEvents then
        nativeFrame:UnregisterAllEvents()
        backup.eventsUnregistered = true
    end

    self.disabled[nativeFrame] = backup

    return true
end

--- Re-enable a previously disabled frame
-- @param nativeFrame Frame: The native frame to re-enable
-- @return boolean: true if successful
function NativeFrame:Enable(nativeFrame)
    if not nativeFrame then
        return false
    end

    local backup = self.disabled[nativeFrame]
    if not backup then
        return false
    end

    -- Restore OnShow
    nativeFrame:SetScript("OnShow", backup.onShow)

    -- Show if was originally shown
    if backup.shown then
        nativeFrame:Show()
    end

    self.disabled[nativeFrame] = nil

    return true
end

-- [ SCENARIO 3: MODIFY IN-PLACE ]-------------------------------------------------------------------
-- Hook and modify native frame properties
-- Use for skinning or minor changes

--- Modify a native frame's properties
-- @param nativeFrame Frame: The native frame to modify
-- @param options table: Properties to modify
--   - scale number: Frame scale
--   - alpha number: Frame alpha (0-1)
--   - strata string: Frame strata
-- @return table: Backup of original values
function NativeFrame:Modify(nativeFrame, options)
    if not nativeFrame then
        return nil
    end
    options = options or {}

    local backup = {}

    if options.scale then
        backup.scale = nativeFrame:GetScale()
        nativeFrame:SetScale(options.scale)
    end

    if options.alpha then
        backup.alpha = nativeFrame:GetAlpha()
        nativeFrame:SetAlpha(options.alpha)
    end

    if options.strata then
        backup.strata = nativeFrame:GetFrameStrata()
        nativeFrame:SetFrameStrata(options.strata)
    end

    self.modified[nativeFrame] = backup

    return backup
end

--- Restore a modified frame to original state
-- @param nativeFrame Frame: The frame to restore
-- @return boolean: true if successful
function NativeFrame:RestoreModified(nativeFrame)
    if not nativeFrame then
        return false
    end

    local backup = self.modified[nativeFrame]
    if not backup then
        return false
    end

    if backup.scale then
        nativeFrame:SetScale(backup.scale)
    end
    if backup.alpha then
        nativeFrame:SetAlpha(backup.alpha)
    end
    if backup.strata then
        nativeFrame:SetFrameStrata(backup.strata)
    end

    self.modified[nativeFrame] = nil

    return true
end

-- [ SCENARIO 4: PROTECT (Keep Events, Hide Visuals) ]-----------------------------------------------
-- Moves frame off-screen, sets alpha 0, disables mouse.
-- Crucially, it KEEPS the frame "Shown" (IsShown() == true) so that
-- Blizzard logic (like Resources/CastBars) attached to it continues to function.

--- Protect a native frame (hide visuals, keep logic)
-- @param nativeFrame Frame: The frame to protect
-- @return boolean: true if successful
function NativeFrame:Protect(nativeFrame)
    if not nativeFrame then
        return false
    end

    -- already protected?
    if self.protected and self.protected[nativeFrame] then
        return true
    end

    -- Store basic backup
    local backup = {
        alpha = nativeFrame:GetAlpha(),
        mouse = nativeFrame:IsMouseEnabled(),
        clamped = nativeFrame:IsClampedToScreen(),
    }

    -- 1. Unclamp
    nativeFrame:SetClampedToScreen(false)
    nativeFrame:SetClampRectInsets(0, 0, 0, 0)

    -- 2. Move Offscreen
    nativeFrame:ClearAllPoints()
    nativeFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)

    -- 3. Invisible but Shown
    nativeFrame:SetAlpha(0)

    -- 4. No Interaction
    nativeFrame:EnableMouse(false)

    -- 5. Hook SetPoint to prevent return
    if not nativeFrame.orbitProtectedHook then
        -- Prevent movement
        hooksecurefunc(nativeFrame, "SetPoint", function(f)
            if InCombatLockdown() then
                return
            end
            if not f.isMovingOffscreen then
                f.isMovingOffscreen = true
                f:ClearAllPoints()
                f:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
                f.isMovingOffscreen = false
            end
        end)

        -- Prevent visibility (Always Alpha 0)
        hooksecurefunc(nativeFrame, "SetAlpha", function(f, a)
            if f.isSettingAlpha then return end
            if a and a ~= 0 then
                f.isSettingAlpha = true
                f:SetAlpha(0)
                f.isSettingAlpha = false
            end
        end)

        nativeFrame.orbitProtectedHook = true
    end

    self.protected[nativeFrame] = backup

    return true
end

-- [ SCENARIO 5: SECURE HIDE (No Taint) ]------------------------------------------------------------
-- Hides a secure frame using visibility driver to avoid taint.
-- Does NOT move offscreen or modify properties directly.
-- @param nativeFrame Frame: The secure frame to hide
-- @return boolean: true if successful
function NativeFrame:SecureHide(nativeFrame)
    if not nativeFrame then
        return false
    end
    if InCombatLockdown() then
        return false
    end -- Cannot register driver in combat

    -- Unregister existing driver if any
    UnregisterStateDriver(nativeFrame, "visibility")

    -- Register hide driver
    RegisterStateDriver(nativeFrame, "visibility", "hide")

    return true
end

-- [ UTILITIES ]-------------------------------------------------------------------------------------

--- Check if a native frame has been hidden by Orbit
-- @param nativeFrame Frame: The frame to check
-- @return boolean: true if hidden by Orbit
function NativeFrame:IsHidden(nativeFrame)
    return self.hidden[nativeFrame] ~= nil
end

--- Check if a native frame has been disabled by Orbit
-- @param nativeFrame Frame: The frame to check
-- @return boolean: true if disabled by Orbit
function NativeFrame:IsDisabled(nativeFrame)
    return self.disabled[nativeFrame] ~= nil
end

--- Check if a native frame has been protected by Orbit
-- @param nativeFrame Frame: The frame to check
-- @return boolean: true if protected by Orbit
function NativeFrame:IsProtected(nativeFrame)
    return self.protected[nativeFrame] ~= nil
end

--- Restore a hidden frame to its original state
-- Warning: May cause taint if called after player interaction
-- @param nativeFrame Frame: The frame to restore
-- @return boolean: true if successful
function NativeFrame:Restore(nativeFrame)
    if not nativeFrame then
        return false
    end

    local backup = self.hidden[nativeFrame]
    if not backup then
        return false
    end

    -- Restore parent
    if backup.parent then
        nativeFrame:SetParent(backup.parent)
    end

    -- Restore scripts
    if backup.onEvent then
        nativeFrame:SetScript("OnEvent", backup.onEvent)
    end
    if backup.onUpdate then
        nativeFrame:SetScript("OnUpdate", backup.onUpdate)
    end

    -- Show if was originally shown
    if backup.shown then
        nativeFrame:Show()
    end

    self.hidden[nativeFrame] = nil

    return true
end

--- Get status information for debugging
-- @return table: Status counts
function NativeFrame:GetStatus()
    local hiddenCount = 0
    local disabledCount = 0
    local modifiedCount = 0

    for _ in pairs(self.hidden) do
        hiddenCount = hiddenCount + 1
    end
    for _ in pairs(self.disabled) do
        disabledCount = disabledCount + 1
    end
    for _ in pairs(self.modified) do
        modifiedCount = modifiedCount + 1
    end
    local protectedCount = 0
    for _ in pairs(self.protected) do
        protectedCount = protectedCount + 1
    end

    return {
        hidden = hiddenCount,
        disabled = disabledCount,
        modified = modifiedCount,
        protected = protectedCount,
    }
end
