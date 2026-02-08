-- [ ORBIT CONSTANTS - Unified Constants Module ]----------------------------------------------------
-- All constants consolidated here for easy access and maintenance.
-- Access via: Orbit.Constants or Orbit.Engine.Constants
-- This file loads FIRST, before Engine.lua

local _, Orbit = ...

---@class OrbitConstants
Orbit.Constants = {}
local C = Orbit.Constants

-- [ UI PANEL LAYOUT ]-------------------------------------------------------------------------------
C.Panel = {
    Width = 320,
    DialogWidth = 350,
    MinDialogHeight = 150,
    MaxHeight = 800,
    ScrollbarWidth = 26,
    ContentPadding = 8,
    DividerWidth = 280,
    DividerHeight = 16,
    HeaderHeight = 55, -- Height to clear tabs completely
    TitlePadding = 50, -- Dialog title area padding
}

C.PluginGroups = {
    UnitFrames = "Unit Frames",
    ActionBars = "Action Bars",
    CooldownManager = "Cooldown Manager",
    MenuItems = "Menu Items",
    BossFrames = "Boss Frames",
    Misc = "Misc",
    PartyFrames = "Party Frames",
}

C.Footer = {
    TopPadding = 12,
    BottomPadding = 12,
    ButtonHeight = 20,
    RowSpacing = 6,
    SidePadding = 10,
    ButtonSpacing = 8,
    DividerOffset = 6,
}

-- [ WIDGET LAYOUT ]---------------------------------------------------------------------------------
-- All widgets follow: [Fixed Label, Left] [Dynamic Control, Fill] [Fixed Value, Right]
C.Widget = {
    Width = 240,
    Height = 26,
    LabelWidth = 100, -- Fixed width for left label column
    LabelGap = 3, -- Gap between label and control
    ValueWidth = 45, -- Fixed width for right value column
    CheckboxIconWidth = 32,
    CheckboxIconGap = 4,
}

-- [ FRAME CONSTANTS ]-------------------------------------------------------------------------------
C.Frame = {
    EditModeColor = { r = 0.7, g = 0.6, b = 1.0 }, -- Light Purple
}

C.Selection = {
    ShiftMultiplier = 10, -- Shift+scroll multiplier for padding adjustment
    AnchorLineThickness = 2, -- Green anchor indicator line thickness
    WheelDebounce = 0.05, -- Mouse wheel event debounce delay
    TooltipFadeDuration = 1.0, -- Position tooltip fade-out delay
    PositionTooltip = { Width = 100, Height = 24 },
    OverlayLevelOffset = 100, -- Frame level offset for selection overlay
}

-- [ FRAME LAYER HIERARCHY ]-------------------------------------------------------------------------
-- Draw Layer Sublevels: background → border → icons → highlights → glows → text
C.Layers = {
    BackdropDeep = -8,  -- Deep backgrounds (bar fills, status textures)
    Border = 1,         -- Frame borders
    Icon = 3,           -- Icons, status textures
    Highlight = 5,      -- Border highlights, selection markers
    Glow = 6,           -- Proc/pandemic glow effects
    Text = 7,           -- Text, component icons (role, leader)
}

-- Frame Level Offsets (relative to parent)
C.Levels = {
    Cooldown = 2,       -- Cooldown swipe frame
    Border = 3,         -- Border container frame
    Highlight = 5,      -- Highlight frame
    Glow = 10,          -- Glow effect container
    Text = 20,          -- Text overlay frame
    ProcOverlay = 50,   -- High level procs (SpellActivationAlert)
    SmartGuides = 90,   -- Canvas Mode snap guides
    Tooltip = 100,      -- Tooltip/flyout layer
}

C.UnitFrame = {
    TextPadding = 5, -- SetPoint offset for Name/HealthText labels
    ShadowOffset = { x = 1, y = -1 }, -- Standard shadow for text
    AdaptiveTextMin = 14, -- Min font size for adaptive text scaling
    AdaptiveTextMax = 24, -- Max font size for adaptive text scaling
    CombatIconSize = 18, -- Player combat indicator icon size
    StatusIconSize = 16, -- Role/Leader/Marker/RareElite icon size
}

C.BossFrame = {
    PowerBarRatio = 0.2, -- Power bar height as ratio of frame height
    FrameSpacing = 20, -- Base spacing between stacked boss frames
}

C.Stagger = {
    LowThreshold = 30, -- Below 30% = light stagger
    MediumThreshold = 60, -- 30-60% = medium stagger, above = heavy
}

-- [ SETTINGS RANGES (Default min/max/step for sliders) ]--------------------------------------------
C.Settings = {
    Width = { Min = 100, Max = 400, Step = 10, Default = 200 },
    Height = { Min = 10, Max = 50, Step = 1, Default = 20 },
    Scale = { Min = 50, Max = 150, Step = 5, Default = 100 },
    Opacity = { Min = 0, Max = 100, Step = 1, Default = 100 },
    TextSize = { Min = 8, Max = 32, Step = 1, Default = 12 },
    BorderSize = { Min = 1, Max = 5, Step = 1, Default = 1 },
    Spacing = { Min = -1, Max = 10, Step = 1, Default = 2 },
    Padding = { Min = -10, Max = 10, Step = 1, Default = 0 },
    Font = { Default = "PT Sans Narrow", FallbackPath = "Fonts\\FRIZQT__.TTF" },
    Texture = { Default = "Melli" },
}

