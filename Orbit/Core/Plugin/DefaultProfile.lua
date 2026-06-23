local _, Orbit = ...

-- [ DEFAULT PROFILE ]--------------------------------------------------------------------------------
-- Layout-only seed (positions, per-instance state, GlobalSettings) — not per-setting defaults; see Core/Plugin/README.md "default values".
Orbit.Profile = Orbit.Profile or {}
Orbit.Profile.defaults = {
    Layouts = {
        ["Orbit"] = {
            ["Orbit_PlayerCastBar"] = {
                [1] = { Anchor = false, Position = { y = 172, x = 0, point = "BOTTOM" } },
            },
            ["Orbit_QueueStatus"] = {
                ["Orbit_QueueStatus"] = { Anchor = false, Position = { y = -4, x = -343, point = "BOTTOMRIGHT" } },
            },
            ["Orbit_TalkingHead"] = {
                ["Orbit_TalkingHead"] = { Anchor = false, Position = { y = 233, x = 577, point = "LEFT" } },
            },
            ["Orbit_StatusWidget"] = {
                ["Orbit_StatusWidget"] = { Anchor = false, Position = { point = "TOPLEFT", x = 24, y = -24 } },
            },
            ["Orbit_MinimapButton"] = {
                ["Orbit_MinimapButton"] = { Anchor = false, Position = { y = -27, x = -22, point = "TOPRIGHT" } },
            },
            ["Orbit_DamageMeter"] = {
                [1] = {
                    -- Per-instance state, not schema settings; NormalizeMeterDefs backfills the rest from DM.DefaultDef, so only fields that differ are seeded here.
                    MeterDefs = {
                        [1] = {
                            id = 1, meterType = 0, sessionType = 0,
                            barCount = 7, barHeight = 34, border = 2, background = 2,
                            scrollOffset = 0, anchor = false,
                            position = { y = 52, x = -103, point = "BOTTOMRIGHT" },
                            disabledComponents = { "Status" },
                            componentPositions = {
                                Rank       = { posY = -2, offsetX = 4,  justifyH = "LEFT",  posX = -91, selfAnchorY = "CENTER", overrides = { FontSize = 8 },  offsetY = 0, anchorX = "LEFT",  anchorY = "CENTER" },
                                Name       = { posY = 0,  offsetX = 15, justifyH = "LEFT",  posX = -60, selfAnchorY = "CENTER", overrides = { FontSize = 12 }, offsetY = 0, anchorX = "LEFT",  anchorY = "CENTER" },
                                DPS        = { posY = 0,  offsetX = 52, justifyH = "RIGHT", posX = 48,  selfAnchorY = "CENTER", overrides = { FontSize = 12 }, offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                                DamageDone = { posY = 0,  offsetX = 4,  justifyH = "RIGHT", posX = 96,  selfAnchorY = "CENTER", overrides = { FontSize = 12 }, offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                            },
                        },
                        [2] = {
                            id = 2, meterType = 0, sessionType = 0,
                            barCount = 3, barHeight = 34, border = 2, background = 2,
                            scrollOffset = 0,
                            anchor = { target = "OrbitDamageMeter1", align = "CENTER", padding = 42, edge = "TOP", fallback = "OrbitDamageMeter1" },
                            disabledComponents = { "Status" },
                            componentPositions = {
                                Rank       = { posY = -1, offsetX = 4,  justifyH = "LEFT",  posX = -91, selfAnchorY = "CENTER", overrides = { FontSize = 8 },  offsetY = 0, anchorX = "LEFT",  anchorY = "CENTER" },
                                Name       = { posY = 0,  offsetX = 15, justifyH = "LEFT",  posX = -85, selfAnchorY = "CENTER", overrides = { FontSize = 12 }, offsetY = 0, anchorX = "LEFT",  anchorY = "CENTER" },
                                DPS        = { posY = 0,  offsetX = 52, justifyH = "RIGHT", posX = 48,  selfAnchorY = "CENTER", overrides = { FontSize = 12 }, offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                                DamageDone = { posY = 0,  offsetX = 4,  justifyH = "RIGHT", posX = 96,  selfAnchorY = "CENTER", overrides = { FontSize = 12 }, offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                            },
                        },
                    },
                },
            },
            ["Orbit_CooldownViewer"] = {
                [1] = { Anchor = false, Position = { y = 275, x = 0, point = "BOTTOM" } },
                [2] = {
                    Anchor = { target = "OrbitEssentialCooldowns", padding = 20, edge = "BOTTOM", align = "CENTER" },
                    -- Index-2-specific Stacks tweak that the shared schema can't carry.
                    ComponentPositions = {
                        Stacks = { posY = -11, offsetX = 1, justifyH = "LEFT", posX = -17, offsetY = 6, anchorX = "LEFT", anchorY = "BOTTOM" },
                    },
                },
                [3] = { Anchor = { target = "OrbitPlayerPower", padding = 20, edge = "TOP", align = "CENTER" } },
                [4] = {
                    Anchor = false, Position = { y = 0, x = -32, point = "CENTER" },
                    ComponentPositions = {
                        Stacks = { posY = -14, offsetX = 0, posX = 15, justifyH = "RIGHT", offsetY = 5, anchorX = "RIGHT", anchorY = "BOTTOM" },
                    },
                },
                [30] = { Anchor = false, Position = { y = -190, x = -325, point = "CENTER" } },
            },
            ["Orbit_BagBar"] = {
                ["Orbit_BagBar"] = {
                    Anchor = { target = "OrbitMicroMenuContainer", padding = 2, edge = "TOP", align = "RIGHT" },
                },
            },
            ["Orbit_TargetDebuffs"] = {
                [1] = { Anchor = { target = "OrbitTargetCastBar", padding = 2, edge = "TOP", align = "LEFT" } },
            },
            ["Orbit_Tour"] = {
                ["A"] = { Anchor = false, Position = { y = 9, x = -89, point = "CENTER" } },
                ["B"] = { Anchor = { target = "OrbitTourFrameA", fallback = "OrbitTourFrameA", padding = 44, edge = "RIGHT", align = "BOTTOM" } },
            },
            ["Orbit_TargetOfFocusFrame"] = {
                [101] = { Anchor = { target = "OrbitFocusBuffsFrame", padding = 10, edge = "BOTTOM", align = "RIGHT" } },
            },
            ["Orbit_FocusPower"] = {
                [1] = { Anchor = { target = "OrbitFocusFrame", padding = 0, edge = "BOTTOM", align = "CENTER" } },
            },
            ["Orbit_Minimap"] = {
                ["Orbit_Minimap"] = { Anchor = false, Position = { y = -3, x = -3, point = "TOPRIGHT" } },
            },
            ["Orbit_FocusFrame"] = {
                [3] = { Anchor = { target = "OrbitTargetFrame", padding = 42, edge = "RIGHT", align = "CENTER" } },
            },
            ["Orbit_FocusDebuffs"] = {
                [1] = {
                    Anchor = { target = "OrbitFocusCastBar", padding = 2, edge = "TOP", align = "LEFT" },
                    -- Per-plugin override: FocusDebuffs wants a distinct red from TargetDebuffs's shared sharedDebuffDefaults curve, but both share the same mixin.
                    PandemicGlowColorCurve = { pins = { { color = { a = 1, r = 1, g = 0.165, b = 0 }, position = 0.5 } } },
                },
            },
            ["Orbit_GroupFrames"] = {
                [1] = {
                    Anchor = false,
                    Position = { y = -118, x = 98, point = "TOPLEFT" },
                    _EditTier = "Party",
                    Tiers = {
                        Mythic = { Position = { y = -130, x = 54, point = "TOPLEFT" } },
                        Party  = { Position = { y = -130, x = 54, point = "TOPLEFT" } },
                        Heroic = { Anchor = false, Position = { y = -253, x = 350, point = "TOPLEFT" } },
                        World  = { Position = { y = -130, x = 54, point = "TOPLEFT" } },
                    },
                },
            },
            ["Orbit_TargetPower"] = {
                [1] = {
                    Anchor = { target = "OrbitTargetFrame", padding = 0, edge = "BOTTOM", align = "RIGHT" },
                    -- Width=205 conflicts with FocusPower's shared default of 200; lives here as per-plugin override.
                    Width = 205,
                },
            },
            ["Orbit_ActionBars"] = {
                [1] = { Anchor = false, Position = { y = 42, x = 0, point = "BOTTOM" } },
                [2] = { Anchor = { align = "LEFT", target = "OrbitActionBar1", fallback = "OrbitActionBar1", edge = "TOP", padding = 1 } },
                [3] = { Anchor = { target = "OrbitActionBar2", padding = 40, edge = "LEFT", align = "TOP" }, NumIcons = 8, Rows = 2 },
                [4] = { Anchor = { target = "OrbitActionBar2", padding = 40, edge = "RIGHT", align = "TOP" }, NumIcons = 8, Rows = 2 },
                [5] = { Anchor = { align = "CENTER", target = "OrbitActionBar6", fallback = "OrbitActionBar6", edge = "LEFT", padding = 1 }, Rows = 12 },
                [6] = { Anchor = false, Position = { y = -48, x = -2, point = "RIGHT" }, Rows = 12 },
                [7] = { Anchor = false, Position = { y = -45, x = -91, point = "RIGHT" }, Scale = 90, Rows = 12, IconPadding = 2 },
                [8] = { Anchor = false, Position = { y = -46, x = -45, point = "RIGHT" }, Scale = 90, Rows = 12, IconPadding = 2 },
                [9] = { Anchor = { align = "CENTER", target = "OrbitActionBar2", fallback = "OrbitActionBar1", edge = "TOP", padding = 4, ancestry = { "OrbitActionBar1" } }, Scale = 80, HideEmptyButtons = true, IconPadding = 2, IconSize = 24 },
                [10] = { Anchor = { target = "OrbitActionBar3", padding = 2, edge = "TOP", align = "LEFT" }, IconPadding = 2 },
                [11] = { Anchor = { target = "OrbitActionBar4", padding = 2, edge = "TOP", align = "RIGHT" }, IconPadding = 2 },
                [12] = { Anchor = false, Position = { y = 271, x = -252, point = "BOTTOM" }, IconPadding = 2 },
                [13] = { Anchor = { target = "OrbitActionBar4", padding = 2, edge = "TOP", align = "LEFT" } },
            },
            ["Orbit_PlayerFrame"] = {
                [1] = { Anchor = { target = "OrbitEssentialCooldowns", padding = 150, edge = "LEFT", align = "BOTTOM" } },
            },
            ["Orbit_PlayerDebuffs"] = {
                [1] = { Anchor = { target = "OrbitPlayerBuffsFrame", fallback = "OrbitPlayerBuffsFrame", padding = 4, edge = "BOTTOM", align = "CENTER" } },
            },
            ["Orbit_PlayerPower"] = {
                [1] = { Anchor = { target = "OrbitPlayerResources", padding = 2, edge = "TOP", align = "CENTER" } },
            },
            ["Orbit_PlayerResources"] = {
                [1] = { Anchor = { target = "OrbitEssentialCooldowns", padding = 2, edge = "TOP", align = "CENTER" } },
            },
            ["Orbit_Portal"] = {
                [1] = { Anchor = false, Position = { y = 0, x = 8, point = "LEFT" } },
            },
            ["Orbit_TargetBuffs"] = {
                [1] = { Anchor = { target = "OrbitTargetPower", padding = 3, edge = "BOTTOM", align = "LEFT" } },
            },
            ["Orbit_MicroMenu"] = {
                ["Orbit_MicroMenu"] = { Anchor = false, Position = { y = 1, x = 0, point = "BOTTOMRIGHT" } },
            },
            ["Orbit_RaidPanel"] = {
                [1] = { Anchor = false, Position = { y = 0, x = 77, point = "LEFT" } },
            },
            ["Orbit_TargetCastBar"] = {
                [1] = { Anchor = { target = "OrbitTargetFrame", padding = 0, edge = "TOP", align = "CENTER" } },
            },
            ["Orbit_TargetFrame"] = {
                [2] = { Anchor = { target = "OrbitEssentialCooldowns", padding = 150, edge = "RIGHT", align = "BOTTOM" } },
            },
            ["Orbit_BossFrames"] = {
                [1] = { Anchor = false, Position = { y = 0, x = 480, point = "CENTER" } },
            },
            ["Orbit_TargetOfTargetFrame"] = {
                [100] = { Anchor = { target = "OrbitTargetBuffsFrame", padding = 10, edge = "BOTTOM", align = "RIGHT" } },
            },
            ["Orbit_FocusBuffs"] = {
                [1] = { Anchor = { target = "OrbitFocusPower", padding = 3, edge = "BOTTOM", align = "LEFT" } },
            },
            ["Orbit_FocusCastBar"] = {
                [1] = { Anchor = { target = "OrbitFocusFrame", padding = 0, edge = "TOP", align = "LEFT" } },
            },
            ["Orbit_PlayerBuffs"] = {
                [1] = { Anchor = false, Position = { y = -7, x = 0, point = "TOP" } },
            },
            ["Orbit_PlayerPetFrame"] = {
                [8] = { Anchor = { target = "OrbitPlayerFrame", padding = 10, edge = "BOTTOM", align = "LEFT" } },
            },
            ["Orbit_Datatexts"] = {
                [1] = {
                    -- datatextPositions is per-instance placement state, no schema seed.
                    datatextPositions = {
                        Performance = { placed = true, x = -567, y = 63, point = "BOTTOMRIGHT", scale = 1 },
                        Spec        = { placed = true, x = 573,  y = 56, point = "BOTTOMLEFT",  scale = 1 },
                        Hearthstone = { placed = true, x = -515, y = 47, point = "BOTTOMRIGHT", scale = 1.23 },
                        CombatTimer = { placed = true, x = 314,  y = 66, point = "BOTTOMLEFT",  scale = 1.83 },
                        Time = { placed = false }, Gold = { placed = false }, Speed = { placed = false },
                        ItemLevel = { placed = false }, Crit = { placed = false }, Volume = { placed = false },
                        Friends = { placed = false }, Mastery = { placed = false }, Versatility = { placed = false },
                        Location = { placed = false }, Quests = { placed = false }, Mail = { placed = false },
                        Durability = { placed = false }, Guild = { placed = false }, Haste = { placed = false },
                        BagSpace = { placed = false },
                    },
                },
            },
            ["Orbit_StrataEngine"] = {
                ["Global_HUD"] = {
                    entities = {
                        "Orbit_PlayerFrame", "Orbit_TargetFrame", "Orbit_PlayerPetFrame", "Orbit_GroupFrames",
                        "Orbit_BossFrames", "Orbit_ActionBars", "Orbit_CooldownViewer",
                        "Orbit_Minimap", "Orbit_Datatexts",
                    },
                },
            },
        },
    },
    DisabledPlugins = {},
    HideBlizzardFrames = {},
    GlobalSettings = {
        OverlayTexture = "Orbit Starfield Overlay", AbsorbTexture = "Orbit Absorb", TourComplete = false,
        UnitHealthUseGradient = false,
        BarColorCurve = {
            pins = { { color = { a = 1, b = 1, g = 1, r = 1 }, type = "class", position = 0 } },
        },
        BarColor = { a = 1, b = 0.2, g = 0.8, r = 0.2 },
        AbsorbColor = { a = 0.85, r = 0.165, g = 0.71, b = 1 },
        AlwaysShowAbsorb = true,
        Font = "Barlow Condensed Bold", HideWhenMounted = false, BorderSize = 1,
        PixelBorderSize = 1, IconPixelBorderSize = 1,
        ClassColorBackground = false, IconBorderSize = 1, OverlayAllFrames = false,
        IconBorderColor = { none = true },
        FontOutline = "OUTLINE", FontShadow = false, UseClassColors = true, Texture = "Orbit Gradient Top-Bottom",
        TrackedContainers = {}, NextTrackedContainerId = 1000,
    },
}
