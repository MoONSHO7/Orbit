-- [ COLORS TAB ]-------------------------------------------------------------------------------------
-- Textures and bar/background color curves for the Orbit Options dialog. Font and border colors
-- live on the Global tab as value-column swatches next to the controls they tint.

local _, Orbit = ...
local L = Orbit.L

local Panel = Orbit.OptionsPanel
local CreateGlobalSettingsPlugin = Panel._helpers.CreateGlobalSettingsPlugin
local RefreshAllPreviews = Panel._helpers.RefreshAllPreviews

-- [ HELPERS ]----------------------------------------------------------------------------------------
local ColorsPlugin = CreateGlobalSettingsPlugin("OrbitColors")

-- [ SCHEMA ]-----------------------------------------------------------------------------------------
local function GetColorsSchema()
    local controls = {
        { type = "texture", key = "Texture", label = L.CFG_TEXTURE, default = "Orbit Gradient Top-Bottom", previewColor = { r = 0.8, g = 0.8, b = 0.8 } },
        { type = "texture", key = "OverlayTexture", label = L.CFG_OVERLAY_TEXTURE, default = "None", previewColor = { r = 0.5, g = 0.5, b = 0.5 }, allowOverlays = true },
        {
            type = "texture", key = "AbsorbTexture", label = L.CFG_ABSORB_TEXTURE, default = "Orbit Absorb",
            previewColor = { r = 0.5, g = 0.8, b = 1.0 },
            valueCheckbox = {
                tooltip = L.CFG_ALWAYS_SHOW_ABSORB,
                initialValue = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.AlwaysShowAbsorb or false,
                callback = function(checked)
                    ColorsPlugin:SetSetting(nil, "AlwaysShowAbsorb", checked)
                    Orbit.EventBus:Fire("ORBIT_ABSORB_STYLE_CHANGED")
                end,
            },
            valueColor = {
                initialValue = function()
                    return (Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.AbsorbColor)
                        or Orbit.Constants.Colors.Absorb
                end,
                callback = function(val)
                    ColorsPlugin:SetSetting(nil, "AbsorbColor", val)
                    Orbit.EventBus:Fire("ORBIT_ABSORB_STYLE_CHANGED")
                end,
            },
        },
        {
            type = "colorcurve", key = "BarColorCurve", label = L.CFG_UNIT_HEALTH,
            default = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.2, a = 1 } } } },
            tooltip = L.CFG_UNIT_HEALTH_TT,
            valueCheckbox = {
                tooltip = function(checked)
                    if checked then
                        return L.CFG_UNIT_HEALTH_GRADIENT_TITLE, L.CFG_UNIT_HEALTH_GRADIENT_DESC
                    end
                    return L.CFG_UNIT_HEALTH_VALUE_TITLE, L.CFG_UNIT_HEALTH_VALUE_DESC
                end,
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
    }

    return {
        hideNativeSettings = true,
        hideResetButton = false,
        openPluginManager = true,
        controls = controls,
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.Texture = "Orbit Gradient Top-Bottom"
                d.OverlayTexture = "None"
                d.AbsorbTexture = "Orbit Absorb"
                d.AlwaysShowAbsorb = false
                d.AbsorbColor = nil
                d.UnitHealthUseGradient = false
                d.BarColorCurve = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.2, a = 1 } } } }
                d.UnitFrameBackdropColourCurve = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } }
            end
            Orbit:Print(L.MSG_COLORS_RESET)
            if Orbit.OptionsPanel then Orbit.OptionsPanel:Refresh() end
        end,
    }
end

-- [ REGISTRATION ]-----------------------------------------------------------------------------------
Panel.Tabs["Textures"] = { plugin = ColorsPlugin, schema = GetColorsSchema }
