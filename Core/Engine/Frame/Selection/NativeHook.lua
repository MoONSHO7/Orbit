-- [ ORBIT SELECTION - NATIVE FRAME HOOKS ]---------------------------------------------------------
-- Hooks into Blizzard's Edit Mode selection system

local _, Orbit = ...
local Engine = Orbit.Engine

local NativeHook = {}
Engine.SelectionNativeHook = NativeHook

NativeHook.hooked = false

-- [ HOOK NATIVE EDIT MODE SELECTION ]--------------------------------------------------------------

function NativeHook:Hook(Selection)
    if not EditModeManagerFrame then
        return
    end
    if self.hooked then
        return
    end
    self.hooked = true

    hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(_, systemFrame)
        if systemFrame then
            -- Deselect all Orbit frames
            Selection:DeselectAll()
            Selection:SetSelectedFrame(systemFrame, true)
            Selection:EnableKeyboardNudge()

            -- CHECK: Is this a native system managed by Orbit? (e.g. MicroMenu)
            -- systemFrame.system is the ID, systemFrame.systemIndex is the index
            local systemID = systemFrame.system
            local plugin = Orbit:GetPlugin(systemID)

            if plugin and Orbit.SettingsDialog then
                -- Yes, Orbit manages this native frame. Take over!

                -- 1. Close native dialog (it opens automatically on native click)
                if EditModeSystemSettingsDialog then
                    EditModeSystemSettingsDialog:Hide()
                end

                -- 2. Open Orbit Dialog
                local context = {
                    system = systemID, -- Pass the ID (number) so GetPlugin works
                    systemIndex = systemFrame.systemIndex or systemID,
                    systemFrame = systemFrame,
                }
                Orbit.SettingsDialog:UpdateDialog(context)
                Orbit.SettingsDialog:Show()
                Orbit.SettingsDialog:PositionNearButton()
            elseif Orbit.SettingsDialog and Orbit.SettingsDialog:IsShown() then
                -- No, it's a pure native frame. Hide Orbit dialog.
                Orbit.SettingsDialog:Hide()
            end
        end
    end)

    hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
        if Selection.isNativeFrame then
            Selection:DisableKeyboardNudge()
        end
    end)
end
