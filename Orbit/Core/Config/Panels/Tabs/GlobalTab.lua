-- [ GLOBAL TAB ]-------------------------------------------------------------------------------------
-- Font, border, and icon border settings for the Orbit Options dialog.

local _, Orbit = ...
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local Constants = Orbit.Constants

local Panel = Orbit.OptionsPanel
local CreateGlobalSettingsPlugin = Panel._helpers.CreateGlobalSettingsPlugin

-- [ HELPERS ]----------------------------------------------------------------------------------------
local GlobalPlugin = CreateGlobalSettingsPlugin("OrbitGlobal")

local function GetBorderStyleOptions()
    local opts = {}
    for _, entry in ipairs(Constants.BorderStyle.Styles) do
        opts[#opts + 1] = entry
    end
    local existing = {}
    for _, entry in ipairs(opts) do existing[entry.label] = true end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local lsm = {}
    if LSM then
        local borders = LSM:HashTable("border")
        if borders then
            for name, path in pairs(borders) do
                if not existing[name] and path and path ~= "" and name ~= "None" and not name:match("^Blizzard") then
                    lsm[#lsm + 1] = { label = name, value = "lsm:" .. name }
                end
            end
        end
    end
    table.sort(lsm, function(a, b) return a.label < b.label end)
    for _, entry in ipairs(lsm) do
        opts[#opts + 1] = entry
    end
    return opts
end

-- [ SCHEMA ]-----------------------------------------------------------------------------------------
local function GetGlobalSchema()
    local controls = {
        { type = "font", key = "Font", label = L.CFG_FONT, default = "PT Sans Narrow" },
        {
            type = "dropdown", key = "FontOutline", label = L.CFG_FONT_OUTLINE,
            options = {
                { label = L.CFG_OUTLINE_OPT_NONE, value = "" }, { label = L.CFG_OUTLINE_OPT_OUTLINE, value = "OUTLINE" },
                { label = L.CFG_OUTLINE_OPT_THICK, value = "THICKOUTLINE" }, { label = L.CFG_OUTLINE_OPT_MONO, value = "MONOCHROME" },
            },
            default = "OUTLINE",
            valueCheckbox = {
                tooltip = L.CFG_TEXT_SHADOW,
                initialValue = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.FontShadow or false,
                callback = function(checked)
                    GlobalPlugin:SetSetting(nil, "FontShadow", checked)
                    GlobalPlugin:ApplySettings()
                end,
            },
        },
        {
            type = "dropdown", key = "BorderStyle", label = L.CFG_BORDER_STYLE, options = GetBorderStyleOptions(), default = Constants.BorderStyle.Default,
            onChange = function(val)
                GlobalPlugin:SetSetting(nil, "BorderStyle", val)
                GlobalPlugin:ApplySettings()
                Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
                local dialog = Orbit.SettingsDialog
                if dialog and dialog.OrbitPanel and dialog.OrbitPanel.Tabs then
                    local oldTab = dialog.OrbitPanel.Tabs["Global"]
                    if oldTab then
                        Layout:Reset(oldTab)
                        oldTab:Hide()
                    end
                    dialog.OrbitPanel.Tabs["Global"] = nil
                end
                Panel.lastTab = nil
                Panel:Open("Global")
            end,
        },
    }

    local currentStyle = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderStyle or Constants.BorderStyle.Default
    local currentEntry = Constants.BorderStyle.Lookup[currentStyle]
    local function borderSizeChanged(key, val)
        GlobalPlugin:SetSetting(nil, key, val)
        GlobalPlugin:ApplySettings()
        Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
    end
    local thicknessLabels = { L.CFG_THICKNESS_SLIM, L.CFG_THICKNESS_MEDIUM, L.CFG_THICKNESS_THICK }
    local function thicknessFormatter(v) return thicknessLabels[v] or tostring(v) end
    local roundnessLabels = { L.CFG_ROUNDNESS_SUBTLE, L.CFG_ROUNDNESS_ROUND, L.CFG_ROUNDNESS_HEAVY }
    local function roundnessFormatter(v) return roundnessLabels[v] or tostring(v) end
    if currentEntry and currentEntry.sliceMargin then
        tinsert(controls, { type = "slider", key = "RoundedThickness", label = L.CFG_BORDER_THICKNESS, default = 2, min = 1, max = 3, step = 1, formatter = thicknessFormatter, updateOnRelease = true, onChange = function(v) borderSizeChanged("RoundedThickness", v) end })
        tinsert(controls, { type = "slider", key = "RoundedCorner", label = L.CFG_BORDER_ROUNDNESS, default = 2, min = 1, max = 3, step = 1, formatter = roundnessFormatter, updateOnRelease = true, onChange = function(v) borderSizeChanged("RoundedCorner", v) end })
    elseif currentStyle == "flat" then
        tinsert(controls, { type = "slider", key = "BorderSize", label = L.CFG_BORDER_SIZE, default = 2, min = 0, max = 5, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderSize", v) end })
    else
        tinsert(controls, { type = "slider", key = "BorderEdgeSize", label = L.CFG_BORDER_EDGE_SIZE, default = 16, min = 4, max = 16, step = 4, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderEdgeSize", v) end })
        tinsert(controls, { type = "slider", key = "BorderOffset", label = L.CFG_BORDER_OFFSET, default = 0, min = 0, max = 16, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderOffset", v) end })
    end

    tinsert(controls, {
        type = "dropdown", key = "IconBorderStyle", label = L.CFG_ICON_BORDER_STYLE, options = GetBorderStyleOptions(), default = Constants.BorderStyle.Default,
        onChange = function(val)
            GlobalPlugin:SetSetting(nil, "IconBorderStyle", val)
            GlobalPlugin:ApplySettings()
            Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
            local dialog = Orbit.SettingsDialog
            if dialog and dialog.OrbitPanel and dialog.OrbitPanel.Tabs then
                local oldTab = dialog.OrbitPanel.Tabs["Global"]
                if oldTab then Layout:Reset(oldTab); oldTab:Hide()
                    dialog.OrbitPanel.Tabs["Global"] = nil
                end
                Panel.lastTab = nil
                Panel:Open("Global")
            end
        end,
    })

    local currentIconStyle = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.IconBorderStyle or Constants.BorderStyle.Default
    local currentIconEntry = Constants.BorderStyle.Lookup[currentIconStyle]
    if currentIconEntry and currentIconEntry.sliceMargin then
        tinsert(controls, { type = "slider", key = "IconRoundedThickness", label = L.CFG_ICON_BORDER_THICKNESS, default = 2, min = 1, max = 3, step = 1, formatter = thicknessFormatter, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconRoundedThickness", v) end })
        tinsert(controls, { type = "slider", key = "IconRoundedCorner", label = L.CFG_ICON_BORDER_ROUNDNESS, default = 2, min = 1, max = 3, step = 1, formatter = roundnessFormatter, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconRoundedCorner", v) end })
    elseif currentIconStyle == "flat" then
        tinsert(controls, { type = "slider", key = "IconBorderSize", label = L.CFG_ICON_BORDER_SIZE, default = 2, min = 0, max = 5, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconBorderSize", v) end })
    else
        tinsert(controls, { type = "slider", key = "IconBorderEdgeSize", label = L.CFG_ICON_BORDER_EDGE_SIZE, default = 16, min = 4, max = 16, step = 4, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconBorderEdgeSize", v) end })
        tinsert(controls, { type = "slider", key = "IconBorderOffset", label = L.CFG_ICON_BORDER_OFFSET, default = 0, min = 0, max = 16, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconBorderOffset", v) end })
    end


    return {
        hideNativeSettings = true,
        hideResetButton = false,
        openPluginManager = true,
        controls = controls,
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.Font = "PT Sans Narrow"
                d.FontOutline = "OUTLINE"
                d.FontShadow = false
                d.BorderSize = 2
                d.BorderStyle = Constants.BorderStyle.Default
                d.BorderEdgeSize = 16
                d.BorderOffset = 0
                d.IconBorderStyle = Constants.BorderStyle.Default
                d.IconBorderSize = 2
                d.IconBorderEdgeSize = 16
                d.IconBorderOffset = 0
                d.RoundedThickness = 2
                d.IconRoundedThickness = 2
                d.RoundedCorner = 2
                d.IconRoundedCorner = 2
            end
            Orbit:Print(L.MSG_GLOBAL_RESET)
        end,
    }
end

-- [ REGISTRATION ]-----------------------------------------------------------------------------------
Panel.Tabs["Global"] = { plugin = GlobalPlugin, schema = GetGlobalSchema }
