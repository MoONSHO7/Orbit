local _, Orbit = ...

-- [ DEFAULT PROFILE ]-------------------------------------------------------------------------------
Orbit.Profile = Orbit.Profile or {}
Orbit.Profile.defaults = {
    Layouts = {
        ["Orbit"] = {
            ["Orbit_PlayerCastBar"] = {
                [1] = {
                    CastBarHeight = 35,
                    SparkColorCurve = {
                        pins = { { color = { a = 0.264, b = 1, g = 1, r = 1 }, position = 0.5 } },
                        _sorted = { { color = { a = 0.264, b = 1, g = 1, r = 1 }, position = 0.5 } },
                    },
                    ShowLatency = false,
                    CastBarColorCurve = {
                        pins = { { color = { a = 1, b = 0, g = 0.7, r = 1 }, position = 0 } },
                    },
                    CastBarWidth = 300,
                    Position = { y = 135.66, x = 0, point = "BOTTOM" },
                    Anchor = false,
                    CastBarTimer = true,
                    CastBarText = true,
                    CastBarTextSize = 10,
                },
            },
            ["Orbit_QueueStatus"] = {
                ["Orbit_QueueStatus"] = {
                    Anchor = false,
                    Position = { y = -4, x = -343, point = "BOTTOMRIGHT" },
                },
            },
            ["Orbit_TalkingHead"] = {
                ["Orbit_TalkingHead"] = {
                    Anchor = false,
                    Scale = 60,
                    Position = { y = -123, x = 0, point = "TOP" },
                },
            },
            ["Orbit_CooldownViewer"] = {
                [1] = {
                    IconLimit = 12,
                    ProcGlowColor = { a = 1, r = 1, g = 0.8, b = 0 },
                    IconPadding = 0,
                    ShowGCDSwipe = true,
                    KeypressColor = { a = 0.492, r = 1, g = 1, b = 1 },
                    Opacity = 100,
                    PandemicGlowType = 1,
                    DisabledComponents = { "Status", "Keybind" },
                    ActiveSwipeColorCurve = {
                        pins = { { color = { a = 0.77, r = 1, g = 0.91, b = 0.28 }, position = 0.5 } },
                        _sorted = { { color = { a = 0.77, r = 1, g = 0.91, b = 0.28 }, position = 0.5 } },
                    },
                    aspectRatio = "4:3",
                    Anchor = false,
                    Position = { y = 274.6, x = 0.27, point = "BOTTOM" },
                    IconSize = 100,
                    CooldownSwipeColorCurve = {
                        pins = { { color = { a = 0.821, r = 0, g = 0, b = 0 }, position = 0.5 } },
                        _sorted = { { color = { a = 0.821, r = 0, g = 0, b = 0 }, position = 0.5 } },
                    },
                    ComponentPositions = {
                        Timer = { offsetX = 0, justifyH = "CENTER", posY = 0, posX = 0, offsetY = 0, selfAnchorY = "CENTER", anchorX = "CENTER", anchorY = "CENTER" },
                        Charges = { offsetX = 1, justifyH = "RIGHT", posY = -10, posX = 15, offsetY = 5, selfAnchorY = "BOTTOM", anchorX = "RIGHT", anchorY = "BOTTOM" },
                        Stacks = { offsetX = 1, justifyH = "LEFT", posY = -10, posX = -15, offsetY = 5, selfAnchorY = "BOTTOM", anchorX = "LEFT", anchorY = "BOTTOM" },
                    },
                    PandemicGlowColor = { a = 1, r = 1, g = 0.102, b = 0 },
                },
                [2] = {
                    IconLimit = 8,
                    Opacity = 100,
                    PandemicGlowType = 2,
                    ActiveSwipeColorCurve = {
                        pins = { { color = { a = 0.77, b = 0.569, g = 0.949, r = 1 }, position = 0.434 } },
                        _sorted = { { color = { a = 0.77, b = 0.569, g = 0.949, r = 1 }, position = 0.434 } },
                    },
                    aspectRatio = "4:3",
                    IconSize = 100,
                    Position = { y = 213.88, x = 0, point = "BOTTOM" },
                    CooldownSwipeColorCurve = {
                        pins = { { color = { a = 0.8, b = 0, g = 0, r = 0 }, position = 0.465 } },
                        _sorted = { { color = { a = 0.8, b = 0, g = 0, r = 0 }, position = 0.465 } },
                    },
                    Anchor = false,
                    ComponentPositions = {
                        Timer = { posY = 0, offsetX = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        Charges = { posY = -10, offsetX = 1, posX = 15, justifyH = "RIGHT", offsetY = 5, anchorX = "RIGHT", anchorY = "BOTTOM" },
                        Stacks = { posY = -11, offsetX = 1, posX = -17, justifyH = "LEFT", offsetY = 6, anchorX = "LEFT", anchorY = "BOTTOM" },
                    },
                    IconPadding = 2,
                },
                [3] = {
                    IconLimit = 10,
                    PandemicGlowColor = { a = 1, b = 0, g = 0.22, r = 1 },
                    IconPadding = 1,
                    DisabledComponents = { "Status", "Keybind" },
                    ActiveSwipeColorCurve = {
                        pins = { { color = { a = 0.77, b = 0.569, g = 0.949, r = 1 }, position = 0.434 } },
                        _sorted = { { color = { a = 0.77, b = 0.569, g = 0.949, r = 1 }, position = 0.434 } },
                    },
                    aspectRatio = "4:3",
                    PandemicGlowType = 1,
                    CooldownSwipeColorCurve = {
                        pins = { { color = { a = 0.8, b = 0, g = 0, r = 0 }, position = 0.465 } },
                        _sorted = { { color = { a = 0.8, b = 0, g = 0, r = 0 }, position = 0.465 } },
                    },
                    Anchor = { target = "OrbitPlayerPower", padding = 15, edge = "TOP", align = "CENTER" },
                    IconSize = 100,
                    ComponentPositions = {
                        Timer = { posY = 0, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        Charges = { posY = -10, offsetX = 1, justifyH = "RIGHT", posX = 15, selfAnchorY = "BOTTOM", offsetY = 5, anchorX = "RIGHT", anchorY = "BOTTOM" },
                        Stacks = { posY = -10, offsetX = 1, justifyH = "LEFT", posX = -15, selfAnchorY = "BOTTOM", offsetY = 5, anchorX = "LEFT", anchorY = "BOTTOM" },
                    },
                    Opacity = 100,
                },
                [4] = {
                    aspectRatio = "1:1",
                    Position = { y = -0.273, x = -32, point = "CENTER" },
                    Anchor = false,
                    ComponentPositions = {
                        Timer = { posY = 0, offsetX = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        Stacks = { posY = -13.55, offsetX = 0, posX = 14.62, justifyH = "RIGHT", offsetY = 5, anchorX = "RIGHT", anchorY = "BOTTOM" },
                    },
                    DisabledComponents = { "Status", "Keybind" },
                },
                [20] = {
                    ComponentPositions = {
                        ChargeCount = { posY = 0, offsetX = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                    },
                    DisabledComponents = { "Status" },
                },
                [30] = {
                    BarColor1 = {
                        pins = { { color = { a = 1, r = 1, g = 0.702, b = 0.302 }, position = 0.5 } },
                        _sorted = { { color = { a = 1, r = 1, g = 0.702, b = 0.302 }, position = 0.5 } },
                    },
                    BarColor4 = { pins = { { color = { a = 1, r = 1, g = 0.702, b = 0.302 }, position = 0.5 } } },
                    DisabledComponents = { "Status" },
                    BarColor5 = { pins = { { color = { a = 1, r = 1, g = 0.702, b = 0.302 }, position = 0.5 } } },
                    Height = 22,
                    ComponentPositions = {
                        BuffBarName = { posY = 0, offsetX = 25, posX = -46.56, justifyH = "LEFT", offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        BuffBarTimer = { posY = 0, offsetX = 5, posX = 85.7, justifyH = "RIGHT", offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                    },
                    Position = { y = -227.56, x = -275.69, point = "CENTER" },
                    BarColor3 = { pins = { { color = { a = 1, r = 1, g = 0.702, b = 0.302 }, position = 0.5 } } },
                    Anchor = false,
                    BarColor2 = {
                        pins = { { color = { a = 1, r = 1, g = 0.702, b = 0.302 }, position = 0.5 } },
                        _sorted = { { color = { a = 1, r = 1, g = 0.702, b = 0.302 }, position = 0.5 } },
                    },
                    Spacing = 8,
                },
            },
            ["Orbit_BagBar"] = {
                ["Orbit_BagBar"] = {
                    Anchor = { target = "OrbitMicroMenuContainer", padding = 2, edge = "TOP", align = "RIGHT" },
                    Opacity = 100, Scale = 100,
                },
            },
            ["Orbit_Status"] = {
                [1] = { Height = 16, Position = "TOP" },
            },
            ["Orbit_TargetDebuffs"] = {
                [1] = {
                    MaxRows = 1,
                    PandemicGlowColorCurve = {
                        pins = { { color = { a = 1, r = 1, g = 0.227, b = 0 }, position = 0.5 } },
                        _sorted = { { color = { a = 1, r = 1, g = 0.227, b = 0 }, position = 0.5 } },
                    },
                    Scale = 100,
                    Anchor = { target = "OrbitTargetCastBar", padding = 2, edge = "TOP", align = "LEFT" },
                    PandemicGlowType = 1, IconsPerRow = 5,
                },
            },
            ["Orbit_Tour"] = {
                ["A"] = { Height = 46, Anchor = false, Position = { y = 751.04, x = 892.72, point = "BOTTOMLEFT" }, Width = 155 },
                ["B"] = { Height = 50, Anchor = { target = "OrbitTourFrameA", padding = 6, edge = "RIGHT", align = "TOP" }, Width = 150 },
            },
            ["Orbit_TargetOfFocusFrame"] = {
                [101] = {
                    DisabledComponents = { "HealthText" }, Height = 20,
                    Anchor = { target = "OrbitFocusBuffsFrame", padding = 10, edge = "BOTTOM", align = "RIGHT" },
                    ComponentPositions = { Name = { offsetX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" } },
                    Width = 100,
                },
            },
            ["Orbit_CombatTimer"] = {
                ["Orbit_CombatTimer"] = {
                    Anchor = { target = "OrbitActionBar3", padding = 15, edge = "LEFT", align = "CENTER" },
                    Opacity = 100, Scale = 100,
                    Position = { y = 0, relativeTo = "OrbitActionBar3", point = "RIGHT", relativePoint = "LEFT", x = -9 },
                },
            },
            ["Orbit_FocusPower"] = {
                [1] = {
                    Height = 7, Anchor = { target = "OrbitFocusFrame", padding = 0, edge = "BOTTOM", align = "CENTER" },
                    ShowText = true, Width = 200,
                },
            },
            ["Orbit_Minimap"] = {
                ["Orbit_Minimap"] = {
                    Anchor = false, Scale = 100, Opacity = 100, Size = 220,
                    DifficultyDisplay = "icon", DifficultyShowBackground = false, ZoneTextColoring = true, DisabledComponents = { "Status" },
                    ComponentPositions = {
                        Compartment = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 15, offsetY = -10, posX = 110.0000305175781, posY = -135.0000305175781, justifyH = "RIGHT", selfAnchorY = "BOTTOM" },
                        Zoom = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 15, offsetY = 35, posX = 110.0000305175781, posY = -90.00003051757812, justifyH = "RIGHT", selfAnchorY = "BOTTOM" },
                        Missions = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 20, offsetY = 20, posX = -105.0000305175781, posY = -105.0000305175781, justifyH = "CENTER", selfAnchorY = "BOTTOM" },
                        Coords = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 30, offsetY = 10, posX = 95.00003051757812, posY = -115.0000305175781, justifyH = "RIGHT", selfAnchorY = "BOTTOM" },
                        CraftingOrder = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 20, offsetY = 38, posX = 105.0000305175781, posY = 87.00003051757812, justifyH = "CENTER", selfAnchorY = "TOP" },
                        DifficultyIcon = { anchorX = "LEFT", anchorY = "TOP", offsetX = 20, offsetY = 20, posX = -105.0000305175781, posY = 105.0000305175781, justifyH = "LEFT", selfAnchorY = "TOP", overrides = { IconSize = 42 } },
                        Mail = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 20, offsetY = 20, posX = 105.0000305175781, posY = 105.0000305175781, justifyH = "CENTER", selfAnchorY = "TOP" },
                        DifficultyText = { anchorX = "LEFT", anchorY = "TOP", offsetX = 20, offsetY = 20, posX = -105.0000305175781, posY = 105.0000305175781, justifyH = "LEFT", selfAnchorY = "TOP" },
                        Clock = { anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 10, posX = 0, posY = -115.0000305175781, justifyH = "CENTER", selfAnchorY = "BOTTOM" },
                        ZoneText = { anchorX = "CENTER", anchorY = "TOP", offsetX = 0, offsetY = 10, posX = 0, posY = 115.0000305175781, justifyH = "CENTER", selfAnchorY = "TOP", overrides = { FontSize = 18 } },
                    },
                    Position = { y = 0, x = -5, point = "TOPRIGHT" },
                },
            },
            ["Orbit_FocusFrame"] = {
                [3] = {
                    EnableFocusTarget = false, EnableFocusPower = true, ReactionColour = false, PortraitStyle = "3d",
                    DisabledComponents = { "Portrait", "Status" }, Width = 99, Is3D = true, PortraitBorder = true,
                    PortraitShape = "square", EnableBuffs = false, Height = 26, PortraitScale = 125,
                    ComponentPositions = {
                        RareEliteIcon = { posY = -5.21, offsetX = -0.77, justifyH = "LEFT", posX = 49.18, selfAnchorY = "BOTTOM", offsetY = 6.82, anchorX = "RIGHT", anchorY = "BOTTOM" },
                        Name = { posY = 0, offsetX = 5, justifyH = "LEFT", posX = -44.5, selfAnchorY = "CENTER", offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        Portrait = { offsetX = 4, offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        HealthText = { posY = 0, offsetX = 5, justifyH = "RIGHT", posX = 44.5, selfAnchorY = "CENTER", offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                        MarkerIcon = { posY = 13.13, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "TOP", offsetY = 0, anchorX = "CENTER", anchorY = "TOP" },
                        LevelText = { posY = 6.58, offsetX = -4.71, justifyH = "RIGHT", posX = 47.79, selfAnchorY = "TOP", offsetY = 5.45, anchorX = "RIGHT", anchorY = "TOP" },
                    },
                    Anchor = { target = "OrbitTargetFrame", padding = 42, edge = "RIGHT", align = "CENTER" },
                },
            },
            ["Orbit_FocusDebuffs"] = {
                [1] = {
                    MaxRows = 1, PandemicGlowColorCurve = { pins = { { color = { a = 1, r = 1, g = 0.165, b = 0 }, position = 0.5 } } },
                    Spacing = 2, IconsPerRow = 5, Scale = 100, PandemicGlowType = 1,
                    Anchor = { target = "OrbitFocusCastBar", padding = 2, edge = "TOP", align = "LEFT" },
                },
            },
            ["Orbit_RaidFrames"] = {
                [1] = {
                    GroupsPerRow = 6, DisabledComponents = { "DefensiveIcon", "CrowdControlIcon", "Status", "HealerAura1", "HealerAura2", "HealerAura3", "HealerAura4", "HealerAura5", "HealerAura6", "HealerAura7", "RaidBuff" },
                    GroupSpacing = 2, UpdateRate = 0.2, ShowHealthValue = false, DispelFrequency = 0.2, Anchor = false, MemberSpacing = 2,
                    Position = { y = -118.2, x = 97.9, point = "TOPLEFT" }, Height = 40, Orientation = "Horizontal",
                    ComponentPositions = {
                        ResIcon = { offsetX = 0, posY = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        Debuffs = { posY = -15, selfAnchorY = "BOTTOM", anchorX = "LEFT", justifyH = "LEFT", posX = -45, overrides = { MaxIcons = 2, MaxRows = 1, FilterDensity = 1, IconSize = 20 }, offsetY = 0, offsetX = 0, anchorY = "BOTTOM" },
                        LeaderIcon = { posY = 19.97, selfAnchorY = "TOP", anchorX = "LEFT", justifyH = "LEFT", posX = -42.05, overrides = { Scale = 0.8 }, offsetY = 0, offsetX = 8, anchorY = "TOP" },
                        HealthText = { posY = -10.17, selfAnchorY = "BOTTOM", anchorX = "CENTER", justifyH = "CENTER", posX = 0, overrides = { FontSize = 10, HealthTextMode = "percent_short", ShowHealthValue = false }, offsetY = 9.8, offsetX = 0, anchorY = "BOTTOM" },
                        CrowdControlIcon = { offsetX = 0, offsetY = 2, anchorX = "CENTER", anchorY = "TOP" },
                        StatusIcons = { posY = 0, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        PrivateAuraAnchor = { posY = 0, selfAnchorY = "CENTER", anchorX = "CENTER", justifyH = "CENTER", posX = 0, overrides = { Scale = 1, IconSize = 24 }, offsetY = 0, offsetX = 0, anchorY = "CENTER" },
                        PhaseIcon = { offsetX = 0, posY = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        RoleIcon = { posY = 14.97, selfAnchorY = "TOP", anchorX = "RIGHT", justifyH = "RIGHT", posX = 45.05, overrides = { Scale = 0.7 }, offsetY = 5, offsetX = 5, anchorY = "TOP" },
                        DefensiveIcon = { offsetX = 2, offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        SummonIcon = { offsetX = 0, posY = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        Name = { posY = 9.97, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "TOP", offsetY = 10, anchorX = "CENTER", anchorY = "TOP" },
                        Status = { offsetX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        MarkerIcon = { posY = 20.97, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "TOP", offsetY = -1, anchorX = "CENTER", anchorY = "TOP" },
                        Buffs = { posY = -15, selfAnchorY = "BOTTOM", anchorX = "RIGHT", justifyH = "RIGHT", posX = 35, overrides = { MaxIcons = 4, MaxRows = 1, FilterDensity = 1, IconSize = 20 }, offsetY = 0, offsetX = 0, anchorY = "BOTTOM" },
                        ReadyCheckIcon = { offsetX = 0, posY = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        MainTankIcon = { posY = 19.47, selfAnchorY = "TOP", anchorX = "LEFT", justifyH = "LEFT", posX = -33.05, overrides = { Scale = 0.6 }, offsetY = 0.5, offsetX = 17, anchorY = "TOP" },
                    },
                    Width = 100,
                },
            },
            ["Orbit_TargetPower"] = {
                [1] = {
                    Anchor = { target = "OrbitTargetFrame", padding = 0, edge = "BOTTOM", align = "RIGHT" },
                    Height = 7, ShowText = true, Width = 205,
                },
            },
            ["Orbit_ActionBars"] = {
                [1] = {
                    GlobalComponentPositions = {
                        Timer = { posY = 0, selfAnchorY = "CENTER", anchorX = "CENTER", justifyH = "CENTER", posX = 0, overrides = { FontSize = 18 }, offsetY = 0, offsetX = 0, anchorY = "CENTER" },
                        Stacks = { justifyH = "RIGHT", posY = -10, offsetX = 0, posX = 10, selfAnchorY = "BOTTOM", offsetY = 5, anchorX = "RIGHT", anchorY = "BOTTOM" },
                        MacroText = { posY = -14, selfAnchorY = "BOTTOM", anchorX = "LEFT", justifyH = "LEFT", posX = -7, overrides = { FontSize = 10 }, offsetY = 6, offsetX = 1, anchorY = "BOTTOM" },
                        Keybind = { justifyH = "RIGHT", posY = 10, offsetX = 0, posX = 10, selfAnchorY = "TOP", offsetY = 5, anchorX = "RIGHT", anchorY = "TOP" },
                    },
                    GlobalDisabledComponents = { "Status" }, Scale = 100, Opacity = 100, IconPadding = 0, UseGlobalTextStyle = true,
                    Position = { y = 35.01, x = 0, point = "BOTTOM" }, Anchor = false, NumIcons = 12, Rows = 1, NumActionBars = 6,
                },
                [2] = { Scale = 100, Anchor = { target = "OrbitActionBar1", padding = 0, edge = "TOP", align = "LEFT" }, Rows = 1, IconPadding = 0, NumIcons = 12 },
                [3] = { Scale = 100, NumIcons = 8, Anchor = { target = "OrbitActionBar2", padding = 40, edge = "LEFT", align = "TOP" }, Rows = 2, IconPadding = 0, Opacity = 100 },
                [4] = { Scale = 100, NumIcons = 8, Anchor = { target = "OrbitActionBar2", padding = 40, edge = "RIGHT", align = "TOP" }, Rows = 2, IconPadding = 0, Opacity = 100 },
                [5] = { UseGlobalTextStyle = true, Scale = 100, Rows = 1, IconPadding = 0, Position = { y = -3.28, x = 4.92, point = "TOPLEFT" }, Anchor = false, NumIcons = 12, HideEmptyButtons = false, Opacity = 100 },
                [6] = { Position = { y = -48.41, x = -2.19, point = "RIGHT" }, Scale = 100, Rows = 12, IconPadding = 0, Anchor = false },
                [7] = { Position = { y = -45.13, x = -90.8, point = "RIGHT" }, Scale = 90, Rows = 12, IconPadding = 2, Anchor = false },
                [8] = { Rows = 12, Position = { y = -45.68, x = -45.4, point = "RIGHT" }, Scale = 90, NumIcons = 12, IconPadding = 2, Anchor = false },
                [9] = { Scale = 80, OutOfCombatFade = false, HideEmptyButtons = true, Anchor = { target = "OrbitActionBar2", padding = 2, edge = "TOP", align = "CENTER" }, Opacity = 100, IconPadding = 2, Rows = 1 },
                [10] = { Scale = 100, Anchor = { target = "OrbitActionBar3", padding = 2, edge = "TOP", align = "LEFT" }, Opacity = 100, IconPadding = 2, Rows = 1 },
                [11] = { Scale = 100, Rows = 1, IconPadding = 2, Anchor = { target = "OrbitActionBar4", padding = 2, edge = "TOP", align = "RIGHT" } },
                [12] = { Anchor = false, Opacity = 100, IconPadding = 2, Position = { y = 271, x = -252, point = "BOTTOM" } },
                [13] = { Scale = 100, Anchor = { target = "OrbitActionBar4", padding = 2, edge = "TOP", align = "LEFT" } },
            },
            ["Orbit_PlayerFrame"] = {
                [1] = {
                    ShowCombatIcon = true, PortraitStyle = "3d",
                    ComponentPositions = {
                        LevelText = { posY = 12.05, offsetX = 5, justifyH = "LEFT", posX = 74.86, selfAnchorY = "TOP", offsetY = 6, anchorX = "RIGHT", anchorY = "TOP" },
                        GroupPositionText = { posY = -10.96, offsetX = 5, justifyH = "LEFT", posX = 73.77, selfAnchorY = "BOTTOM", offsetY = 6, anchorX = "RIGHT", anchorY = "BOTTOM" },
                        LeaderIcon = { posY = 18.05, offsetX = 10, justifyH = "LEFT", posX = -69.86, selfAnchorY = "TOP", offsetY = 0, anchorX = "LEFT", anchorY = "TOP" },
                        PvpIcon = { posY = -23.05, selfAnchorY = "BOTTOM", anchorX = "RIGHT", justifyH = "RIGHT", posX = 54.86, overrides = { Scale = 1.5 }, offsetY = -5, offsetX = 25, anchorY = "BOTTOM" },
                        HealthText = { posY = 0, offsetX = 4.9, justifyH = "RIGHT", posX = 74.96, selfAnchorY = "CENTER", offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                        RestingIcon = { posY = 13.05, selfAnchorY = "TOP", anchorX = "LEFT", justifyH = "LEFT", posX = -69.86, overrides = { Scale = 0.5 }, offsetY = 5, offsetX = 10, anchorY = "TOP" },
                        Name = { posY = 0, offsetX = 5, justifyH = "LEFT", posX = -74.86, selfAnchorY = "CENTER", offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        RoleIcon = { offsetX = 10, offsetY = 3, anchorX = "RIGHT", anchorY = "TOP" },
                        CombatIcon = { posY = 0, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        Portrait = { offsetX = 4, offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        ReadyCheckIcon = { posY = 0, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        MarkerIcon = { posY = 18.05, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "TOP", offsetY = 0, anchorX = "CENTER", anchorY = "TOP" },
                    },
                    PortraitMirror = false, ShowAbsorbs = true, ShowHealAbsorbs = true, DisabledComponents = { "Status", "Portrait", "RoleIcon" },
                    Width = 160, Is3D = true, PortraitBorder = true, PortraitShape = "square",
                    Anchor = { target = "OrbitEssentialCooldowns", padding = 100, edge = "LEFT", align = "BOTTOM" },
                    Height = 30, PortraitScale = 155, TextSize = 12, ShowLevel = true,
                },
            },
            ["Orbit_PlayerDebuffs"] = {
                [1] = { Anchor = false, Spacing = 0, IconLimit = 10, Position = { y = -3.28, x = -234.12, point = "TOPRIGHT" } },
            },
            ["Orbit_PlayerPower"] = {
                [1] = {
                    ShowText = false, Height = 12, Anchor = { target = "OrbitPlayerResources", padding = 2, edge = "TOP", align = "CENTER" },
                    DisabledComponents = { "Status" },
                    ComponentPositions = { Text = { justifyH = "RIGHT", posY = 0, offsetX = 4.92, posX = 134.84, selfAnchorY = "CENTER", offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" } },
                    Width = 200,
                },
            },
            ["Orbit_Portal"] = {
                [1] = { Anchor = false, Position = { y = -118, x = 11, point = "TOPLEFT" } },
            },
            ["Orbit_TargetBuffs"] = {
                [1] = { MaxRows = 2, Spacing = 2, Anchor = { target = "OrbitTargetPower", padding = 3, edge = "BOTTOM", align = "LEFT" }, IconsPerRow = 8, Scale = 100 },
            },
            ["Orbit_MicroMenu"] = {
                ["Orbit_MicroMenu"] = { Anchor = false, Padding = -5, Rows = 1, Position = { y = 1, x = 0, point = "BOTTOMRIGHT" } },
            },
            ["Orbit_TargetCastBar"] = {
                [1] = { Anchor = { target = "OrbitTargetFrame", padding = 0, edge = "TOP", align = "CENTER" }, CastBarHeight = 18, CastBarTextSize = 10 },
            },
            ["Orbit_TargetFrame"] = {
                [2] = {
                    PortraitMirror = true, AuraSize = 20, Is3D = false, PortraitStyle = "2d", DisabledComponents = { "Portrait", "Status" },
                    PortraitShape = "square", EnableTargetPower = true, PortraitBorder = true, MaxBuffs = 16, Height = 36,
                    Anchor = { target = "OrbitEssentialCooldowns", padding = 100, edge = "RIGHT", align = "CENTER" },
                    PortraitScale = 125,
                    ComponentPositions = {
                        RareEliteIcon = { posY = -10.05, offsetX = 0, justifyH = "LEFT", posX = 79.86, selfAnchorY = "BOTTOM", offsetY = 8, anchorX = "RIGHT", anchorY = "BOTTOM" },
                        Name = { posY = 0, offsetX = 5, justifyH = "LEFT", posX = -74.86, selfAnchorY = "CENTER", offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        Portrait = { offsetX = 4, offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        MarkerIcon = { posY = 18.05, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "TOP", offsetY = 0, anchorX = "CENTER", anchorY = "TOP" },
                        HealthText = { posY = 0, offsetX = 5, justifyH = "RIGHT", posX = 74.86, selfAnchorY = "CENTER", offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                        LevelText = { posY = 12.05, offsetX = 5, justifyH = "LEFT", posX = 74.86, selfAnchorY = "TOP", offsetY = 6, anchorX = "RIGHT", anchorY = "TOP" },
                    },
                    EnableTargetTarget = true,
                },
            },
            ["Orbit_BossFrames"] = {
                [1] = {
                    CastBarWidth = 116, CastBarPosition = "Below", MaxDebuffs = 4, Spacing = 24, Anchor = false,
                    ComponentPositions = {
                        CastBar = { posY = -29.26, selfAnchorY = "BOTTOM", anchorX = "CENTER", offsetX = 0, justifyH = "CENTER", posX = 0, overrides = { CastBarWidth = 116, CastBarHeight = 18, CastBarIcon = false }, offsetY = -9.85, subComponents = { Timer = { offsetX = 4, justifyH = "RIGHT", offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" }, Text = { offsetX = 4, justifyH = "LEFT", offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" } }, anchorY = "BOTTOM" },
                        Debuffs = { posY = 0, selfAnchorY = "CENTER", anchorX = "LEFT", justifyH = "RIGHT", posX = -58.89, overrides = { MaxIcons = 4, MaxRows = 1, FilterDensity = 2, IconSize = 40, PandemicGlowColorCurve = { pins = { { color = { a = 1, r = 1, g = 0.188, b = 0 }, position = 0.589 } } }, PandemicGlowType = 1 }, offsetY = 0, offsetX = -2, anchorY = "CENTER" },
                        Name = { posY = 0, offsetX = 5, justifyH = "LEFT", posX = -52.98, selfAnchorY = "CENTER", offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        HealthText = { posY = 0, offsetX = 5, justifyH = "RIGHT", posX = 52.98, selfAnchorY = "CENTER", offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                        Buffs = { posY = 0, selfAnchorY = "CENTER", anchorX = "RIGHT", justifyH = "LEFT", posX = 58.89, overrides = { MaxIcons = 3, MaxRows = 1, FilterDensity = 2, IconSize = 40 }, offsetY = 0, offsetX = -2, anchorY = "CENTER" },
                        MarkerIcon = { posY = 19.42, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "TOP", offsetY = 0, anchorX = "CENTER", anchorY = "TOP" },
                    },
                    CastBarHeight = 18, PandemicGlowColorCurve = { pins = { { color = { a = 1, r = 1, g = 0.188, b = 0 }, position = 0.589 } }, _sorted = { { color = { a = 1, r = 1, g = 0.188, b = 0 }, position = 0.589 } } },
                    DisabledComponents = { "Status" }, Width = 116, DebuffPosition = "Left", CastBarIcon = false, Height = 39,
                    Position = { y = 62.74, x = -493.4, point = "RIGHT" }, ReactionColour = false, Scale = 100, DebuffSize = 32, PandemicGlowType = 1,
                },
            },
            ["Orbit_TargetOfTargetFrame"] = {
                [100] = {
                    DisabledComponents = { "HealthText" }, Height = 20,
                    Anchor = { target = "OrbitTargetBuffsFrame", padding = 10, edge = "BOTTOM", align = "RIGHT" },
                    ComponentPositions = { Name = { offsetX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" } },
                    Width = 100,
                },
            },
            ["Orbit_FocusBuffs"] = {
                [1] = { Anchor = { target = "OrbitFocusPower", padding = 3, edge = "BOTTOM", align = "LEFT" }, MaxRows = 2, Scale = 100, IconsPerRow = 8 },
            },
            ["Orbit_FocusCastBar"] = {
                [1] = { Anchor = { target = "OrbitFocusFrame", padding = 0, edge = "TOP", align = "LEFT" }, CastBarHeight = 18, CastBarWidth = 200, CastBarTextSize = 10 },
            },
            ["Orbit_PlayerBuffs"] = {
                [1] = {
                    ComponentPositions = {
                        Timer = { posY = 0, selfAnchorY = "CENTER", anchorX = "CENTER", justifyH = "CENTER", posX = 0, overrides = { FontSize = 14 }, offsetY = 0, offsetX = 0, anchorY = "CENTER" },
                        Stacks = { posY = -10, offsetX = 0, justifyH = "RIGHT", posX = 10, selfAnchorY = "BOTTOM", offsetY = 5, anchorX = "RIGHT", anchorY = "BOTTOM" },
                    },
                    DisabledComponents = { "Status" }, IconLimit = 30, Anchor = { target = "OrbitActionBar5", padding = 50, edge = "RIGHT", align = "TOP" },
                    Rows = 1, Collapsed = false, Spacing = 0,
                },
            },
            ["Orbit_PlayerPetFrame"] = {
                [8] = {
                    DisabledComponents = { "HealthText" }, Height = 22, Anchor = { target = "OrbitPlayerFrame", padding = 4, edge = "BOTTOM", align = "LEFT" },
                    ComponentPositions = { Name = { offsetX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" } }, Width = 91,
                },
            },
            ["Orbit_PartyFrames"] = {
                [1] = {
                    DisabledComponentsMigrated = true, Spacing = 3, DisabledComponents = { "DefensiveIcon", "CrowdControlIcon", "Status", "HealerAura1", "HealerAura2", "HealerAura3", "HealerAura4", "HealerAura5", "HealerAura6", "HealerAura7", "RaidBuff" },
                    Position = { y = -466, x = 446, point = "TOPLEFT" }, ShowPowerBar = false, IncludePlayer = true,
                    ComponentPositions = {
                        RoleIcon = { posY = 0, selfAnchorY = "CENTER", anchorX = "LEFT", justifyH = "LEFT", posX = -74.86, overrides = { HideDPS = false }, offsetY = 0, offsetX = 5, anchorY = "CENTER" },
                        Debuffs = { posY = 0, selfAnchorY = "CENTER", anchorX = "RIGHT", justifyH = "LEFT", posX = 79.77, overrides = { MaxIcons = 6, MaxRows = 2, FilterDensity = 2, IconSize = 30 }, offsetY = 0, offsetX = -1, anchorY = "CENTER" },
                        LeaderIcon = { posY = 19.97, offsetX = 10, justifyH = "LEFT", posX = -69.86, selfAnchorY = "TOP", offsetY = 0, anchorX = "LEFT", anchorY = "TOP" },
                        DefensiveIcon = { offsetX = 2, offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        HealthText = { posY = 0, offsetX = 5, justifyH = "RIGHT", posX = 74.86, selfAnchorY = "CENTER", offsetY = 0, anchorX = "RIGHT", anchorY = "CENTER" },
                        CrowdControlIcon = { offsetX = 0, offsetY = 2, anchorX = "CENTER", anchorY = "TOP" },
                        SummonIcon = { offsetX = 0, posY = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        StatusIcons = { posY = 0, selfAnchorY = "CENTER", anchorX = "CENTER", justifyH = "CENTER", posX = 0, overrides = { IconSize = 20 }, offsetY = 0, offsetX = 0, anchorY = "CENTER" },
                        PrivateAuraAnchor = { posY = 0, selfAnchorY = "CENTER", anchorX = "CENTER", justifyH = "CENTER", posX = 0, overrides = { Scale = 1.2, IconSize = 24 }, offsetY = 0, offsetX = 0, anchorY = "CENTER" },
                        Name = { posY = 0, offsetX = 15, justifyH = "LEFT", posX = -64.86, selfAnchorY = "CENTER", offsetY = 0, anchorX = "LEFT", anchorY = "CENTER" },
                        ResIcon = { offsetX = 0, posY = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        PhaseIcon = { offsetX = 0, posY = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        Buffs = { posY = 0, selfAnchorY = "CENTER", anchorX = "LEFT", justifyH = "RIGHT", posX = -79.77, overrides = { MaxIcons = 6, MaxRows = 2, FilterDensity = 1, IconSize = 30 }, offsetY = 0, offsetX = -1, anchorY = "CENTER" },
                        ReadyCheckIcon = { offsetX = 0, posY = 0, posX = 0, justifyH = "CENTER", offsetY = 0, anchorX = "CENTER", anchorY = "CENTER" },
                        MarkerIcon = { posY = 17.97, offsetX = 0, justifyH = "CENTER", posX = 0, selfAnchorY = "TOP", offsetY = 2, anchorX = "CENTER", anchorY = "TOP" },
                    },
                    Anchor = false,
                },
            },
            ["Orbit_Performance"] = {
                ["Orbit_Performance"] = { Anchor = { target = "OrbitActionBar4", padding = 15, edge = "RIGHT", align = "CENTER" }, Opacity = 100 },
            },
        },
    },
    DisabledPlugins = {},
    HideBlizzardFrames = {},
    GlobalSettings = {
        OverlayTexture = "None", TourComplete = true,
        BackdropColour = { a = 0.7, r = 0.145, g = 0.145, b = 0.145 },
        BarColorCurve = {
            pins = { { color = { a = 1, b = 1, g = 1, r = 1 }, type = "class", position = 0 } },
            _sorted = { { color = { a = 1, b = 1, g = 1, r = 1 }, type = "class", position = 0 } },
        },
        BarColor = { a = 1, b = 0.2, g = 0.8, r = 0.2 },
        Font = "Barlow Condensed Bold", HideWhenMounted = false, BorderSize = 2,
        ClassColorBackground = false, IconBorderSize = 4, OverlayAllFrames = false,
        FontOutline = "OUTLINE", UseClassColors = true, Texture = "Solid",
    },
}
