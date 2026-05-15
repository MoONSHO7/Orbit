-- [ CANVAS MODE - COMPONENT SETTINGS SCHEMA ] -------------------------------------------------------
-- Schema definitions, presets, titles, and type detection for component settings.
local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local L = Orbit.L

local Schema = {}
CanvasMode.SettingsSchema = Schema

local PORTRAIT_RING_OPTIONS = OrbitEngine.PortraitRingOptions

-- [ SCHEMA HELPERS ] --------------------------------------------------------------------------------
local function Compose(...)
    local controls = {}
    for i = 1, select("#", ...) do
        for _, ctrl in ipairs(select(i, ...)) do controls[#controls + 1] = ctrl end
    end
    return { controls = controls }
end

-- [ REUSABLE CONTROLS ] -----------------------------------------------------------------------------
local SCALE_CONTROL = {
    type = "slider", key = "Scale", label = L.CFG_SCALE,
    min = 0.5, max = 2.0, step = 0.1,
    formatter = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
}

local ICON_SIZE_CONTROL = {
    type = "slider", key = "IconSize", label = L.CFG_ICON_SIZE, min = 8, max = 50, step = 1,
    formatter = function(v) return v .. "px" end,
}

-- [ PRESETS ] ---------------------------------------------------------------------------------------
local STATIC_TEXT = {
    { type = "font", key = "Font", label = L.CMN_FONT },
    { type = "slider", key = "FontSize", label = L.CMN_SIZE, min = 6, max = 32, step = 1 },
    { type = "colorcurve", key = "CustomColorCurve", label = L.CMN_COLOR, singleColor = true },
}

local DYNAMIC_TEXT = {
    { type = "font", key = "Font", label = L.CMN_FONT },
    { type = "slider", key = "FontSize", label = L.CMN_SIZE, min = 6, max = 32, step = 1 },
    { type = "colorcurve", key = "CustomColorCurve", label = L.CMN_COLOR, singleColor = false },
}

local TEXT_NO_COLOR = {
    { type = "font", key = "Font", label = L.CMN_FONT },
    { type = "slider", key = "FontSize", label = L.CMN_SIZE, min = 6, max = 32, step = 1 },
}

local AURA_GRID = {
    { type = "slider", key = "FilterDensity", label = L.CFG_AURA_FILTER, min = 1, max = 3, step = 1,
      formatter = function(v) return v <= 1 and L.CFG_FILTER_LESS or v >= 3 and L.CFG_FILTER_ALL or L.CFG_FILTER_MORE end },
    { type = "slider", key = "MaxIcons", label = L.CFG_MAX_ICONS, min = 1, max = 10, step = 1 },
    { type = "slider", key = "MaxRows", label = L.CFG_MAX_ROWS, min = 1, max = 3, step = 1 },
    ICON_SIZE_CONTROL,
}

local GLOW_TYPE_OPTIONS = {
    { text = L.CFG_GLOW_TYPE_NONE, value = 0 }, { text = L.CFG_GLOW_TYPE_THIN, value = 6 },
    { text = L.CFG_GLOW_TYPE_STANDARD, value = 2 }, { text = L.CFG_GLOW_TYPE_THICK, value = 7 },
    { text = L.CFG_GLOW_TYPE_CLASSIC, value = 4 }, { text = L.CFG_GLOW_TYPE_AUTOCAST, value = 3 },
    { text = L.CFG_GLOW_TYPE_PIXEL, value = 1 },
}
local ALL_ANIMATED_TYPES = { 1, 2, 3, 4, 6, 7 }
local GD = Orbit.Constants.Glow.Defaults
local FMT2 = function(v) return string.format("%.2f", v) end
-- Builds glow type dropdown + per-type fine-tuning sliders for Canvas Mode.
-- Optional capability string gates the entire control set per-plugin.
local function BuildGlowControls(prefix, label, colorKey, colorLabel, capability)
    local typeKey = prefix .. "Type"
    local cap = capability
    return {
        { type = "dropdown", key = typeKey, label = label, plugin = true, rebuildsPanel = true,
          options = GLOW_TYPE_OPTIONS, default = 0, capability = cap },
        { type = "colorcurve", key = colorKey, label = colorLabel, plugin = true, singleColor = true, capability = cap },
        -- Pixel
        { type = "slider", key = prefix .. "PixelLines", label = L.CFG_GLOW_LINES, plugin = true, min = 1, max = 20, step = 1, default = GD.Pixel.Lines, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        { type = "slider", key = prefix .. "PixelFrequency", label = L.CFG_GLOW_FREQUENCY, plugin = true, min = 0, max = 0.20, step = 0.02, default = GD.Pixel.Frequency, formatter = FMT2, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        { type = "slider", key = prefix .. "PixelLength", label = L.CFG_GLOW_LENGTH, plugin = true, min = 1, max = 30, step = 1, default = GD.Pixel.Length, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        { type = "slider", key = prefix .. "PixelThickness", label = L.CFG_GLOW_THICKNESS, plugin = true, min = 1, max = 10, step = 1, default = GD.Pixel.Thickness, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        { type = "checkbox", key = prefix .. "PixelBorder", label = L.CFG_USE_BORDER, plugin = true, default = false, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        -- Medium (Standard)
        { type = "slider", key = prefix .. "MediumSpeed", label = L.CFG_GLOW_SPEED, plugin = true, min = 0.1, max = 5.0, step = 0.1, default = GD.Medium.Speed, showIfValue = { key = typeKey, value = 2 }, capability = cap },
        -- Autocast
        { type = "slider", key = prefix .. "AutocastParticles", label = L.CFG_GLOW_PARTICLES, plugin = true, min = 1, max = 16, step = 1, default = GD.Autocast.Particles, showIfValue = { key = typeKey, value = 3 }, capability = cap },
        { type = "slider", key = prefix .. "AutocastFrequency", label = L.CFG_GLOW_FREQUENCY, plugin = true, min = 0.05, max = 1.0, step = 0.05, default = GD.Autocast.Frequency, formatter = FMT2, showIfValue = { key = typeKey, value = 3 }, capability = cap },
        -- Classic
        { type = "slider", key = prefix .. "ClassicFrequency", label = L.CFG_GLOW_FREQUENCY, plugin = true, min = 0.05, max = 1.0, step = 0.05, default = GD.Classic.Frequency, formatter = FMT2, showIfValue = { key = typeKey, value = 4 }, capability = cap },
        -- Thin
        { type = "slider", key = prefix .. "ThinSpeed", label = L.CFG_GLOW_SPEED, plugin = true, min = 0, max = 5.0, step = 0.1, default = GD.Thin.Speed, showIfValue = { key = typeKey, value = 6 }, capability = cap },
        -- Thick
        { type = "slider", key = prefix .. "ThickSpeed", label = L.CFG_GLOW_SPEED, plugin = true, min = 0, max = 5.0, step = 0.1, default = GD.Thick.Speed, showIfValue = { key = typeKey, value = 7 }, capability = cap },
        -- Reverse (all animated types)
        { type = "checkbox", key = prefix .. "Reverse", label = L.CFG_REVERSE, plugin = true, default = false, showIfValue = { key = typeKey, values = ALL_ANIMATED_TYPES }, capability = cap },
    }
end

-- [ COMPONENT TYPE SCHEMAS ] ------------------------------------------------------------------------
Schema.TYPE_SCHEMAS = {
    FontString = Compose(DYNAMIC_TEXT),
    Texture = { controls = { SCALE_CONTROL } },
    IconFrame = { controls = { ICON_SIZE_CONTROL } },
    CyclingAtlas = { controls = { ICON_SIZE_CONTROL } },
}

-- [ KEY SCHEMAS ] -----------------------------------------------------------------------------------
Schema.KEY_SCHEMAS = {
    Name            = Compose(STATIC_TEXT),
    Timer           = Compose(DYNAMIC_TEXT),
    Stacks          = Compose(STATIC_TEXT),
    Keybind         = Compose(STATIC_TEXT),
    MacroText       = Compose(STATIC_TEXT),
    Charges         = Compose(STATIC_TEXT),
    ChargeCount     = Compose(STATIC_TEXT),
    Text            = Compose(STATIC_TEXT),
    BuffBarName     = Compose(STATIC_TEXT),
    BuffBarTimer    = Compose(STATIC_TEXT),
    ["CastBar.Text"] = Compose(STATIC_TEXT),
    LevelText       = Compose(TEXT_NO_COLOR),
    DungeonScore    = Compose(TEXT_NO_COLOR),
    DungeonShort    = Compose(TEXT_NO_COLOR),
    FavouriteStar   = { controls = {} },
    StatusIcons     = { controls = { ICON_SIZE_CONTROL } },
    DispelIcon      = { controls = { ICON_SIZE_CONTROL } },
    RoleIcon        = { controls = { SCALE_CONTROL, { type = "dropdown", key = "RoleIconStyle", label = L.CFG_STYLE,
        options = { { text = L.CFG_ROLE_STYLE_LFG, value = "default" }, { text = L.CFG_ROLE_STYLE_ROUND, value = "round" }, { text = L.CFG_ROLE_STYLE_HEADER, value = "header" } }, default = "default" },
        { type = "checkbox", key = "HideDPS", label = L.CFG_HIDE_DPS_ROLE, default = false } } },
    CombatIcon      = { controls = { SCALE_CONTROL, { type = "dropdown", key = "CombatIconStyle", label = L.CFG_STYLE,
        options = { { text = L.CFG_COMBAT_STYLE_SWORDS, value = "default" }, { text = L.CFG_COMBAT_STYLE_PVP, value = "pvp" } }, default = "default" } } },
    LeaderIcon      = { controls = { SCALE_CONTROL, { type = "dropdown", key = "LeaderIconStyle", label = L.CFG_STYLE,
        options = { { text = L.CFG_LEADER_STYLE_DEFAULT, value = "default" }, { text = L.CFG_ROLE_STYLE_HEADER, value = "header" } }, default = "default" } } },
    PvpIcon         = { controls = { ICON_SIZE_CONTROL } },
    Buffs           = Compose(AURA_GRID, BuildGlowControls("PandemicGlow", L.CFG_PANDEMIC_GLOW, "PandemicGlowColorCurve", L.CFG_PANDEMIC_COLOR)),
    Debuffs         = Compose(AURA_GRID, BuildGlowControls("PandemicGlow", L.CFG_PANDEMIC_GLOW, "PandemicGlowColorCurve", L.CFG_PANDEMIC_COLOR, "supportsPandemicGlow")),
    PrivateAuraAnchor = { controls = { ICON_SIZE_CONTROL } },
    Portrait = {
        controls = {
            { type = "dropdown", key = "PortraitStyle", label = L.CFG_STYLE, plugin = true, rebuildsPanel = true,
              options = { { text = L.CFG_PORTRAIT_STYLE_2D, value = "2d" }, { text = L.CFG_PORTRAIT_STYLE_3D, value = "3d" } }, default = "3d" },
            { type = "slider", key = "PortraitScale", label = L.CFG_SCALE, plugin = true, min = 50, max = 200, step = 1,
              formatter = function(v) return v .. "%" end, default = 120 },
            { type = "checkbox", key = "PortraitBorder", label = L.CFG_BORDER, plugin = true, default = true, showIfValue = { key = "PortraitStyle", value = "3d" } },
            { type = "dropdown", key = "PortraitRing", label = L.CFG_RING, plugin = true, showIfValue = { key = "PortraitStyle", value = "2d" },
              options = PORTRAIT_RING_OPTIONS, default = "none" },
            { type = "checkbox", key = "PortraitMirror", label = L.CFG_MIRROR, plugin = true, default = false },
        },
    },
    CastBar = {
        controls = {
            { type = "slider", key = "CastBarHeight", label = L.CMN_HEIGHT, plugin = true, min = 8, max = 40, step = 1,
              formatter = function(v) return v .. "px" end },
            { type = "slider", key = "CastBarWidth", label = L.CMN_WIDTH, plugin = true, min = 50, max = 400, step = 1,
              formatter = function(v) return v .. "px" end },
            { type = "colorcurve", key = "CastBarColorCurve", label = L.CMN_COLOR, plugin = true, singleColor = true },
        },
    },
    HealthText = {
        controls = {
            { type = "checkbox", key = "ShowHealthValue", label = L.CFG_SHOW_HEALTH_VALUE, plugin = true, default = true, capability = "supportsHealthText" },
            { type = "dropdown", key = "HealthTextMode", label = L.CFG_FORMAT, plugin = true, showIf = "ShowHealthValue", capability = "supportsHealthText",
              options = {
                { text = L.CFG_HEALTH_FMT_PERCENT, value = "percent" },
                { text = L.CFG_HEALTH_FMT_SHORT, value = "short" },
                { text = L.CFG_HEALTH_FMT_RAW, value = "raw" },
                { text = L.CFG_HEALTH_FMT_SHORT_PCT, value = "short_and_percent" },
                { text = L.CFG_HEALTH_FMT_PCT_SHORT, value = "percent_short" },
                { text = L.CFG_HEALTH_FMT_PCT_RAW, value = "percent_raw" },
                { text = L.CFG_HEALTH_FMT_SHORT_PCT2, value = "short_percent" },
                { text = L.CFG_HEALTH_FMT_SHORT_RAW, value = "short_raw" },
                { text = L.CFG_HEALTH_FMT_RAW_SHORT, value = "raw_short" },
                { text = L.CFG_HEALTH_FMT_RAW_PCT, value = "raw_percent" },
              }, default = "percent_short" },
            { type = "font", key = "Font", label = L.CMN_FONT },
            { type = "slider", key = "FontSize", label = L.CMN_SIZE, min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = L.CMN_COLOR, singleColor = false },
        },
    },
    ZoneText = {
        controls = {
            { type = "font",       key = "Font",             label = L.CMN_FONT },
            { type = "slider",     key = "FontSize",         label = L.CMN_SIZE,          min = 6,       max = 32,   step = 1 },
            { type = "checkbox",   key = "ZoneTextColoring", label = L.CFG_ZONE_COLORING, plugin = true, default = false },
            { type = "colorcurve", key = "CustomColorCurve", label = L.CMN_COLOR,         singleColor = true, hideIf = "ZoneTextColoring" },
        },
    },
    Clock  = Compose(STATIC_TEXT),
    Coords = Compose(STATIC_TEXT),
    DifficultyIcon = {
        controls = {
            { type = "dropdown", key = "DifficultyDisplay", label = L.CFG_DISPLAY, plugin = true, default = "icon", rebuildsPanel = true,
                options = { { value = "icon", label = L.CFG_DISPLAY_ICON }, { value = "text", label = L.CFG_DISPLAY_TEXT } } },
            { type = "slider", key = "IconSize", label = L.CMN_SIZE, min = 16, max = 80, step = 1, formatter = function(v) return v .. "px" end,
            },
            { type = "checkbox", key = "DifficultyShowBackground", label = L.CFG_SHOW_BACKGROUND_MINIMAP, plugin = true, default = false },
        },
    },
    DifficultyText = {
        controls = {
            { type = "dropdown", key = "DifficultyDisplay", label = L.CFG_DISPLAY, plugin = true, default = "icon", rebuildsPanel = true,
                options = { { value = "icon", label = L.CFG_DISPLAY_ICON }, { value = "text", label = L.CFG_DISPLAY_TEXT } } },
            { type = "font", key = "Font", label = L.CMN_FONT },
            { type = "slider", key = "FontSize", label = L.CMN_SIZE, min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = L.CMN_COLOR, singleColor = true },
        },
    },
}

-- Register healer aura + raid buff schemas dynamically
do
    local HealerReg = Orbit.HealerAuraRegistry
    if HealerReg then
        for _, key in ipairs(HealerReg.SLOT_KEYS) do
            Schema.KEY_SCHEMAS[key] = Compose({
                { type = "checkbox", key = "ShowTimer", label = L.CFG_SHOW_TIMER, default = false },
                ICON_SIZE_CONTROL,
            }, BuildGlowControls("PandemicGlow", L.CFG_PANDEMIC_GLOW, "PandemicGlowColorCurve", L.CFG_PANDEMIC_COLOR), {
                { type = "colorcurve", key = "SwipeColorCurve", label = L.CFG_SWIPE_COLOR, singleColor = false },
                { type = "colorcurve", key = "TimerTextColorCurve", label = L.CFG_TIMER_TEXT_COLOR, singleColor = false },
            })
        end
        Schema.KEY_SCHEMAS[HealerReg.RAID_BUFF_KEY] = Compose({
            ICON_SIZE_CONTROL,
        }, BuildGlowControls("ProcGlow", L.CFG_PROC_GLOW, "ProcGlowColorCurve", L.CFG_PROC_COLOR))
    end
end

-- [ TITLES ] ----------------------------------------------------------------------------------------
local COMPONENT_TITLES = {
    Name = L.CFG_TITLE_NAME_TEXT, HealthText = L.CFG_TITLE_HEALTH_TEXT, LevelText = L.CFG_TITLE_LEVEL_TEXT,
    CombatIcon = L.CFG_TITLE_COMBAT_ICON, RareEliteIcon = L.CFG_TITLE_CLASSIFICATION_ICON,
    RestingIcon = L.CFG_TITLE_RESTING_ICON, DefensiveIcon = L.CFG_TITLE_DEFENSIVE_ICON,
    CrowdControlIcon = L.CFG_TITLE_CC_ICON, Buffs = L.CFG_TITLE_BUFFS, Debuffs = L.CFG_TITLE_DEBUFFS,
    Portrait = L.CFG_TITLE_PORTRAIT, CastBar = L.CFG_TITLE_CAST_BAR, MarkerIcon = L.CFG_TITLE_RAID_MARKER,
    RoleIcon = L.CFG_TITLE_ROLE_ICON,
    LeaderIcon = L.CFG_TITLE_LEADER_ASSIST,
    ["CastBar.Text"] = L.CFG_TITLE_ABILITY_TEXT, ["CastBar.Timer"] = L.CFG_TITLE_CAST_TIMER,
    StatusIcons = L.CFG_TITLE_STATUS_ICONS,
    DispelIcon = L.CFG_TITLE_DISPEL_ICON,
    BuffBarName = L.CFG_TITLE_BUFF_BAR_NAME, BuffBarTimer = L.CFG_TITLE_BUFF_BAR_TIMER,
    ZoneText = L.CFG_TITLE_ZONE_TEXT, Clock = L.CFG_TITLE_CLOCK, Coords = L.CFG_TITLE_COORDINATES,
    Zoom = L.CFG_TITLE_ZOOM_BUTTONS, DifficultyIcon = L.CFG_TITLE_DIFFICULTY_ICON, DifficultyText = L.CFG_TITLE_DIFFICULTY_TEXT,
    Missions = L.CFG_TITLE_MISSIONS, Mail = L.CFG_TITLE_NEW_MAIL, CraftingOrder = L.CFG_TITLE_CRAFTING_ORDER,
    Compartment = L.CFG_TITLE_ADDON_COMPARTMENT,
}

function Schema.ResolveTitle(key)
    if COMPONENT_TITLES[key] then return COMPONENT_TITLES[key] end
    local HealerReg = Orbit.HealerAuraRegistry
    if HealerReg then return HealerReg:GetSlotLabel(key) end
    return key
end

function Schema.GetComponentFamily(container)
    if not container or not container.visual then return nil end
    if container.isIconFrame then return "IconFrame" end
    local objType = container.visual.GetObjectType and container.visual:GetObjectType()
    if objType == "FontString" then return "FontString"
    elseif objType == "Texture" then return "Texture" end
    return nil
end
