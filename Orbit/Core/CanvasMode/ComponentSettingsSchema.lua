-- [ CANVAS MODE - COMPONENT SETTINGS SCHEMA ]------------------------------------------------------
-- Schema definitions, presets, titles, and type detection for component settings.
local _, addonTable = ...
local Orbit = addonTable
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

local PANDEMIC_GLOW = {
    { type = "dropdown", key = "PandemicGlowType", label = "Pandemic Glow", plugin = true,
      options = {
          { text = "None", value = 0 }, { text = "Pixel Glow", value = 1 },
          { text = "Proc Glow", value = 2 }, { text = "Autocast Shine", value = 3 },
          { text = "Button Glow", value = 4 }, { text = "Blizzard", value = 5 },
      }, default = 0 },
    { type = "colorcurve", key = "PandemicGlowColorCurve", label = "Pandemic Colour", plugin = true, singleColor = true },
}

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
        options = { { text = "LFG", value = "default" }, { text = "Round", value = "round" } }, default = "default" },
        { type = "checkbox", key = "HideDPS", label = "Hide DPS Role", default = false } } },
    CombatIcon      = { controls = { SCALE_CONTROL, { type = "dropdown", key = "CombatIconStyle", label = "Style",
        options = { { text = "Crossed Swords", value = "default" }, { text = "PVP Marker", value = "pvp" } }, default = "default" } } },
    PvpIcon         = { controls = { SCALE_CONTROL, { type = "dropdown", key = "PvpIconStyle", label = "Style",
        options = { { text = "Quest Portrait", value = "default" }, { text = "Faction Crest", value = "crest" } }, default = "default" } } },
    Buffs           = Compose(AURA_GRID),
    Debuffs         = Compose(AURA_GRID, PANDEMIC_GLOW),
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
            { type = "checkbox", key = "CastBarIcon", label = "Icon", plugin = true, default = true },
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
}

-- Register healer aura + raid buff schemas dynamically
do
    local HealerReg = Orbit.HealerAuraRegistry
    if HealerReg then
        for _, key in ipairs(HealerReg.SLOT_KEYS) do
            Schema.KEY_SCHEMAS[key] = Compose({
                { type = "checkbox", key = "ShowTimer", label = "Show Timer", default = false },
                ICON_SIZE_CONTROL,
            }, PANDEMIC_GLOW, {
                { type = "colorcurve", key = "SwipeColorCurve", label = "Swipe Colour", singleColor = false },
                { type = "colorcurve", key = "TimerTextColorCurve", label = "Timer Text Colour", singleColor = false },
            })
        end
        Schema.KEY_SCHEMAS[HealerReg.RAID_BUFF_KEY] = {
            controls = {
                ICON_SIZE_CONTROL,
                { type = "dropdown", key = "ProcGlowType", label = "Proc Glow",
                  options = {
                      { text = "None", value = 0 }, { text = "Pixel Glow", value = 1 },
                      { text = "Proc Glow", value = 2 }, { text = "Autocast Shine", value = 3 },
                      { text = "Button Glow", value = 4 }, { text = "Blizzard", value = 5 },
                  }, default = 0 },
                { type = "colorcurve", key = "ProcGlowColorCurve", label = "Proc Colour", singleColor = true },
            },
        }
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
    ["CastBar.Text"] = "Ability Text", ["CastBar.Timer"] = "Cast Timer",
    StatusIcons = "Status Icons",
    BuffBarName = "Buff Bar Name", BuffBarTimer = "Buff Bar Timer",
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
