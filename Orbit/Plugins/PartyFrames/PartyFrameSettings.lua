-- [ PARTY FRAME SETTINGS ]--------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local SB = OrbitEngine.SchemaBuilder

-- [ ADD SETTINGS ]----------------------------------------------------------------------------------
function Orbit.PartyFrameSettings(plugin, dialog, systemFrame)
    local MOC = function(key, pre) return SB:MakePluginOnChange(plugin, 1, key, pre) end
    local orientation = plugin:GetSetting(1, "Orientation") or 0
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, plugin, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Auras", "Indicators" }, "Layout")

    if currentTab == "Layout" then
        table.insert(schema.controls, {
            type = "dropdown", key = "Orientation", label = "Orientation", default = 0,
            options = { { text = "Vertical", value = 0 }, { text = "Horizontal", value = 1 } },
            onChange = function(val)
                plugin:SetSetting(1, "Orientation", val)
                plugin:SetSetting(1, "GrowthDirection", val == 0 and "Down" or "Right")
                plugin:ApplySettings()
                if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:SchedulePreviewUpdate() end
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end,
        })
        local growthOptions = orientation == 0 and { { text = "Down", value = "Down" }, { text = "Up", value = "Up" } }
            or { { text = "Right", value = "Right" }, { text = "Left", value = "Left" } }
        table.insert(schema.controls, { type = "dropdown", key = "GrowthDirection", label = "Growth Direction", default = orientation == 0 and "Down" or "Right", options = growthOptions, onChange = MOC("GrowthDirection") })
        table.insert(schema.controls, { type = "slider", key = "Width", label = "Width", min = 50, max = 400, step = 1, default = 160, onChange = MOC("Width") })
        table.insert(schema.controls, { type = "slider", key = "Height", label = "Height", min = 10, max = 100, step = 1, default = 40, onChange = MOC("Height") })
        table.insert(schema.controls, { type = "slider", key = "Spacing", label = "Spacing", min = -5, max = 50, step = 1, default = 0, onChange = MOC("Spacing") })
        table.insert(schema.controls, {
            type = "dropdown", key = "HealthTextMode", label = "Health Text", default = "percent_short",
            options = {
                { text = "Percentage", value = "percent" }, { text = "Short Health", value = "short" },
                { text = "Raw Health", value = "raw" }, { text = "Short - Percentage", value = "short_and_percent" },
                { text = "Percentage / Short", value = "percent_short" }, { text = "Percentage / Raw", value = "percent_raw" },
                { text = "Short / Percentage", value = "short_percent" }, { text = "Short / Raw", value = "short_raw" },
                { text = "Raw / Short", value = "raw_short" }, { text = "Raw / Percentage", value = "raw_percent" },
            },
            onChange = MOC("HealthTextMode"),
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "IncludePlayer", label = "Include Player", default = false,
            onChange = MOC("IncludePlayer", function()
                if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:ShowPreview() else plugin:UpdateFrameUnits() end
            end),
        })
        table.insert(schema.controls, { type = "checkbox", key = "ShowPowerBar", label = "Show Power Bar", default = true, onChange = MOC("ShowPowerBar") })
    elseif currentTab == "Indicators" then
        local dispelRefresh = function() if plugin.UpdateAllDispelIndicators then plugin:UpdateAllDispelIndicators(plugin) end end
        table.insert(schema.controls, { type = "checkbox", key = "DispelIndicatorEnabled", label = "Enable Dispel Indicators", default = true, onChange = MOC("DispelIndicatorEnabled", dispelRefresh) })
        table.insert(schema.controls, { type = "slider", key = "DispelThickness", label = "Dispel Border Thickness", default = 2, min = 1, max = 5, step = 1, onChange = MOC("DispelThickness", dispelRefresh) })
        table.insert(schema.controls, { type = "slider", key = "DispelFrequency", label = "Dispel Animation Speed", default = 0.25, min = 0.1, max = 1.0, step = 0.05, onChange = MOC("DispelFrequency", dispelRefresh) })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, plugin, schema)
end