-- [ TIMING CONSTANTS ]------------------------------------------------------------------------------
C.Timing = {
    DefaultDebounce = 0.1,
    LayoutThrottle = 0.15,
    SettingsApplyDelay = 0.1,
    IconMonitorInterval = 0.25, -- Icon state monitoring (0.25s = ~60% less CPU than 0.1s)
    LayoutMonitorInterval = 0.25, -- Layout change detection
    FadeDuration = 0.3,
    FlashDuration = 0.5,
    KeyboardRestoreDelay = 0.05, -- Restore keyboard propagation after ESC
    RetryShort = 0.5, -- Short retry delay for initialization
    RetryLong = 2.0, -- Long retry delay for slow loads
    ResourceUpdateInterval = 0.05, -- Resource bar OnUpdate throttle
    HoverCheckInterval = 0.1, -- OOC fade mouseover polling interval
}

-- [ ICON & TEXTURE CONSTANTS ]----------------------------------------------------------------------
C.IconScale = {
    MaskOversize = 4, -- Ensure mask doesn't clip non-square icons
    FlashScale = 1.2, -- Flash animation slightly larger than icon
    ProcGlowScale = 1.4, -- Proc glow extends beyond icon
    PandemicPadding = 12, -- Pandemic border padding
    BorderPaddingH = 16, -- Native border horizontal padding
    BorderPaddingV = 16, -- Native border vertical padding
}

C.Texture = {
    BlizzardIconBorderTrim = 0.08,
}

C.Atlases = {
    CooldownBorder = "UI-HUD-CoolDownManager-IconOverlay",
    OutofRangeShadow = "UI-CooldownManager-OORshadow",
}

C.Assets = {
    SwipeCustom = "Interface\\Cooldown\\player-cooldown-swipe",
    SwipeDefault = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe",
}

-- [ SKINNING CONSTANTS ]----------------------------------------------------------------------------
C.Skin = {
    DefaultIconSize = 40,
    BorderOffsetGeneric = 7,
    BorderOffsetPandemic = 6,
    OORAlpha = 0.5,
    DebuffBorderAlpha = 0,
}

-- [ COMPONENT DEFAULTS ]----------------------------------------------------------------------------
-- Note: PlayerCastBar is shared by PlayerCastBar, TargetCastBar, FocusCastBar, and CastBarMixin
C.PlayerCastBar = {
    DefaultWidth = 200,
    DefaultHeight = 15,
    DefaultY = -200,
}

C.Cooldown = {
    DefaultLimit = 10,
    DefaultPadding = 2,
    DefaultIconSize = 100,
    MaxChildFrames = 14,
    SystemIndex = {
        Essential = 1,
        Utility = 2,
        BuffIcon = 3,
        Tracked = 4,
        Tracked_ChildStart = 5,
        ChargeBar = 20,
        ChargeBar_ChildStart = 21,
    },
    MaxChargeBarChildren = 4,
}

-- Pandemic Glow configuration (LibCustomGlow)
C.PandemicGlow = {
    -- Glow type enum
    Type = {
        None = 0,
        Pixel = 1,
        Proc = 2,
        Autocast = 3,
        Button = 4,
    },

    -- Default glow type and color
    DefaultType = 2, -- Proc Glow
    DefaultColor = { r = 1, g = 0.8, b = 0, a = 1 }, -- Gold/amber

    -- Per-glow-type parameters (customize size, speed, etc.)
    Pixel = {
        Lines = 4, -- Number of lines
        Frequency = 0.25, -- Speed
        Length = 15, -- Line length
        Thickness = 2, -- Line thickness
        XOffset = 0,
        YOffset = 0,
        Border = false,
    },
    Proc = {
        StartAnim = true,
        Duration = 1,
    },
    Autocast = {
        Particles = 4, -- Number of particles
        Frequency = 0.125, -- Speed
        Scale = 1,
        XOffset = 0,
        YOffset = 0,
    },
    Button = {
        Frequency = 0.125, -- Speed
        FrameLevel = 8, -- Frame level offset
    },
}

-- [ UI FONTS (Template Names) ]---------------------------------------------------------------------
C.UI = {
    LabelFont = "GameFontHighlight", -- White font for widget labels
    ValueFont = "GameFontHighlightSmall", -- Yellow font for value displays
    UnitFrameTextSize = 12, -- Standard text size for UnitFrames (Name, Health)
}

