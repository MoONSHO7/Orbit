-- [ ORBIT POSITION MANAGER ]------------------------------------------------------------------------
-- Manages frame positions during Edit Mode (ephemeral state, Cancel support)

local _, Orbit = ...
Orbit.Engine.PositionManager = Orbit.Engine.PositionManager or {}
local PositionManager = Orbit.Engine.PositionManager
local ActivePositions, ActiveAnchors, PendingFrames = {}, {}, {}

function PositionManager:SetPosition(frame, point, x, y)
    if not frame then
        return
    end
    local name = frame:GetName()
    if not name then
        return
    end
    if ActivePositions[name] then
        ActivePositions[name].point, ActivePositions[name].x, ActivePositions[name].y = point, x, y
    else
        ActivePositions[name] = { point = point, x = x, y = y }
    end
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
    if ActiveAnchors[name] then
        ActiveAnchors[name].target, ActiveAnchors[name].edge = targetName, edge
        ActiveAnchors[name].padding, ActiveAnchors[name].align = padding, align
    else
        ActiveAnchors[name] = { target = targetName, edge = edge, padding = padding, align = align }
    end
    ActivePositions[name] = nil
end

function PositionManager:MarkDirty(frame)
    if not frame then
        return
    end
    local name = frame:GetName()
    if name then
        PendingFrames[name] = frame
    end
end

function PositionManager:FlushToStorage()
    for name, frame in pairs(PendingFrames) do
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
    table.wipe(PendingFrames)
end

function PositionManager:DiscardChanges()
    table.wipe(ActivePositions)
    table.wipe(ActiveAnchors)
    table.wipe(PendingFrames)
end

function PositionManager:GetPosition(frame)
    if not frame then
        return nil
    end
    return ActivePositions[frame:GetName()] or nil
end

function PositionManager:GetAnchor(frame)
    if not frame then
        return nil
    end
    return ActiveAnchors[frame:GetName()] or nil
end
