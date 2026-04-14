-- [ ORBIT POSITION MANAGER ]------------------------------------------------------------------------
-- Manages frame positions during Edit Mode (ephemeral state, Cancel support)

local _, Orbit = ...
Orbit.Engine.PositionManager = Orbit.Engine.PositionManager or {}
local PositionManager = Orbit.Engine.PositionManager
local ActivePositions, ActiveAnchors, PendingFrames = {}, {}, {}

function PositionManager:SetPosition(frame, point, x, y)
    if not frame then return end
    local name = frame:GetName()
    if not name then return end
    if ActivePositions[name] then
        ActivePositions[name].point, ActivePositions[name].x, ActivePositions[name].y = point, x, y
    else
        ActivePositions[name] = { point = point, x = x, y = y }
    end
    ActiveAnchors[name] = nil
end

function PositionManager:SetAnchor(frame, target, edge, padding, align, fallback)
    if not frame then return end
    local name = frame:GetName()
    if not name then return end
    local targetName = type(target) == "table" and target:GetName() or target
    if ActiveAnchors[name] then
        ActiveAnchors[name].target, ActiveAnchors[name].edge = targetName, edge
        ActiveAnchors[name].padding, ActiveAnchors[name].align = padding, align
        ActiveAnchors[name].fallback = fallback
    else
        ActiveAnchors[name] = { target = targetName, edge = edge, padding = padding, align = align, fallback = fallback }
    end
    ActivePositions[name] = nil
end

function PositionManager:MarkDirty(frame)
    if not frame then return end
    local name = frame:GetName()
    if name then
        PendingFrames[name] = frame
    end
end

-- Persistence:WriteAnchor / WritePosition handle the spec-vs-global routing
-- (built-in spec-scoped plugins, per-spec target frames, sticky free-position
-- writes). Centralizing the routing here means FlushToStorage just chooses
-- between anchor and position and lets Persistence decide which store to hit.
function PositionManager:FlushToStorage()
    local Persistence = Orbit.Engine.FramePersistence
    for name, frame in pairs(PendingFrames) do
        if frame and frame.orbitPlugin then
            local systemIndex = frame.systemIndex or 1
            local plugin = frame.orbitPlugin
            if ActiveAnchors[name] then
                Persistence:WriteAnchor(plugin, systemIndex, ActiveAnchors[name])
            elseif ActivePositions[name] then
                Persistence:WritePosition(plugin, systemIndex, ActivePositions[name])
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
    if not frame then return nil end
    return ActivePositions[frame:GetName()] or nil
end

function PositionManager:GetAnchor(frame)
    if not frame then return nil end
    return ActiveAnchors[frame:GetName()] or nil
end

function PositionManager:ClearFrame(frame)
    local name = frame and frame:GetName()
    if not name then return end
    ActivePositions[name] = nil
    ActiveAnchors[name] = nil
    PendingFrames[name] = nil
end
