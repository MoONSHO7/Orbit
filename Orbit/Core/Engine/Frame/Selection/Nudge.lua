-- [ ORBIT SELECTION - KEYBOARD NUDGE ]-------------------------------------------------------------
-- Handles keyboard arrow key nudging for both Orbit and native frames

local _, Orbit = ...
local Engine = Orbit.Engine

local Nudge = {}
Engine.SelectionNudge = Nudge

-------------------------------------------------
-- KEYBOARD HANDLER
-------------------------------------------------

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
                
                -- Execute nudge
                if Selection.isNativeFrame then
                    Nudge:NudgeNativeFrame(Selection.selectedFrame, key, Selection)
                else
                    Nudge:NudgeFrame(Selection.selectedFrame, key, Selection)
                end
                
                -- Start repeat using shared module
                local direction = key
                Engine.NudgeRepeat:Start(
                    function()
                        if Selection.isNativeFrame then
                            Nudge:NudgeNativeFrame(Selection.selectedFrame, direction, Selection)
                        else
                            Nudge:NudgeFrame(Selection.selectedFrame, direction, Selection)
                        end
                    end,
                    function()
                        return Selection.selectedFrame ~= nil
                    end
                )
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

-------------------------------------------------
-- ORBIT FRAME NUDGE
-------------------------------------------------

function Nudge:NudgeFrame(frame, direction, Selection)
    if not frame then
        return
    end

    -- Block nudging frames in Component Edit mode
    if Engine.ComponentEdit and Engine.ComponentEdit:IsActive(frame) then
        return
    end

    -- Block nudging anchored frames (they follow their parent)
    if Engine.FrameAnchor and Engine.FrameAnchor:GetAnchorParent(frame) then
        return
    end

    -- Get current position
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    if not point then
        point, xOfs, yOfs = "CENTER", 0, 0
        relativeTo = UIParent
        relativePoint = "CENTER"
    end

    -- Apply 1 pixel nudge
    if direction == "UP" then
        yOfs = yOfs + 1
    elseif direction == "DOWN" then
        yOfs = yOfs - 1
    elseif direction == "LEFT" then
        xOfs = xOfs - 1
    elseif direction == "RIGHT" then
        xOfs = xOfs + 1
    end

    -- Reposition frame
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)

    -- Trigger drag callback to persist position
    if Selection.dragCallbacks[frame] then
        Selection.dragCallbacks[frame](frame, point, xOfs, yOfs)
    end

    Selection:UpdateVisuals(frame)

    -- Show position tooltip
    Engine.SelectionTooltip:ShowPosition(frame, Selection)
end

-------------------------------------------------
-- NATIVE FRAME NUDGE
-------------------------------------------------

function Nudge:NudgeNativeFrame(frame, direction, Selection)
    if not frame then
        return
    end

    -- Must have systemInfo to be a native Edit Mode frame
    if not frame.systemInfo then
        return
    end

    -- Block nudging frames in Component Edit mode
    if Engine.ComponentEdit and Engine.ComponentEdit:IsActive(frame) then
        return
    end

    -- Get anchor info from native Edit Mode system
    local anchor = frame.systemInfo.anchorInfo or {}
    local xOffset = anchor.offsetX or 0
    local yOffset = anchor.offsetY or 0

    -- Apply 1 pixel nudge
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
