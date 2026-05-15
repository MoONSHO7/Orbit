-- [ COLORS TAB ]-------------------------------------------------------------------------------------
-- Textures, color curves, and border colors for the Orbit Options dialog.

local _, Orbit = ...
local L = Orbit.L
local Constants = Orbit.Constants

local Panel = Orbit.OptionsPanel
local CreateGlobalSettingsPlugin = Panel._helpers.CreateGlobalSettingsPlugin
local RefreshAllPreviews = Panel._helpers.RefreshAllPreviews

-- [ HELPERS ]----------------------------------------------------------------------------------------
local ColorsPlugin = CreateGlobalSettingsPlugin("OrbitColors")

-- [ SCHEMA ]-----------------------------------------------------------------------------------------
local function GetColorsSchema()
    local controls = {
        { type = "texture", key = "Texture", label = L.CFG_TEXTURE, default = "Melli", previewColor = { r = 0.8, g = 0.8, b = 0.8 } },
        { type = "texture", key = "OverlayTexture", label = L.CFG_OVERLAY_TEXTURE, default = "None", previewColor = { r = 0.5, g = 0.5, b = 0.5 } },
        {
            type = "texture", key = "AbsorbTexture", label = L.CFG_ABSORB_TEXTURE, default = "Blizzard",
            previewColor = { r = 0.5, g = 0.8, b = 1.0 },
            valueCheckbox = {
                tooltip = L.CFG_ALWAYS_SHOW_ABSORB,
                initialValue = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.AlwaysShowAbsorb or false,
                callback = function(checked)
                    ColorsPlugin:SetSetting(nil, "AlwaysShowAbsorb", checked)
                    Orbit.EventBus:Fire("ORBIT_ABSORB_STYLE_CHANGED")
                end,
            },
        },
        {
            type = "colorcurve", key = "FontColorCurve", label = L.CFG_FONT,
            default = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } },
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "FontColorCurve", val)
                Orbit.Async:Debounce("ColorsPanel_FontColor", function() ColorsPlugin:ApplySettings() end, 0.15)
            end,
        },
        {
            type = "colorcurve", key = "BarColorCurve", label = L.CFG_UNIT_HEALTH,
            default = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.2, a = 1 } } } },
            tooltip = L.CFG_UNIT_HEALTH_TT,
            valueCheckbox = {
                tooltip = L.CFG_UNIT_HEALTH_GRADIENT_TT,
                initialValue = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.UnitHealthUseGradient or false,
                callback = function(checked)
                    ColorsPlugin:SetSetting(nil, "UnitHealthUseGradient", checked)
                    Orbit.Async:Debounce("ColorsPanel_BarColor", function()
                        ColorsPlugin:ApplySettings()
                        RefreshAllPreviews()
                    end, 0.15)
                end,
            },
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "BarColorCurve", val)
                Orbit.Async:Debounce("ColorsPanel_BarColor", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                end, 0.15)
            end,
        },
        {
            type = "colorcurve", key = "UnitFrameBackdropColourCurve", label = L.CFG_BACKGROUND,
            default = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } },
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "UnitFrameBackdropColourCurve", val)
                Orbit.Async:Debounce("ColorsPanel_UnitFrameBg", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                    Orbit.EventBus:Fire("ORBIT_GLOBAL_BACKDROP_CHANGED")
                end, 0.15)
            end,
        },
        {
            type = "solidcolor", key = "BorderColor", label = L.CFG_FRAME_BORDERS,
            visibleIf = function()
                local style = (Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderStyle) or Constants.BorderStyle.Default
                return Constants.BorderStyle.Lookup[style] ~= nil
            end,
            default = { r = 0, g = 0, b = 0, a = 1 },
            tooltip = L.CFG_FRAME_BORDERS_TT,
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "BorderColor", val)
                Orbit.Async:Debounce("ColorsPanel_BorderColor", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                    Orbit.EventBus:Fire("ORBIT_GLOBAL_BORDER_COLOR_CHANGED")
                end, 0.15)
            end,
        },
        {
            type = "solidcolor", key = "IconBorderColor", label = L.CFG_ICON_BORDERS,
            visibleIf = function()
                local style = (Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.IconBorderStyle) or Constants.BorderStyle.Default
                return Constants.BorderStyle.Lookup[style] ~= nil
            end,
            default = { r = 0, g = 0, b = 0, a = 1 },
            tooltip = L.CFG_ICON_BORDERS_TT,
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "IconBorderColor", val)
                Orbit.Async:Debounce("ColorsPanel_IconBorderColor", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                    Orbit.EventBus:Fire("ORBIT_GLOBAL_BORDER_COLOR_CHANGED")
                end, 0.15)
            end,
        },
    }

    return {
        hideNativeSettings = true,
        hideResetButton = false,
        openPluginManager = true,
        controls = controls,
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.Texture = "Melli"

                d.OverlayTexture = "None"
                d.AbsorbTexture = "Blizzard"
                d.AlwaysShowAbsorb = false
                d.UnitHealthUseGradient = false
                d.BarColorCurve = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.2, a = 1 } } } }
                d.UnitFrameBackdropColourCurve = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } }
                d.FontColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } }
                d.BorderColor = { r = 0, g = 0, b = 0, a = 1 }
                d.IconBorderColor = { r = 0, g = 0, b = 0, a = 1 }
            end
            Orbit:Print(L.MSG_COLORS_RESET)
            if Orbit.OptionsPanel then Orbit.OptionsPanel:Refresh() end
        end,
    }
end

-- [ REGISTRATION ]-----------------------------------------------------------------------------------
Panel.Tabs["Colors"] = { plugin = ColorsPlugin, schema = GetColorsSchema }
