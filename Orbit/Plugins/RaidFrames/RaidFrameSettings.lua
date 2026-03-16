-- [ RAID FRAME SETTINGS ]---------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local SB = OrbitEngine.SchemaBuilder

-- [ ADD SETTINGS ]----------------------------------------------------------------------------------
function Orbit.RaidFrameSettings(plugin, dialog, systemFrame)
    local MOC = function(key, pre) return SB:MakePluginOnChange(plugin, 1, key, pre) end
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, plugin, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Colors", "Indicators" }, "Layout", plugin)

    if currentTab == "Layout" then
        if (plugin:GetSetting(1, "SortMode") or "Group") == "Group" then
            table.insert(schema.controls, {
                type = "dropdown", key = "Orientation", label = "Orientation", default = "Vertical",
                options = { { text = "Vertical", value = "Vertical" }, { text = "Horizontal", value = "Horizontal" } },
                onChange = MOC("Orientation"),
            })
        end
        table.insert(schema.controls, { type = "dropdown", key = "GrowthDirection", label = "Growth Direction", default = "Down", options = { { text = "Down", value = "Down" }, { text = "Up", value = "Up" } }, onChange = MOC("GrowthDirection") })
        table.insert(schema.controls, {
            type = "dropdown", key = "SortMode", label = "Sort Mode", default = "Group",
            options = { { text = "Group", value = "Group" }, { text = "Role", value = "Role" }, { text = "Alphabetical", value = "Alphabetical" } },
            onChange = function(val)
                plugin:SetSetting(1, "SortMode", val)
                if not InCombatLockdown() then plugin:UpdateFrameUnits(); plugin:PositionFrames() end
                if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:SchedulePreviewUpdate() end
                C_Timer.After(0, function() OrbitEngine.Layout:Reset(dialog); Orbit.RaidFrameSettings(plugin, dialog, systemFrame) end)
            end,
        })
        table.insert(schema.controls, { type = "slider", key = "Width", label = "Width", min = 50, max = 200, step = 1, default = 90, onChange = MOC("Width") })
        table.insert(schema.controls, { type = "slider", key = "Height", label = "Height", min = 20, max = 80, step = 1, default = 36, onChange = MOC("Height") })
        table.insert(schema.controls, { type = "slider", key = "MemberSpacing", label = "Member Spacing", min = 0, max = 50, step = 1, default = 1, onChange = MOC("MemberSpacing") })
        if (plugin:GetSetting(1, "SortMode") or "Group") == "Group" then
            table.insert(schema.controls, { type = "slider", key = "GroupsPerRow", label = "Groups Per Row", min = 1, max = 6, step = 1, default = 6, onChange = MOC("GroupsPerRow") })
            table.insert(schema.controls, { type = "slider", key = "GroupSpacing", label = "Group Spacing", min = 0, max = 50, step = 1, default = 4, onChange = MOC("GroupSpacing") })
        else
            table.insert(schema.controls, { type = "slider", key = "FlatRows", label = "Rows", min = 1, max = 4, step = 1, default = 1, onChange = MOC("FlatRows") })
        end
        table.insert(schema.controls, { type = "checkbox", key = "ShowPowerBar", label = "Show Healer Power Bars", default = true, onChange = MOC("ShowPowerBar") })
        table.insert(schema.controls, { type = "slider", key = "PowerBarHeight", label = "Powerbar Height", min = 5, max = 30, step = 1, default = 8, suffix = "%", onChange = MOC("PowerBarHeight") })
    elseif currentTab == "Colors" then
        table.insert(schema.controls, { type = "color", key = "SelectionColor", label = "Selection Highlight", default = { r = 0.8, g = 0.9, b = 1.0, a = 1 }, onChange = MOC("SelectionColor") })
        table.insert(schema.controls, { type = "color", key = "AggroColor", label = "Aggro Highlight", default = { r = 1.0, g = 0.0, b = 0.0, a = 1 }, onChange = MOC("AggroColor") })
    elseif currentTab == "Indicators" then
        if (plugin:GetSetting(1, "SortMode") or "Group") == "Group" then
            table.insert(schema.controls, { type = "checkbox", key = "ShowGroupLabels", label = "Show Groups", default = true, onChange = MOC("ShowGroupLabels") })
        end
        local dispelRefresh = function() if plugin.UpdateAllDispelIndicators then plugin:UpdateAllDispelIndicators(plugin) end end
        table.insert(schema.controls, { type = "checkbox", key = "DispelIndicatorEnabled", label = "Enable Dispel Indicators", default = true, onChange = MOC("DispelIndicatorEnabled", dispelRefresh) })
        table.insert(schema.controls, { type = "checkbox", key = "DispelOnlyByMe", label = "Only Dispellable By Me", default = false, onChange = MOC("DispelOnlyByMe", dispelRefresh) })
        table.insert(schema.controls, { type = "slider", key = "DispelThickness", label = "Dispel Border Thickness", default = 2, min = 1, max = 5, step = 1, onChange = MOC("DispelThickness", dispelRefresh) })
        table.insert(schema.controls, { type = "slider", key = "DispelFrequency", label = "Dispel Animation Speed", default = 0.25, min = 0.1, max = 1.0, step = 0.05, onChange = MOC("DispelFrequency", dispelRefresh) })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, plugin, schema)
end
