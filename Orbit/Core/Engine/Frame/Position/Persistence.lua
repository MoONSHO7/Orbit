-- [ ORBIT FRAME PERSISTENCE ]-----------------------------------------------------------------------
-- Handles saving and restoring frame positions and anchors

local _, Orbit = ...
local Engine = Orbit.Engine

---@class OrbitFramePersistence
Engine.FramePersistence = {}
local Persistence = Engine.FramePersistence

-- Restore frame position or anchor from plugin settings
function Persistence:RestorePosition(frame, plugin, systemIndex)
    if not frame or not plugin then
        return false
    end

    -- Safety: Do not restore position while user is actively dragging the frame.
    if frame.orbitIsDragging then
        return false
    end

    -- Safety: Do not attempt to move protected frames during combat
    if InCombatLockdown() and frame:IsProtected() then
        return false
    end

    systemIndex = systemIndex or 1

    -- Try to restore ephemeral state first (Edit Mode Dirty State)
    if Engine.PositionManager then
        local anchor = Engine.PositionManager:GetAnchor(frame)
        if anchor and anchor.target then
            local targetFrame = _G[anchor.target]
            if targetFrame then
                Engine.FrameAnchor:CreateAnchor(frame, targetFrame, anchor.edge, anchor.padding or 0, nil, anchor.align, true)
                return true
            end
        end

        local pos = Engine.PositionManager:GetPosition(frame)
        if pos and pos.point then
            local x, y = pos.x, pos.y
            if Engine.Pixel then
                local scale = frame:GetEffectiveScale()
                local point = pos.point
                if not point:match("LEFT") and not point:match("RIGHT") then
                    local w = frame:GetWidth()
                    x = Engine.Pixel:Snap(x - (w / 2), scale) + (w / 2)
                else
                    x = Engine.Pixel:Snap(x, scale)
                end
                if not point:match("TOP") and not point:match("BOTTOM") then
                    local h = frame:GetHeight()
                    y = Engine.Pixel:Snap(y - (h / 2), scale) + (h / 2)
                else
                    y = Engine.Pixel:Snap(y, scale)
                end
            end
            frame:ClearAllPoints()
            frame:SetPoint(pos.point, x, y)
            return true
        end
    end

    -- Try to restore SavedVariables Anchor first
    local anchor = plugin:GetSetting(systemIndex, "Anchor")
    if anchor and anchor.target then
        local targetFrame = _G[anchor.target]
        if targetFrame then
            Engine.FrameAnchor:CreateAnchor(frame, targetFrame, anchor.edge, anchor.padding or 0, nil, anchor.align, true)
            return true
        end
    end

    -- Restore Position
    local pos = plugin:GetSetting(systemIndex, "Position")
    if pos and pos.point then
        local x, y = pos.x, pos.y
        if Engine.Pixel then
            local scale = frame:GetEffectiveScale()
            local point = pos.point
            if not point:match("LEFT") and not point:match("RIGHT") then
                local w = frame:GetWidth()
                x = Engine.Pixel:Snap(x - (w / 2), scale) + (w / 2)
            else
                x = Engine.Pixel:Snap(x, scale)
            end
            if not point:match("TOP") and not point:match("BOTTOM") then
                local h = frame:GetHeight()
                y = Engine.Pixel:Snap(y - (h / 2), scale) + (h / 2)
            else
                y = Engine.Pixel:Snap(y, scale)
            end
        end
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, x, y)
        return true
    end

    -- Fallback: Reset to Default Position
    if frame.defaultPosition then
        local x = frame.defaultPosition.x
        local y = frame.defaultPosition.y
        if Engine.Pixel then
            local scale = frame:GetEffectiveScale()
            local point = frame.defaultPosition.point
            if not point:match("LEFT") and not point:match("RIGHT") then
                local w = frame:GetWidth()
                x = Engine.Pixel:Snap(x - (w / 2), scale) + (w / 2)
            else
                x = Engine.Pixel:Snap(x, scale)
            end
            if not point:match("TOP") and not point:match("BOTTOM") then
                local h = frame:GetHeight()
                y = Engine.Pixel:Snap(y - (h / 2), scale) + (h / 2)
            else
                y = Engine.Pixel:Snap(y, scale)
            end
        end

        frame:ClearAllPoints()
        frame:SetPoint(frame.defaultPosition.point, frame.defaultPosition.relativeTo, frame.defaultPosition.relativePoint, x, y)
        return true
    end

    return false
end

-- Attach listener for standard Orbit position/anchor saving
function Persistence:AttachSettingsListener(frame, plugin, systemIndex)
    if not frame or not plugin then
        return
    end
    systemIndex = systemIndex or 1

    -- Ensure the frame identifies its system for plugin lookup
    if not frame.system then
        frame.system = plugin.system or plugin.name
    end

    -- Ensure PositionManager has access to the plugin for saving
    -- (Fixes data loss for frames created manually without FrameFactory)
    frame.orbitPlugin = plugin
    frame.systemIndex = systemIndex

    -- Shared logic to refresh dialog (Trailing Debounce)
    local refreshTimer
    local function RefreshDialog()
        -- Reset timer on every call (Trailing Debounce)
        -- We only update the dialog when the user STOPS moving/nudging for 0.2s
        if refreshTimer then
            refreshTimer:Cancel()
        end

        refreshTimer = C_Timer.NewTimer(0.2, function()
            refreshTimer = nil
            -- Use Orbit's own settings dialog instead of Blizzard's
            if Orbit.SettingsDialog and Orbit.SettingsDialog:IsShown() then
                -- Only refresh if this frame is currently selected
                if Engine.FrameSelection:GetSelectedFrame() == frame then
                    local context = {
                        system = plugin.name or frame.orbitName,
                        systemIndex = systemIndex,
                        systemFrame = frame,
                    }
                    if plugin.system then
                        context.system = plugin.system
                    end
                    Orbit.SettingsDialog:UpdateDialog(context)
                end
            end
        end)
    end

    Engine.FrameSelection:Attach(frame, function(f, point, x, y)
        -- Save position or anchor state via PositionManager (ephemeral)
        if Engine.PositionManager then
            if point == "ANCHORED" then
                -- Retrieve padding/align from anchor to pass to PositionManager
                local padding = 0
                local align = nil
                if Engine.FrameAnchor and Engine.FrameAnchor.anchors[f] then
                    padding = Engine.FrameAnchor.anchors[f].padding or 0
                    align = Engine.FrameAnchor.anchors[f].align
                end
                Engine.PositionManager:SetAnchor(f, x, y, padding, align)
            else
                Engine.PositionManager:SetPosition(f, point, x, y)
            end
            Engine.PositionManager:MarkDirty(f)
        else
            error("Orbit: PositionManager is nil — cannot save frame position")
        end

        -- Refresh settings (e.g. show/hide width/height sliders based on anchor)
        RefreshDialog()
    end, function(f)
        -- Selection callback: Open Orbit's settings dialog
        if Orbit.SettingsDialog then
            -- Deselect any native Blizzard frames first
            if EditModeManagerFrame then
                EditModeManagerFrame:ClearSelectedSystem()
            end

            local context = {
                system = plugin.name or frame.orbitName,
                systemIndex = systemIndex,
                systemFrame = f,
            }
            if plugin.system then
                context.system = plugin.system
            end

            -- Update and show Orbit's dialog
            Orbit.SettingsDialog:UpdateDialog(context)
            Orbit.SettingsDialog:Show()
            Orbit.SettingsDialog:PositionNearButton()
        end
    end)
end
