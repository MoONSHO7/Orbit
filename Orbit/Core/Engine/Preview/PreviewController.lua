-- [ ORBIT PREVIEW CONTROLLER ]---------------------------------------------------------------------
-- Session management for preview editing.
-- Coordinates callbacks and state between preview frames and the dialog.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.Preview = Engine.Preview or {}
local Preview = Engine.Preview

local PreviewController = {}
Preview.Controller = PreviewController

-- [ STATE ]--------------------------------------------------------------------------------------

local activeSession = nil

local function CopyPosition(pos)
    return { anchorX = pos.anchorX, anchorY = pos.anchorY, offsetX = pos.offsetX, offsetY = pos.offsetY, justifyH = pos.justifyH }
end

-- [ SESSION API ]--------------------------------------------------------------------------------

-- Start a new preview session
-- @param frame: The source frame being edited
-- @param plugin: The plugin owning the frame
-- @param callbacks: { onPositionChange, onApply, onCancel }
-- @return session object
function PreviewController:StartSession(frame, plugin, callbacks)
    -- End any existing session
    if activeSession then
        self:EndSession(activeSession, false)
    end

    local session = {
        frame = frame,
        plugin = plugin,
        callbacks = callbacks or {},
        originalPositions = {}, -- Backup of original positions
        currentPositions = {}, -- Current working positions
        preview = nil, -- Set by dialog after creating preview
        startTime = GetTime(),
    }

    -- Backup original positions
    if plugin and plugin.savedVariables then
        local sv = plugin.savedVariables
        local systemIndex = frame.systemIndex or plugin.system or 1
        if sv.Systems and sv.Systems[systemIndex] and sv.Systems[systemIndex].ComponentPositions then
            for key, pos in pairs(sv.Systems[systemIndex].ComponentPositions) do
                session.originalPositions[key] = CopyPosition(pos)
                session.currentPositions[key] = CopyPosition(pos)
            end
        end
    end

    activeSession = session
    return session
end

-- End the current session
-- @param session: The session to end
-- @param apply: If true, apply changes; if false, discard
function PreviewController:EndSession(session, apply)
    if not session then
        return
    end

    if apply and session.callbacks.onApply then
        session.callbacks.onApply(session.currentPositions)
    elseif not apply and session.callbacks.onCancel then
        session.callbacks.onCancel()
    end

    -- Clear session
    wipe(session.originalPositions)
    wipe(session.currentPositions)
    session.preview = nil

    if activeSession == session then
        activeSession = nil
    end
end

-- Get the active session
function PreviewController:GetActiveSession()
    return activeSession
end

-- Check if a session is active
function PreviewController:IsActive()
    return activeSession ~= nil
end

-- [ POSITION MANAGEMENT ]------------------------------------------------------------------------

-- Update a component's position in the session
-- @param session: The session
-- @param key: Component key
-- @param position: { anchorX, anchorY, offsetX, offsetY, posX, posY, justifyH }
function PreviewController:UpdatePosition(session, key, position)
    if not session or not key then
        return
    end

    session.currentPositions[key] = {
        anchorX = position.anchorX,
        anchorY = position.anchorY,
        offsetX = position.offsetX,
        offsetY = position.offsetY,
        posX = position.posX,
        posY = position.posY,
        justifyH = position.justifyH,
    }

    -- Notify callback
    if session.callbacks.onPositionChange then
        session.callbacks.onPositionChange(key, session.currentPositions[key])
    end
end

-- Get current positions for a session
function PreviewController:GetPositions(session)
    if not session then
        return {}
    end
    return session.currentPositions
end

-- Get original positions for a session (for reset)
function PreviewController:GetOriginalPositions(session)
    if not session then
        return {}
    end
    return session.originalPositions
end

-- Reset positions to original values
function PreviewController:ResetPositions(session)
    if not session then
        return
    end

    for key, pos in pairs(session.originalPositions) do
        session.currentPositions[key] = CopyPosition(pos)
    end

    -- Notify callback
    if session.callbacks.onReset then
        session.callbacks.onReset()
    end
end