-- [ COLORS ]----------------------------------------------------------------------------------------
C.PowerTypeIds = {
    Mana = 0,
    Rage = 1,
    Focus = 2,
    Energy = 3,
    ComboPoints = 4,
    Runes = 5,
    RunicPower = 6,
    SoulShards = 7,
    LunarPower = 8,
    HolyPower = 9,
    Maelstrom = 11,
    Chi = 12,
    Insanity = 13,
    Obsolete = 14,
    Obsolete2 = 15,
    ArcaneCharges = 16,
    Fury = 17,
    Pain = 18,
    Essence = 19,
}

C.Colors = {
    Background = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 },

    -- Power Type Colors (for boss frames, etc.)
    -- Keys correspond to Enum.PowerType
    PowerType = {
        [0] = { r = 0, g = 0, b = 1 }, -- Mana
        [1] = { r = 1, g = 0, b = 0 }, -- Rage
        [2] = { r = 1, g = 0.5, b = 0.25 }, -- Focus
        [3] = { r = 1, g = 1, b = 0 }, -- Energy
        [4] = { r = 0, g = 1, b = 1 }, -- Combo Points
        [5] = { r = 0.5, g = 0.5, b = 0.5 }, -- Runes
        [6] = { r = 0, g = 0.82, b = 1 }, -- Runic Power
        [7] = { r = 0.5, g = 0.32, b = 0.55 }, -- Soul Shards
        [8] = { r = 0.95, g = 0.9, b = 0.6 }, -- Lunar Power
        [9] = { r = 0.3, g = 0.52, b = 0.9 }, -- Holy Power
        [11] = { r = 0.65, g = 0.63, b = 0.35 }, -- Maelstrom
        [12] = { r = 0.6, g = 0.09, b = 0.16 }, -- Chi
        [13] = { r = 1, g = 0.61, b = 0 }, -- Insanity
        [16] = { r = 0.3, g = 0.52, b = 0.9 }, -- Arcane Charges
        [17] = { r = 1, g = 0.6, b = 0.2 }, -- Fury
        [18] = { r = 0.27, g = 0.75, b = 0.65 }, -- Pain
        [19] = { r = 0.19, g = 0.58, b = 0.77 }, -- Essence
    },

    PlayerResources = {
        ROGUE = { r = 1.0, g = 0.96, b = 0.41 },
        DRUID = { r = 1.0, g = 0.96, b = 0.41 },
        PALADIN = { r = 0.95, g = 0.9, b = 0.6 },
        MONK = { r = 0.71, g = 1.0, b = 0.92 },
        WARLOCK = { r = 0.5, g = 0.35, b = 0.9 },
        MAGE = { r = 0.4, g = 0.6, b = 1.0 },
        DEATHKNIGHT = { r = 0.8, g = 0.1, b = 0.2 },
        EVOKER = { r = 0.6, g = 0.8, b = 1.0 },
        ChargedComboPoint = { r = 0.169, g = 0.733, b = 0.992 },
        RuneBlood = { r = 1.0, g = 0.2, b = 0.3 },
        RuneFrost = { r = 0.0, g = 0.6, b = 1.0 },
        RuneUnholy = { r = 0.1, g = 1.0, b = 0.1 },
        StaggerLow = { r = 0.52, g = 1.0, b = 0.52 },
        StaggerMedium = { r = 1.0, g = 0.98, b = 0.72 },
        StaggerHeavy = { r = 1.0, g = 0.42, b = 0.42 },
        SoulFragments = { r = 0.278, g = 0.125, b = 0.796 },
        SoulFragmentsVoidMeta = { r = 0.037, g = 0.220, b = 0.566 },
        EbonMight = { r = 0.2, g = 0.8, b = 0.4 },
        MaelstromWeapon = { r = 0.0, g = 0.5, b = 1.0 },
    },

    EmpowerStage = {
        [1] = { r = 0.7, g = 0.7, b = 0.3 },
        [2] = { r = 0.8, g = 0.5, b = 0.2 },
        [3] = { r = 0.9, g = 0.3, b = 0.1 },
        [4] = { r = 1.0, g = 0.2, b = 0.2 },
    },

    DebuffTypeColor = {
        ["none"] = { r = 0.80, g = 0, b = 0 },
        ["Magic"] = { r = 0.20, g = 0.60, b = 1.00 },
        ["Curse"] = { r = 0.60, g = 0.00, b = 1.00 },
        ["Disease"] = { r = 0.60, g = 0.40, b = 0 },
        ["Poison"] = { r = 0.00, g = 0.60, b = 0 },
        [""] = { r = 0.80, g = 0, b = 0 },
    },
}

-- Helper function for class resource colors
function C.Colors:GetResourceColor(classFileName)
    return self.PlayerResources[classFileName]
end

-- Helper function for power type colors (Mana, Rage, Energy, etc.)
function C.Colors:GetPowerColor(powerType)
    return self.PowerType[powerType] or { r = 0.5, g = 0.5, b = 0.5 }
end

-- [ BACKWARDS COMPATIBILITY ALIAS ]---------------------------------------------------------------
-- Orbit.Colors points to C.Colors for existing code
Orbit.Colors = C.Colors
