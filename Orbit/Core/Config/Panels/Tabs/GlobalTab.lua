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

-- A border-style change adds/removes conditional sliders, so the cached tab is dropped and rebuilt.
local function RebuildGlobalTab()
    local dialog = Orbit.SettingsDialog
    if dialog and dialog.OrbitPanel and dialog.OrbitPanel.Tabs then
        local oldTab = dialog.OrbitPanel.Tabs[L.CFG_TAB_GLOBAL]
        if oldTab then
            Layout:Reset(oldTab)
            oldTab:Hide()
        end
        dialog.OrbitPanel.Tabs[L.CFG_TAB_GLOBAL] = nil
    end
    Panel.lastTab = nil
    Panel:Open(L.CFG_TAB_GLOBAL)
end

local function GetBorderStyleOptions()
    local opts = {}
    for _, entry in ipairs(Constants.BorderStyle.Styles) do
        opts[#opts + 1] = entry
    end
    local existing = {}
    for _, entry in ipairs(opts) do existing[entry.label] = true end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local owned, others = {}, {}
    if LSM then
        local borders = LSM:HashTable("border")
        if borders then
            local ownedMedia = Orbit.OwnedMedia or {}
            for name, path in pairs(borders) do
                if not existing[name] and path and path ~= "" and name ~= "None" and not name:match("^Blizzard") then
                    local bucket = ownedMedia[name] and owned or others
                    bucket[#bucket + 1] = { label = name, value = "lsm:" .. name }
                end
            end
        end
    end
    local byLabel = function(a, b) return a.label < b.label end
    table.sort(owned, byLabel)
    table.sort(others, byLabel)
    -- Orbit-bundled borders sit with the built-in styles; a divider separates third-party LibSharedMedia borders below.
    for _, entry in ipairs(owned) do opts[#opts + 1] = entry end
    if #others > 0 then
        opts[#opts + 1] = { divider = true }
        for _, entry in ipairs(others) do opts[#opts + 1] = entry end
    end
    return opts
end

-- [ SCHEMA ]-----------------------------------------------------------------------------------------
local function GetGlobalSchema()
    local g = Orbit.db and Orbit.db.GlobalSettings
    local currentStyle = (g and g.BorderStyle) or Constants.BorderStyle.Default
    local currentEntry = Constants.BorderStyle.Lookup[currentStyle]
    local currentIconStyle = (g and g.IconBorderStyle) or Constants.BorderStyle.Default
    local currentIconEntry = Constants.BorderStyle.Lookup[currentIconStyle]
    local borderOpts = GetBorderStyleOptions()

    -- Color swatch applies to built-in styles AND to LSM edge-file textures (grayscale -> vertex-tinted).
    local DEFAULT_FONT_CURVE = Orbit.Constants.NewWhiteColorCurve()
    local function GS() return Orbit.db and Orbit.db.GlobalSettings end
    local function StyleHasColor(key)
        local gs = GS()
        local v = (gs and gs[key]) or Constants.BorderStyle.Default
        return Constants.BorderStyle.Lookup[v] ~= nil or (type(v) == "string" and v:find("^lsm:") ~= nil)
    end

    local fontColorValue = {
        curve = true,
        tooltip = L.CFG_FONT_COLOR_TT,
        initialValue = function() local gs = GS(); return (gs and gs.FontColorCurve) or DEFAULT_FONT_CURVE end,
        callback = function(val)
            GlobalPlugin:SetSetting(nil, "FontColorCurve", val)
            Orbit.Async:Debounce("GlobalTab_FontColor", function() GlobalPlugin:ApplySettings() end, 0.15)
        end,
    }
    local borderColorValue = {
        curve = false,
        allowNone = true,
        tooltip = L.CFG_FRAME_BORDERS_TT,
        enabled = function() return StyleHasColor("BorderStyle") end,
        initialValue = function() local gs = GS(); return (gs and gs.BorderColor) or { none = true } end,
        callback = function(val)
            GlobalPlugin:SetSetting(nil, "BorderColor", val)
            Orbit.Async:Debounce("GlobalTab_BorderColor", function()
                GlobalPlugin:ApplySettings()
                Orbit.EventBus:Fire("ORBIT_GLOBAL_BORDER_COLOR_CHANGED")
            end, 0.15)
        end,
    }
    local iconBorderColorValue = {
        curve = false,
        allowNone = true,
        tooltip = L.CFG_ICON_BORDERS_TT,
        enabled = function() return StyleHasColor("IconBorderStyle") end,
        initialValue = function() local gs = GS(); return (gs and gs.IconBorderColor) or { none = true } end,
        callback = function(val)
            GlobalPlugin:SetSetting(nil, "IconBorderColor", val)
            Orbit.Async:Debounce("GlobalTab_IconBorderColor", function()
                GlobalPlugin:ApplySettings()
                Orbit.EventBus:Fire("ORBIT_GLOBAL_BORDER_COLOR_CHANGED")
            end, 0.15)
        end,
    }

    local controls = {
        { type = "font", key = "Font", label = L.CFG_FONT, default = "PT Sans Narrow", valueColor = fontColorValue },
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
            type = "dropdown", key = "BorderStyle", label = L.CFG_BORDER_STYLE, options = borderOpts,
            default = Constants.BorderStyle.Default, valueColor = borderColorValue,
            onChange = function(val)
                GlobalPlugin:SetSetting(nil, "BorderStyle", val)
                -- Re-sync the effective BorderSize before ApplySettings re-skins from it.
                Constants.BorderStyle.SyncEffectiveSize(Orbit.db.GlobalSettings)
                GlobalPlugin:ApplySettings()
                Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
                RebuildGlobalTab()
            end,
        },
    }

    local function borderSizeChanged(key, val)
        GlobalPlugin:SetSetting(nil, key, val)
        Constants.BorderStyle.SyncEffectiveSize(Orbit.db.GlobalSettings)
        GlobalPlugin:ApplySettings()
        Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
    end
    local pixelSize = Constants.BorderStyle.PixelSize
    -- "Orbit Pixel" → Border Size 0-5 slider; rounded → no slider (thickness baked in); LSM → edge-size + offset sliders.
    if currentEntry and currentEntry.pixel then
        tinsert(controls, { type = "slider", key = "PixelBorderSize", label = L.CFG_BORDER_SIZE, default = Constants.BorderStyle.DefaultPixelSize, min = pixelSize.Min, max = pixelSize.Max, step = pixelSize.Step, updateOnRelease = true, onChange = function(v) borderSizeChanged("PixelBorderSize", v) end })
    elseif currentEntry and currentEntry.rounded then
        -- rounded slice border: fixed pixel thickness, no size slider
    else
        tinsert(controls, { type = "slider", key = "BorderEdgeSize", label = L.CFG_BORDER_EDGE_SIZE, default = 16, min = 4, max = 16, step = 4, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderEdgeSize", v) end })
        tinsert(controls, { type = "slider", key = "BorderOffset", label = L.CFG_BORDER_OFFSET, default = 0, min = 0, max = 16, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderOffset", v) end })
    end

    tinsert(controls, {
        type = "dropdown", key = "IconBorderStyle", label = L.CFG_ICON_BORDER_STYLE, options = borderOpts,
        default = Constants.BorderStyle.Default, valueColor = iconBorderColorValue,
        onChange = function(val)
            GlobalPlugin:SetSetting(nil, "IconBorderStyle", val)
            Constants.BorderStyle.SyncEffectiveSize(Orbit.db.GlobalSettings)
            GlobalPlugin:ApplySettings()
            Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
            RebuildGlobalTab()
        end,
    })

    if currentIconEntry and currentIconEntry.pixel then
        tinsert(controls, { type = "slider", key = "IconPixelBorderSize", label = L.CFG_ICON_BORDER_SIZE, default = Constants.BorderStyle.DefaultPixelSize, min = pixelSize.Min, max = pixelSize.Max, step = pixelSize.Step, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconPixelBorderSize", v) end })
    elseif currentIconEntry and currentIconEntry.rounded then
        -- rounded slice border: fixed pixel thickness, no size slider
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
            local def = (Orbit.Profile and Orbit.Profile.defaults and Orbit.Profile.defaults.GlobalSettings) or {}
            if d then
                d.Font = def.Font or "Barlow Condensed Bold"
                d.FontOutline = def.FontOutline or "OUTLINE"
                d.FontShadow = def.FontShadow or false
                d.BorderStyle = Constants.BorderStyle.Default
                d.BorderEdgeSize = 16
                d.BorderOffset = 0
                d.IconBorderStyle = Constants.BorderStyle.Default
                d.IconBorderEdgeSize = 16
                d.IconBorderOffset = 0
                d.PixelBorderSize = Constants.BorderStyle.DefaultPixelSize
                d.IconPixelBorderSize = Constants.BorderStyle.DefaultPixelSize
                Constants.BorderStyle.SyncEffectiveSize(d)
                d.FontColorCurve = Orbit.Constants.NewWhiteColorCurve()
                d.BorderColor = { none = true }
                d.IconBorderColor = { none = true }
            end
            -- Rebuild merged group borders: per-frame ApplySettings re-skins members but never the group overlay/mask.
            Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
            Orbit:Print(L.MSG_GLOBAL_RESET)
        end,
    }
end

-- [ REGISTRATION ]-----------------------------------------------------------------------------------
Panel.Tabs[L.CFG_TAB_GLOBAL] = { plugin = GlobalPlugin, schema = GetGlobalSchema }
