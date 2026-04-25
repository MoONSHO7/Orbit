-- [ ORBIT SELECTION - KEYBOARD NUDGE ] --------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

local Nudge = {}
Engine.SelectionNudge = Nudge

-- [ KEYBOARD HANDLER ]-------------------------------------------------------------------------------
function Nudge:Enable(Selection)
    if InCombatLockdown() then
        return
    end

    if not Selection.keyboardHandler then
        Selection.keyboardHandler = CreateFrame("Frame", "OrbitNudgeKeyHandler", UIParent)
        Selection.keyboardHandler:EnableKeyboard(true)
        Selection.keyboardHandler:SetPropagateKeyboardInput(true)

        Selection.keyboardHandler:SetScript("OnKeyDown", function(_, key)
            if InCombatLockdown() then
                return
            end

            if not Selection.selectedFrame then
                Selection.keyboardHandler:SetPropagateKeyboardInput(true)
                return
            end

            if key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
                Selection.keyboardHandler:SetPropagateKeyboardInput(false)

                if Selection.isNativeFrame then
                    Nudge:NudgeNativeFrame(Selection.selectedFrame, key, Selection)
                else
                    Nudge:NudgeFrame(Selection.selectedFrame, key, Selection)
                end

                local direction = key
                Engine.NudgeRepeat:Start(function()
                    if Selection.isNativeFrame then
                        Nudge:NudgeNativeFrame(Selection.selectedFrame, direction, Selection)
                    else
                        Nudge:NudgeFrame(Selection.selectedFrame, direction, Selection)
                    end
                end, function()
                    return Selection.selectedFrame ~= nil
                end)
            else
                Selection.keyboardHandler:SetPropagateKeyboardInput(true)
            end
        end)

        Selection.keyboardHandler:SetScript("OnKeyUp", function(_, key)
            if key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
                Engine.NudgeRepeat:Stop()
            end
        end)
    end
    Selection.keyboardHandler:Show()
end

function Nudge:Disable(Selection)
    if InCombatLockdown() then
        return
    end
    Selection:SetSelectedFrame(nil, false)
    if Selection.keyboardHandler then
        Selection.keyboardHandler:Hide()
    end
    Engine.NudgeRepeat:Stop()
end

-- [ ORBIT FRAME NUDGE ] -----------------------------------------------------------------------------
function Nudge:NudgeFrame(frame, direction, Selection)
    if not frame then
        return
    end

    if Engine.CanvasMode and Engine.CanvasMode:IsActive(frame) then
        return
    end

    -- Anchored frames follow their parent — nudging them would desync the chain.
    if Engine.FrameAnchor and Engine.FrameAnchor:GetAnchorParent(frame) then
        return
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    if not point then
        point, xOfs, yOfs = "CENTER", 0, 0
        relativeTo = UIParent
        relativePoint = "CENTER"
    end

    local Pixel = Engine.Pixel
    local effectiveScale = frame:GetEffectiveScale()
    local step = Pixel and (Pixel:GetScale() / effectiveScale) or 1
    local multiplier = IsShiftKeyDown() and 10 or 1

    local function nudgeAxis(val, dir)
        local idx = math.floor(val / step + 0.5)
        return (idx + dir * multiplier) * step
    end

    if direction == "UP" then yOfs = nudgeAxis(yOfs, 1)
    elseif direction == "DOWN" then yOfs = nudgeAxis(yOfs, -1)
    elseif direction == "LEFT" then xOfs = nudgeAxis(xOfs, -1)
    elseif direction == "RIGHT" then xOfs = nudgeAxis(xOfs, 1)
    end

    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)

    if Selection.dragCallbacks[frame] then
        Selection.dragCallbacks[frame](frame, point, xOfs, yOfs)
    end

    Selection:UpdateVisuals(frame)
    Engine.SelectionTooltip:ShowPosition(frame, Selection)
end

-- [ NATIVE FRAME NUDGE ] ----------------------------------------------------------------------------
function Nudge:NudgeNativeFrame(frame, direction, Selection)
    if not frame then
        return
    end

    if not frame.systemInfo then
        return
    end

    if Engine.CanvasMode and Engine.CanvasMode:IsActive(frame) then
        return
    end

    local anchor = frame.systemInfo.anchorInfo or {}
    local xOffset = anchor.offsetX or 0
    local yOffset = anchor.offsetY or 0

    if direction == "UP" then
        yOffset = yOffset + 1
    elseif direction == "DOWN" then
        yOffset = yOffset - 1
    elseif direction == "LEFT" then
        xOffset = xOffset - 1
    elseif direction == "RIGHT" then
        xOffset = xOffset + 1
    end

    -- Write back into anchorInfo
    anchor.offsetX = xOffset
    anchor.offsetY = yOffset
    frame.systemInfo.anchorInfo = anchor

    -- Flag as dirty so Save button lights up
    frame.hasActiveChanges = true
    if EditModeManagerFrame and EditModeManagerFrame.SetHasActiveChanges then
        EditModeManagerFrame:SetHasActiveChanges(true)
    end

    -- Reposition the frame
    local point = anchor.point or "CENTER"
    local relativeTo = anchor.relativeTo or UIParent
    local relativePoint = anchor.relativePoint or "CENTER"

    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset)

    -- Notify native system of position change
    if frame.OnSystemPositionChange then
        frame:OnSystemPositionChange()
    end

    -- Show position tooltip
    Engine.SelectionTooltip:ShowPosition(frame, Selection)
end
