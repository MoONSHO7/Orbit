-- [ ORBIT POSITION MANAGER ]------------------------------------------------------------------------
-- Manages frame positions during Edit Mode to prevent excessive
-- SavedVariables writes and allow for "Cancel" operations.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.PositionManager = Engine.PositionManager or {}
local PositionManager = Engine.PositionManager

-- Ephemeral session-only state
local ActivePositions = {} -- { [frameName] = { point, relativeTo, relativePoint, x, y } }
local ActiveAnchors = {} -- { [frameName] = { target, edge, padding, align } }
local PendingFrames = {} -- Dirty flag set

-- [ PUBLIC API ]------------------------------------------------------------------------------------

function PositionManager:SetPosition(frame, point, x, y)
    if not frame then
        return
    end

    local name = frame:GetName()
    if not name then
        return
    end

    -- Store normalized position (recycle table if exists)
    if ActivePositions[name] then
        local t = ActivePositions[name]
        t.point = point
        t.x = x
        t.y = y
    else
        ActivePositions[name] = {
            point = point,
            x = x,
            y = y,
        }
    end

    -- Clear any conflicting anchor
    ActiveAnchors[name] = nil
end

function PositionManager:SetAnchor(frame, target, edge, padding, align)
    if not frame then
        return
    end

    local name = frame:GetName()
    if not name then
        return
    end

    local targetName = type(target) == "table" and target:GetName() or target

    -- Store anchor (recycle table if exists)
    if ActiveAnchors[name] then
        local t = ActiveAnchors[name]
        t.target = targetName
        t.edge = edge
        t.padding = padding
        t.align = align
    else
        ActiveAnchors[name] = {
            target = targetName,
            edge = edge,
            padding = padding,
            align = align,
        }
    end

    -- Clear any conflicting position
    ActivePositions[name] = nil
end

function PositionManager:MarkDirty(frame)
    if not frame then
        return
    end
    local name = frame:GetName()
    if not name then
        return
    end

    -- Use frame NAME as key to allow garbage collection of frame objects
    -- Store the frame reference as value for FlushToStorage to use
    PendingFrames[name] = frame
end

function PositionManager:FlushToStorage()
    -- Copy dirty frames to persistent storage
    for name, frame in pairs(PendingFrames) do
        -- Validate frame is still valid (not destroyed/recreated)
        if frame and frame.orbitPlugin and frame.orbitPlugin.SetSetting then
            local systemIndex = frame.systemIndex or 1

            if ActiveAnchors[name] then
                frame.orbitPlugin:SetSetting(systemIndex, "Anchor", ActiveAnchors[name])
                frame.orbitPlugin:SetSetting(systemIndex, "Position", nil)
            elseif ActivePositions[name] then
                frame.orbitPlugin:SetSetting(systemIndex, "Position", ActivePositions[name])
                frame.orbitPlugin:SetSetting(systemIndex, "Anchor", false)
            end
        end
    end

    -- Clear dirty flags
    table.wipe(PendingFrames)
end

function PositionManager:DiscardChanges()
    -- Clear ephemeral state without saving
    table.wipe(ActivePositions)
    table.wipe(ActiveAnchors)
    table.wipe(PendingFrames)
end

function PositionManager:GetPosition(frame)
    -- Helper to read from ephemeral state if it exists
    if not frame then
        return nil
    end
    local name = frame:GetName()

    if ActivePositions[name] then
        return ActivePositions[name]
    end

    return nil
end

function PositionManager:GetAnchor(frame)
    if not frame then
        return nil
    end
    local name = frame:GetName()

    if ActiveAnchors[name] then
        return ActiveAnchors[name]
    end

    return nil
end
