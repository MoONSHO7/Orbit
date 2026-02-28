-- [ GROUP CANVAS REGISTRATION ]--------------------------------------------------------------------
-- Shared canvas mode component registration and icon position application for group frames

local _, Orbit = ...
local OrbitEngine = Orbit.Engine

Orbit.GroupCanvasRegistration = {}
local Reg = Orbit.GroupCanvasRegistration

-- [ REGISTER COMPONENTS ]--------------------------------------------------------------------------
-- Registers text, icon, and aura container components on a group frame container for Canvas Mode.
function Reg:RegisterComponents(plugin, container, firstFrame, textKeys, iconKeys, auraBaseIconSize)
    if not OrbitEngine.ComponentDrag or not firstFrame then return end

    for _, key in ipairs(textKeys) do
        local element = firstFrame[key]
        if element then
            OrbitEngine.ComponentDrag:Attach(element, container, {
                key = key,
                onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(plugin, 1, key),
            })
        end
    end

    for _, key in ipairs(iconKeys) do
        local element = firstFrame[key]
        if element then
            OrbitEngine.ComponentDrag:Attach(element, container, {
                key = key,
                onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(plugin, 1, key),
            })
        end
    end

    for _, key in ipairs({ "Buffs", "Debuffs" }) do
        local containerKey = key == "Buffs" and "buffContainer" or "debuffContainer"
        if not firstFrame[containerKey] then
            firstFrame[containerKey] = CreateFrame("Frame", nil, firstFrame)
            firstFrame[containerKey]:SetSize(auraBaseIconSize, auraBaseIconSize)
        end
        OrbitEngine.ComponentDrag:Attach(firstFrame[containerKey], container, {
            key = key, isAuraContainer = true,
            onPositionChange = OrbitEngine.ComponentDrag:MakeAuraPositionCallback(plugin, 1, key),
        })
    end
end

-- [ APPLY ICON POSITIONS ]-------------------------------------------------------------------------
-- Applies saved component positions to all icon elements on each frame.
function Reg:ApplyIconPositions(frames, savedPositions, iconKeys)
    if not savedPositions then return end
    for _, frame in ipairs(frames) do
        if frame.ApplyComponentPositions then
            frame:ApplyComponentPositions(savedPositions)
        end
        for _, iconKey in ipairs(iconKeys) do
            if frame[iconKey] and savedPositions[iconKey] then
                local pos = savedPositions[iconKey]
                local anchorX = pos.anchorX or "CENTER"
                local anchorY = pos.anchorY or "CENTER"

                local anchorPoint
                if anchorY == "CENTER" and anchorX == "CENTER" then anchorPoint = "CENTER"
                elseif anchorY == "CENTER" then anchorPoint = anchorX
                elseif anchorX == "CENTER" then anchorPoint = anchorY
                else anchorPoint = anchorY .. anchorX end

                local finalX = pos.offsetX or 0
                local finalY = pos.offsetY or 0
                if anchorX == "RIGHT" then finalX = -finalX end
                if anchorY == "TOP" then finalY = -finalY end

                frame[iconKey]:ClearAllPoints()
                frame[iconKey]:SetPoint("CENTER", frame, anchorPoint, finalX, finalY)
            end
        end
    end
end
