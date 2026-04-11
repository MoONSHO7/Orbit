-- [ CANVAS MODE - COMPONENT SETTINGS SCHEMA ]------------------------------------------------------
-- Schema definitions, presets, titles, and type detection for component settings.
local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode

local Schema = {}
CanvasMode.SettingsSchema = Schema

local PORTRAIT_RING_OPTIONS = OrbitEngine.PortraitRingOptions

-- [ SCHEMA HELPERS ]---------------------------------------------------------------------------------
local function Compose(...)
    local controls = {}
    for i = 1, select("#", ...) do
        for _, ctrl in ipairs(select(i, ...)) do controls[#controls + 1] = ctrl end
    end
    return { controls = controls }
end

-- [ REUSABLE CONTROLS ]------------------------------------------------------------------------------
local SCALE_CONTROL = {
    type = "slider", key = "Scale", label = "Scale",
    min = 0.5, max = 2.0, step = 0.1,
    formatter = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
}

local ICON_SIZE_CONTROL = {
    type = "slider", key = "IconSize", label = "Icon Size", min = 8, max = 50, step = 1,
    formatter = function(v) return v .. "px" end,
}

-- [ PRESETS ]----------------------------------------------------------------------------------------
local STATIC_TEXT = {
    { type = "font", key = "Font", label = "Font" },
    { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
    { type = "colorcurve", key = "CustomColorCurve", label = "Color", singleColor = true },
}

local DYNAMIC_TEXT = {
    { type = "font", key = "Font", label = "Font" },
    { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
    { type = "colorcurve", key = "CustomColorCurve", label = "Color", singleColor = false },
}

local TEXT_NO_COLOR = {
    { type = "font", key = "Font", label = "Font" },
    { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
}

local AURA_GRID = {
    { type = "slider", key = "FilterDensity", label = "Aura Filter", min = 1, max = 3, step = 1,
      formatter = function(v) return v <= 1 and "Less" or v >= 3 and "All" or "More" end },
    { type = "slider", key = "MaxIcons", label = "Max Icons", min = 1, max = 10, step = 1 },
    { type = "slider", key = "MaxRows", label = "Max Rows", min = 1, max = 3, step = 1 },
    ICON_SIZE_CONTROL,
}

local GLOW_TYPE_OPTIONS = {
    { text = "None", value = 0 }, { text = "Thin", value = 6 },
    { text = "Standard", value = 2 }, { text = "Thick", value = 7 },
    { text = "Classic", value = 4 }, { text = "Autocast", value = 3 },
    { text = "Pixel", value = 1 },
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
        { type = "slider", key = prefix .. "PixelLines", label = "Lines", plugin = true, min = 1, max = 20, step = 1, default = GD.Pixel.Lines, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        { type = "slider", key = prefix .. "PixelFrequency", label = "Frequency", plugin = true, min = 0, max = 0.20, step = 0.02, default = GD.Pixel.Frequency, formatter = FMT2, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        { type = "slider", key = prefix .. "PixelLength", label = "Length", plugin = true, min = 1, max = 30, step = 1, default = GD.Pixel.Length, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        { type = "slider", key = prefix .. "PixelThickness", label = "Thickness", plugin = true, min = 1, max = 10, step = 1, default = GD.Pixel.Thickness, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        { type = "checkbox", key = prefix .. "PixelBorder", label = "Use Border", plugin = true, default = false, showIfValue = { key = typeKey, value = 1 }, capability = cap },
        -- Medium (Standard)
        { type = "slider", key = prefix .. "MediumSpeed", label = "Speed", plugin = true, min = 0.1, max = 5.0, step = 0.1, default = GD.Medium.Speed, showIfValue = { key = typeKey, value = 2 }, capability = cap },
        -- Autocast
        { type = "slider", key = prefix .. "AutocastParticles", label = "Particles", plugin = true, min = 1, max = 16, step = 1, default = GD.Autocast.Particles, showIfValue = { key = typeKey, value = 3 }, capability = cap },
        { type = "slider", key = prefix .. "AutocastFrequency", label = "Frequency", plugin = true, min = 0.05, max = 1.0, step = 0.05, default = GD.Autocast.Frequency, formatter = FMT2, showIfValue = { key = typeKey, value = 3 }, capability = cap },
        -- Classic
        { type = "slider", key = prefix .. "ClassicFrequency", label = "Frequency", plugin = true, min = 0.05, max = 1.0, step = 0.05, default = GD.Classic.Frequency, formatter = FMT2, showIfValue = { key = typeKey, value = 4 }, capability = cap },
        -- Thin
        { type = "slider", key = prefix .. "ThinSpeed", label = "Speed", plugin = true, min = 0, max = 5.0, step = 0.1, default = GD.Thin.Speed, showIfValue = { key = typeKey, value = 6 }, capability = cap },
        -- Thick
        { type = "slider", key = prefix .. "ThickSpeed", label = "Speed", plugin = true, min = 0, max = 5.0, step = 0.1, default = GD.Thick.Speed, showIfValue = { key = typeKey, value = 7 }, capability = cap },
        -- Reverse (all animated types)
        { type = "checkbox", key = prefix .. "Reverse", label = "Reverse", plugin = true, default = false, showIfValue = { key = typeKey, values = ALL_ANIMATED_TYPES }, capability = cap },
    }
end

-- [ COMPONENT TYPE SCHEMAS ]-------------------------------------------------------------------------
Schema.TYPE_SCHEMAS = {
    FontString = Compose(DYNAMIC_TEXT),
    Texture = { controls = { SCALE_CONTROL } },
    IconFrame = { controls = { ICON_SIZE_CONTROL } },
    CyclingAtlas = { controls = { ICON_SIZE_CONTROL } },
}

-- [ KEY SCHEMAS ]------------------------------------------------------------------------------------
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
    StatusIcons     = { controls = { ICON_SIZE_CONTROL } },
    RoleIcon        = { controls = { SCALE_CONTROL, { type = "dropdown", key = "RoleIconStyle", label = "Style",
        options = { { text = "LFG", value = "default" }, { text = "Round", value = "round" }, { text = "Header", value = "header" } }, default = "default" },
        { type = "checkbox", key = "HideDPS", label = "Hide DPS Role", default = false } } },
    CombatIcon      = { controls = { SCALE_CONTROL, { type = "dropdown", key = "CombatIconStyle", label = "Style",
        options = { { text = "Crossed Swords", value = "default" }, { text = "PVP Marker", value = "pvp" } }, default = "default" } } },
    LeaderIcon      = { controls = { SCALE_CONTROL, { type = "dropdown", key = "LeaderIconStyle", label = "Style",
        options = { { text = "Default", value = "default" }, { text = "Header", value = "header" } }, default = "default" } } },
    PvpIcon         = { controls = { ICON_SIZE_CONTROL } },
    Buffs           = Compose(AURA_GRID, BuildGlowControls("PandemicGlow", "Pandemic Glow", "PandemicGlowColorCurve", "Pandemic Colour")),
    Debuffs         = Compose(AURA_GRID, BuildGlowControls("PandemicGlow", "Pandemic Glow", "PandemicGlowColorCurve", "Pandemic Colour", "supportsPandemicGlow")),
    PrivateAuraAnchor = { controls = { ICON_SIZE_CONTROL } },
    Portrait = {
        controls = {
            { type = "dropdown", key = "PortraitStyle", label = "Style", plugin = true, rebuildsPanel = true,
              options = { { text = "2D", value = "2d" }, { text = "3D", value = "3d" } }, default = "3d" },
            { type = "slider", key = "PortraitScale", label = "Scale", plugin = true, min = 50, max = 200, step = 1,
              formatter = function(v) return v .. "%" end, default = 120 },
            { type = "checkbox", key = "PortraitBorder", label = "Border", plugin = true, default = true, showIfValue = { key = "PortraitStyle", value = "3d" } },
            { type = "dropdown", key = "PortraitRing", label = "Ring", plugin = true, showIfValue = { key = "PortraitStyle", value = "2d" },
              options = PORTRAIT_RING_OPTIONS, default = "none" },
            { type = "checkbox", key = "PortraitMirror", label = "Mirror", plugin = true, default = false },
        },
    },
    CastBar = {
        controls = {
            { type = "slider", key = "CastBarHeight", label = "Height", plugin = true, min = 8, max = 40, step = 1,
              formatter = function(v) return v .. "px" end },
            { type = "slider", key = "CastBarWidth", label = "Width", plugin = true, min = 50, max = 400, step = 1,
              formatter = function(v) return v .. "px" end },
            { type = "colorcurve", key = "CastBarColorCurve", label = "Color", plugin = true, singleColor = true },
        },
    },
    HealthText = {
        controls = {
            { type = "checkbox", key = "ShowHealthValue", label = "Show Health Value", plugin = true, default = true, capability = "supportsHealthText" },
            { type = "dropdown", key = "HealthTextMode", label = "Format", plugin = true, showIf = "ShowHealthValue", capability = "supportsHealthText",
              options = {
                { text = "Percentage", value = "percent" },
                { text = "Short Health", value = "short" },
                { text = "Raw Health", value = "raw" },
                { text = "Short - Percentage", value = "short_and_percent" },
                { text = "Percentage / Short", value = "percent_short" },
                { text = "Percentage / Raw", value = "percent_raw" },
                { text = "Short / Percentage", value = "short_percent" },
                { text = "Short / Raw", value = "short_raw" },
                { text = "Raw / Short", value = "raw_short" },
                { text = "Raw / Percentage", value = "raw_percent" },
              }, default = "percent_short" },
            { type = "font", key = "Font", label = "Font" },
            { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = "Color", singleColor = false },
        },
    },
    ZoneText = {
        controls = {
            { type = "font",       key = "Font",             label = "Font" },
            { type = "slider",     key = "FontSize",         label = "Size",          min = 6,       max = 32,   step = 1 },
            { type = "checkbox",   key = "ZoneTextColoring", label = "Zone Coloring", plugin = true, default = false },
            { type = "colorcurve", key = "CustomColorCurve", label = "Color",         singleColor = true, hideIf = "ZoneTextColoring" },
        },
    },
    Clock  = Compose(STATIC_TEXT),
    Coords = Compose(STATIC_TEXT),
    DifficultyIcon = {
        controls = {
            { type = "dropdown", key = "DifficultyDisplay", label = "Display", plugin = true, default = "icon", rebuildsPanel = true,
                options = { { value = "icon", label = "Icon" }, { value = "text", label = "Text" } } },
            { type = "slider", key = "IconSize", label = "Size", min = 16, max = 80, step = 1, formatter = function(v) return v .. "px" end,
            },
            { type = "checkbox", key = "DifficultyShowBackground", label = "Show Background on Minimap", plugin = true, default = false },
        },
    },
    DifficultyText = {
        controls = {
            { type = "dropdown", key = "DifficultyDisplay", label = "Display", plugin = true, default = "icon", rebuildsPanel = true,
                options = { { value = "icon", label = "Icon" }, { value = "text", label = "Text" } } },
            { type = "font", key = "Font", label = "Font" },
            { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = "Color", singleColor = true },
        },
    },
}

-- Register healer aura + raid buff schemas dynamically
do
    local HealerReg = Orbit.HealerAuraRegistry
    if HealerReg then
        for _, key in ipairs(HealerReg.SLOT_KEYS) do
            Schema.KEY_SCHEMAS[key] = Compose({
                { type = "checkbox", key = "ShowTimer", label = "Show Timer", default = false },
                ICON_SIZE_CONTROL,
            }, BuildGlowControls("PandemicGlow", "Pandemic Glow", "PandemicGlowColorCurve", "Pandemic Colour"), {
                { type = "colorcurve", key = "SwipeColorCurve", label = "Swipe Colour", singleColor = false },
                { type = "colorcurve", key = "TimerTextColorCurve", label = "Timer Text Colour", singleColor = false },
            })
        end
        Schema.KEY_SCHEMAS[HealerReg.RAID_BUFF_KEY] = Compose({
            ICON_SIZE_CONTROL,
        }, BuildGlowControls("ProcGlow", "Proc Glow", "ProcGlowColorCurve", "Proc Colour"))
    end
end

-- [ TITLES ]-----------------------------------------------------------------------------------------
local COMPONENT_TITLES = {
    Name = "Name Text", HealthText = "Health Text", LevelText = "Level Text",
    CombatIcon = "Combat Icon", RareEliteIcon = "Classification Icon",
    RestingIcon = "Resting Icon", DefensiveIcon = "Defensive Icon",
    CrowdControlIcon = "Crowd Control Icon", Buffs = "Buffs", Debuffs = "Debuffs",
    Portrait = "Portrait", CastBar = "Cast Bar", MarkerIcon = "Raid Marker",
    RoleIcon = "Role Icon",
    LeaderIcon = "Leader / Assist Icon",
    ["CastBar.Text"] = "Ability Text", ["CastBar.Timer"] = "Cast Timer",
    StatusIcons = "Status Icons",
    BuffBarName = "Buff Bar Name", BuffBarTimer = "Buff Bar Timer",
    ZoneText = "Zone Text", Clock = "Clock", Coords = "Coordinates",
    Zoom = "Zoom Buttons", DifficultyIcon = "Instance Difficulty Icon", DifficultyText = "Instance Difficulty Text",
    Missions = "Missions", Mail = "New Mail", CraftingOrder = "Crafting Order",
    Compartment = "Addon Compartment",
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
