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
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local existing = {}
        for _, entry in ipairs(opts) do existing[entry.label] = true end
        local borders = LSM:HashTable("border")
        if borders then
            for name, path in pairs(borders) do
                if not existing[name] and path and path ~= "" and name ~= "None" and not name:match("^Blizzard") then
                    opts[#opts + 1] = { label = name, value = "lsm:" .. name }
                end
            end
        end
    end
    table.sort(opts, function(a, b)
        if a.value == "flat" then return true end
        if b.value == "flat" then return false end
        return a.label < b.label
    end)
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
    local function borderSizeChanged(key, val)
        GlobalPlugin:SetSetting(nil, key, val)
        GlobalPlugin:ApplySettings()
        Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
    end
    if currentStyle == "flat" then
        tinsert(controls, { type = "slider", key = "BorderSize", label = L.CFG_BORDER_SIZE, default = 2, min = 0, max = 5, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderSize", v) end })
    else
        tinsert(controls, { type = "slider", key = "BorderEdgeSize", label = L.CFG_BORDER_EDGE_SIZE, default = 16, min = 1, max = 32, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderEdgeSize", v) end })
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
    if currentIconStyle == "flat" then
        tinsert(controls, { type = "slider", key = "IconBorderSize", label = L.CFG_ICON_BORDER_SIZE, default = 2, min = 0, max = 5, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconBorderSize", v) end })
    else
        tinsert(controls, { type = "slider", key = "IconBorderEdgeSize", label = L.CFG_ICON_BORDER_EDGE_SIZE, default = 16, min = 1, max = 32, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconBorderEdgeSize", v) end })
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
            end
            Orbit:Print(L.MSG_GLOBAL_RESET)
        end,
    }
end

-- [ REGISTRATION ]-----------------------------------------------------------------------------------
Panel.Tabs["Global"] = { plugin = GlobalPlugin, schema = GetGlobalSchema }
