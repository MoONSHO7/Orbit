-- [ EDIT MODE TAB ]---------------------------------------------------------------------------------
-- Edit mode visibility and selection color settings for the Orbit Options dialog.

local _, Orbit = ...
local L = Orbit.L

local Panel = Orbit.OptionsPanel
local CreateGlobalSettingsPlugin = Panel._helpers.CreateGlobalSettingsPlugin

-- [ HELPERS ]---------------------------------------------------------------------------------------

local EditModePlugin = CreateGlobalSettingsPlugin("OrbitEditMode", function(key, value)
    if Orbit.Engine.FrameSelection then Orbit.Engine.FrameSelection:RefreshVisuals() end
end)

EditModePlugin.ApplySettings = function(self, systemFrame) end

-- [ SCHEMA ]----------------------------------------------------------------------------------------

local function GetEditModeSchema()
    return {
        hideNativeSettings = true,
        hideResetButton = false,
        openPluginManager = true,
        controls = {
            { type = "checkbox", key = "ShowBlizzardFrames", label = L.CFG_SHOW_BLIZZARD_FRAMES, default = true, tooltip = L.CFG_SHOW_BLIZZARD_FRAMES_TT },
            { type = "checkbox", key = "ShowOrbitFrames", label = L.CFG_SHOW_ORBIT_FRAMES, default = true, tooltip = L.CFG_SHOW_ORBIT_FRAMES_TT },
            { type = "checkbox", key = "AnchoringEnabled", label = L.CFG_ENABLE_FRAME_ANCHORING, default = true, tooltip = L.CFG_ENABLE_FRAME_ANCHORING_TT },
            {
                type = "colorcurve", key = "EditModeColorCurve", label = L.CFG_ORBIT_FRAME_COLOR,
                default = { pins = { { position = 0, color = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 } } } },
                tooltip = L.CFG_ORBIT_FRAME_COLOR_TT,
            },
        },
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.ShowBlizzardFrames = true
                d.ShowOrbitFrames = true
                d.AnchoringEnabled = true
                d.EditModeColor = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 }
                d.EditModeColorCurve = { pins = { { position = 0, color = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 } } } }
            end
            if Orbit.Engine.FrameSelection then Orbit.Engine.FrameSelection:RefreshVisuals() end
            Orbit:Print(L.MSG_EDITMODE_RESET)
        end,
    }
end

-- [ REGISTRATION ]----------------------------------------------------------------------------------

Panel.Tabs["Edit Mode"] = { plugin = EditModePlugin, schema = GetEditModeSchema }
