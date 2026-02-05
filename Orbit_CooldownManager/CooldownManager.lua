---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

local LibCustomGlow = LibStub("LibCustomGlow-1.0", true)

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local ESSENTIAL_INDEX = Constants.Cooldown.SystemIndex.Essential
local UTILITY_INDEX = Constants.Cooldown.SystemIndex.Utility
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon
local TRACKED_INDEX = Constants.Cooldown.SystemIndex.Tracked
local VIEWER_MAP = {}

local Plugin = Orbit:RegisterPlugin("Cooldown Manager", "Orbit_CooldownViewer", {
    defaults = {
        aspectRatio = "1:1",
        IconSize = Constants.Cooldown.DefaultIconSize,
        IconPadding = Constants.Cooldown.DefaultPadding,
        SwipeColor = { r = 0, g = 0, b = 0, a = 0.8 },
        Opacity = 100,
        Orientation = 0,
        IconLimit = Constants.Cooldown.DefaultLimit,
        ShowGCDSwipe = true,
        DisabledComponents = { "Keybind" },
        ComponentPositions = {
            Timer = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0, justifyH = "CENTER" },
            Stacks = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2, justifyH = "LEFT" },
            Charges = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2, justifyH = "RIGHT" },
            Keybind = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2, justifyH = "RIGHT" },
        },
        PandemicGlowType = Constants.PandemicGlow.DefaultType,
        PandemicGlowColor = Constants.PandemicGlow.DefaultColor,
        ProcGlowType = Constants.PandemicGlow.DefaultType,
        ProcGlowColor = Constants.PandemicGlow.DefaultColor,
        OutOfCombatFade = false,
        ShowOnMouseover = true,
        TrackedItems = {},
    },
}, Orbit.Constants.PluginGroups.CooldownManager)

Plugin.canvasMode = true
Plugin.viewerMap = VIEWER_MAP


-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic

    local frame = self:GetFrameBySystemIndex(systemIndex)
    local isAnchored = frame and OrbitEngine.Frame:GetAnchorParent(frame) ~= nil
    local isTracked = frame and frame.isTrackedBar

    local schema = {
        hideNativeSettings = true,
        controls = {},
        extraButtons = {},
    }

    if not isTracked then
        table.insert(schema.extraButtons, {
            text = "Cooldown Settings",
            callback = function()
                if EditModeManagerFrame and EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
                if CooldownViewerSettings then CooldownViewerSettings:Show() end
            end,
        })
    end

    if not isAnchored then end

    table.insert(schema.controls, {
        type = "dropdown",
        key = "aspectRatio",
        label = "Icon Aspect Ratio",
        options = {
            { text = "Square (1:1)", value = "1:1" },
            { text = "Landscape (16:9)", value = "16:9" },
            { text = "Landscape (4:3)", value = "4:3" },
            { text = "Ultrawide (21:9)", value = "21:9" },
        },
        default = "1:1",
    })

    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "IconSize",
        label = "Scale",
        default = Constants.Cooldown.DefaultIconSize,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "IconPadding",
        label = "Icon Padding",
        min = -1,
        max = 10,
        step = 1,
        default = Constants.Cooldown.DefaultPadding,
    })

    if not isTracked then
        table.insert(schema.controls, {
            type = "slider",
            key = "IconLimit",
            label = "# Columns",
            min = 1,
            max = 20,
            step = 1,
            default = Constants.Cooldown.DefaultLimit,
        })
    end

    WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
        key = "SwipeColor",
        label = "Swipe Colour",
        default = { r = 0, g = 0, b = 0, a = 0.8 },
    }, nil)

    table.insert(schema.controls, {
        type = "checkbox",
        key = "ShowGCDSwipe",
        label = "Show GCD Swipe",
        default = true,
    })

    if not isTracked then
        local GlowType = Constants.PandemicGlow.Type
        table.insert(schema.controls, {
            type = "dropdown",
            key = "PandemicGlowType",
            label = "Pandemic Glow",
            options = {
                { text = "None", value = GlowType.None },
                { text = "Pixel Glow", value = GlowType.Pixel },
                { text = "Proc Glow", value = GlowType.Proc },
                { text = "Autocast Shine", value = GlowType.Autocast },
                { text = "Button Glow", value = GlowType.Button },
            },
            default = Constants.PandemicGlow.DefaultType,
        })

        WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
            key = "PandemicGlowColor",
            label = "Pandemic Glow Colour",
            default = Constants.PandemicGlow.DefaultColor,
        }, nil)

        table.insert(schema.controls, {
            type = "dropdown",
            key = "ProcGlowType",
            label = "Proc Glow",
            options = {
                { text = "None", value = GlowType.None },
                { text = "Pixel Glow", value = GlowType.Pixel },
                { text = "Proc Glow", value = GlowType.Proc },
                { text = "Autocast Shine", value = GlowType.Autocast },
                { text = "Button Glow", value = GlowType.Button },
            },
            default = Constants.PandemicGlow.DefaultType,
        })

        WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
            key = "ProcGlowColor",
            label = "Proc Glow Colour",
            default = Constants.PandemicGlow.DefaultColor,
        }, nil)
    end

    -- Opacity (resting alpha when visible)
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })

    table.insert(schema.controls, {
        type = "checkbox",
        key = "OutOfCombatFade",
        label = "Out of Combat Fade",
        default = false,
        tooltip = "Hide frame when out of combat with no target",
        onChange = function(val)
            self:SetSetting(systemIndex, "OutOfCombatFade", val)
            if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
            OrbitEngine.Layout:Reset(dialog)
            self:AddSettings(dialog, systemFrame)
        end,
    })

    if self:GetSetting(systemIndex, "OutOfCombatFade") then
        table.insert(schema.controls, {
            type = "checkbox",
            key = "ShowOnMouseover",
            label = "Show on Mouseover",
            default = true,
            tooltip = "Reveal frame when mousing over it",
            onChange = function(val)
                self:SetSetting(systemIndex, "ShowOnMouseover", val)
                local data = VIEWER_MAP[systemIndex]
                if data then
                    local target = data.isTracked and data.anchor or data.viewer
                    if target and Orbit.OOCFadeMixin then
                        Orbit.OOCFadeMixin:ApplyOOCFade(target, self, systemIndex, "OutOfCombatFade", val)
                        Orbit.OOCFadeMixin:RefreshAll()
                    end
                end
            end,
        })
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self.essentialAnchor = self:CreateAnchor("OrbitEssentialCooldowns", ESSENTIAL_INDEX, "Essential Cooldowns")
    self.utilityAnchor = self:CreateAnchor("OrbitUtilityCooldowns", UTILITY_INDEX, "Utility Cooldowns")
    self.buffIconAnchor = self:CreateAnchor("OrbitBuffIconCooldowns", BUFFICON_INDEX, "Buff Icons")
    self.trackedAnchor = self:CreateTrackedAnchor("OrbitTrackedCooldowns", TRACKED_INDEX, "Tracked Cooldowns")

    VIEWER_MAP = {
        [ESSENTIAL_INDEX] = { viewer = EssentialCooldownViewer, anchor = self.essentialAnchor },
        [UTILITY_INDEX] = { viewer = UtilityCooldownViewer, anchor = self.utilityAnchor },
        [BUFFICON_INDEX] = { viewer = BuffIconCooldownViewer, anchor = self.buffIconAnchor },
        [TRACKED_INDEX] = { viewer = nil, anchor = self.trackedAnchor, isTracked = true },
    }
    self.viewerMap = VIEWER_MAP

    self:SetupCanvasPreview(self.essentialAnchor, ESSENTIAL_INDEX)
    self:SetupCanvasPreview(self.utilityAnchor, UTILITY_INDEX)
    self:SetupCanvasPreview(self.buffIconAnchor, BUFFICON_INDEX)
    self:SetupTrackedCanvasPreview(self.trackedAnchor, TRACKED_INDEX)

    self:RestoreChildFrames()
    self:HookBlizzardViewers()
    self:StartTrackedUpdateTicker()
    self:RegisterCursorWatcher()
    self:SetupTrackedKeyboardHook()

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", self.OnPlayerEnteringWorld, self)
    self:RegisterVisibilityEvents()

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        if Orbit.OOCFadeMixin then
            for systemIndex, data in pairs(VIEWER_MAP) do
                if data.viewer then
                    local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
                    Orbit.OOCFadeMixin:ApplyOOCFade(data.viewer, self, systemIndex, "OutOfCombatFade", enableHover)
                end
                if data.isTracked and data.anchor then
                    local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
                    Orbit.OOCFadeMixin:ApplyOOCFade(data.anchor, self, systemIndex, "OutOfCombatFade", enableHover)
                end
            end
            Orbit.OOCFadeMixin:RefreshAll()
        end
    end, self)
end

function Plugin:CreateAnchor(name, systemIndex, label)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(40, 40)
    frame:SetClampedToScreen(true)
    frame.systemIndex = systemIndex
    frame.editModeName = label
    frame:EnableMouse(true)
    frame.anchorOptions = { horizontal = true, vertical = true, syncScale = false, syncDimensions = false }
    OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)

    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()
    if not frame:GetPoint() then
        if systemIndex == ESSENTIAL_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
        elseif systemIndex == UTILITY_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
        elseif systemIndex == BUFFICON_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        end
    end

    frame.OnAnchorChanged = function(self, parent, edge, padding)
        Plugin:ProcessChildren(self)
    end
    self:ApplySettings(frame)
    return frame
end


function Plugin:IsComponentDisabled(componentKey, systemIndex)
    systemIndex = systemIndex or 1
    local disabled = self:GetSetting(systemIndex, "DisabledComponents") or {}
    for _, key in ipairs(disabled) do
        if key == componentKey then return true end
    end
    return false
end

-- [ CANVAS MODE PREVIEW ]-----------------------------------------------------------------------
function Plugin:SetupCanvasPreview(anchor, systemIndex)
    local plugin = self
    local LSM = LibStub("LibSharedMedia-3.0")

    anchor.CreateCanvasPreview = function(self, options)
        local entry = VIEWER_MAP[systemIndex]
        if not entry or not entry.viewer then
            return nil
        end

        -- Get icon dimensions from actual icons in the viewer
        local w, h = nil, nil
        local children = { entry.viewer:GetChildren() }
        for _, child in ipairs(children) do
            if child:IsShown() and child.Icon then
                w, h = child:GetSize()
                break
            end
        end

        -- Fallback to settings-based calculation if no visible icons
        if not w or not h then
            local aspectRatio = plugin:GetSetting(systemIndex, "aspectRatio") or "1:1"
            local iconSize = plugin:GetSetting(systemIndex, "IconSize") or Constants.Cooldown.DefaultIconSize
            local baseSize = Constants.Skin.DefaultIconSize or 40
            local scaledSize = baseSize * (iconSize / 100)
            w, h = scaledSize, scaledSize
            if aspectRatio == "16:9" then
                h = scaledSize * (9 / 16)
            elseif aspectRatio == "4:3" then
                h = scaledSize * (3 / 4)
            elseif aspectRatio == "21:9" then
                h = scaledSize * (9 / 21)
            end
        end

        -- Create preview matching single icon size
        local parent = options.parent or UIParent
        local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        preview:SetSize(w, h)

        -- Required metadata for Canvas Mode
        preview.sourceFrame = self
        -- Use content dimensions (excluding border) for positioning
        local borderSize = Orbit.db.GlobalSettings.BorderSize
        local contentW = w - (borderSize * 2) -- Inset by border on each side
        local contentH = h - (borderSize * 2)
        preview.sourceWidth = contentW
        preview.sourceHeight = contentH
        preview.previewScale = 1
        preview.components = {}

        -- Get first visible icon texture from the viewer
        local iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        local children = { entry.viewer:GetChildren() }
        for _, child in ipairs(children) do
            if child:IsShown() and child.Icon then
                local tex = child.Icon:GetTexture()
                if tex then
                    iconTexture = tex
                    break
                end
            end
        end

        -- Create icon display
        local icon = preview:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(iconTexture)

        -- Apply border matching Orbit style
        -- Only include edgeFile when borderSize > 0 to avoid rendering glitches
        local backdrop = {
            bgFile = "Interface\\BUTTONS\\WHITE8x8",
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        }
        if borderSize > 0 then
            backdrop.edgeFile = "Interface\\BUTTONS\\WHITE8x8"
            backdrop.edgeSize = borderSize
        end
        preview:SetBackdrop(backdrop)
        preview:SetBackdropColor(0, 0, 0, 0)
        if borderSize > 0 then
            preview:SetBackdropBorderColor(0, 0, 0, 1)
        end

        -- [ TEXT COMPONENTS ]------------------------------------------------------------
        -- Add draggable text labels for Timer, Charges, Stacks, Keybind

        local savedPositions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}

        -- Get global font settings
        local globalFontName = Orbit.db.GlobalSettings.Font
        local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"

        -- Text component definitions with defaults
        local textComponents = {
            { key = "Timer", preview = string.format("%.1f", 3 + math.random() * 7), anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
            { key = "Charges", preview = "2", anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
            { key = "Stacks", preview = "3", anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
            { key = "Keybind", preview = "Q", anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2 },
        }

        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent

        for _, def in ipairs(textComponents) do
            -- Create temporary FontString as source for cloning
            local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7) -- Highest sublevel
            fs:SetFont(fontPath, 12, "OUTLINE")
            fs:SetText(def.preview)
            fs:SetTextColor(1, 1, 1, 1)
            fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

            -- Get saved position or use defaults
            local saved = savedPositions[def.key] or {}
            local defaultJustifyH = def.anchorX == "LEFT" and "LEFT" or def.anchorX == "RIGHT" and "RIGHT" or "CENTER"
            local data = {
                anchorX = saved.anchorX or def.anchorX,
                anchorY = saved.anchorY or def.anchorY,
                offsetX = saved.offsetX or def.offsetX,
                offsetY = saved.offsetY or def.offsetY,
                justifyH = saved.justifyH or defaultJustifyH,
                overrides = saved.overrides,
            }

            -- Calculate start position (center-relative)
            local halfW, halfH = contentW / 2, contentH / 2
            local startX, startY = saved.posX or 0, saved.posY or 0

            -- If no posX/posY saved, convert from anchor/offset
            if not saved.posX then
                if data.anchorX == "LEFT" then
                    startX = -halfW + data.offsetX
                elseif data.anchorX == "RIGHT" then
                    startX = halfW - data.offsetX
                end
            end
            if not saved.posY then
                if data.anchorY == "BOTTOM" then
                    startY = -halfH + data.offsetY
                elseif data.anchorY == "TOP" then
                    startY = halfH - data.offsetY
                end
            end

            -- Create draggable component if available
            if CreateDraggableComponent then
                local comp = CreateDraggableComponent(preview, def.key, fs, startX, startY, data)
                if comp then
                    -- Ensure text is above the border
                    comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                    preview.components[def.key] = comp
                    fs:Hide() -- Hide original, comp has its own visual
                end
            else
                -- Fallback: just position the FontString directly
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
            end
        end

        return preview
    end
end


function Plugin:HookBlizzardViewers()
    for _, entry in pairs(VIEWER_MAP) do
        self:SetupViewerHooks(entry.viewer, entry.anchor)
    end

    -- Re-apply parentage when Edit Mode exits
    if EventRegistry and not self.editModeExitRegistered then
        self.editModeExitRegistered = true
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            self:ReapplyParentage()
        end, self)
    end

    -- Hook spell activation (proc) glows
    self:HookProcGlow()

    self:MonitorViewers()
end

function Plugin:HookProcGlow()
    if not LibCustomGlow or self.procGlowHooked or not ActionButtonSpellAlertManager then
        return
    end

    local plugin = self

    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
        local viewer = button.viewerFrame
        if not viewer then
            return
        end

        local systemIndex = viewer == EssentialCooldownViewer and ESSENTIAL_INDEX
            or viewer == UtilityCooldownViewer and UTILITY_INDEX
            or viewer == BuffIconCooldownViewer and BUFFICON_INDEX
            or nil
        if not systemIndex then
            return
        end

        local GlowType = Constants.PandemicGlow.Type
        local glowType = plugin:GetSetting(systemIndex, "ProcGlowType") or GlowType.None
        if glowType == GlowType.None then
            return
        end

        local GlowConfig = Constants.PandemicGlow
        local procColor = plugin:GetSetting(systemIndex, "ProcGlowColor") or GlowConfig.DefaultColor
        local colorTable = { procColor.r, procColor.g, procColor.b, procColor.a }
        if button.SpellActivationAlert then
            button.SpellActivationAlert:SetAlpha(0)
        end

        -- Start our custom glow
        if not button.orbitProcGlowActive then
            if glowType == GlowType.Pixel then
                local cfg = GlowConfig.Pixel
                LibCustomGlow.PixelGlow_Start(
                    button,
                    colorTable,
                    cfg.Lines,
                    cfg.Frequency,
                    cfg.Length,
                    cfg.Thickness,
                    cfg.XOffset,
                    cfg.YOffset,
                    cfg.Border,
                    "orbitProc"
                )
            elseif glowType == GlowType.Proc then
                local cfg = GlowConfig.Proc
                LibCustomGlow.ProcGlow_Start(button, {
                    color = colorTable,
                    startAnim = cfg.StartAnim,
                    duration = cfg.Duration,
                    key = "orbitProc",
                })
                local glowFrame = button["_ProcGloworbitProc"]
                if glowFrame then
                    glowFrame.startAnim = false
                    plugin:FixGlowTransparency(glowFrame, procColor.a)
                end
            elseif glowType == GlowType.Autocast then
                local cfg = GlowConfig.Autocast
                LibCustomGlow.AutoCastGlow_Start(button, colorTable, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, "orbitProc")
            elseif glowType == GlowType.Button then
                local cfg = GlowConfig.Button
                LibCustomGlow.ButtonGlow_Start(button, colorTable, cfg.Frequency, cfg.FrameLevel)
            end

            button.orbitProcGlowActive = glowType
        end
    end)

    hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, button)
        if button.orbitProcGlowActive then
            local GlowType = Constants.PandemicGlow.Type
            local activeType = button.orbitProcGlowActive

            if activeType == GlowType.Pixel then
                LibCustomGlow.PixelGlow_Stop(button, "orbitProc")
            elseif activeType == GlowType.Proc then
                LibCustomGlow.ProcGlow_Stop(button, "orbitProc")
            elseif activeType == GlowType.Autocast then
                LibCustomGlow.AutoCastGlow_Stop(button, "orbitProc")
            elseif activeType == GlowType.Button then
                LibCustomGlow.ButtonGlow_Stop(button)
            end

            button.orbitProcGlowActive = nil
        end
    end)

    self.procGlowHooked = true
end

function Plugin:FixGlowTransparency(glowFrame, alpha)
    if not glowFrame or not alpha then
        return
    end

    -- Patch Loop Animation (alphaRepeat)
    if glowFrame.ProcLoopAnim and glowFrame.ProcLoopAnim.alphaRepeat then
        glowFrame.ProcLoopAnim.alphaRepeat:SetFromAlpha(alpha)
        glowFrame.ProcLoopAnim.alphaRepeat:SetToAlpha(alpha)
    end

    -- Patch Start Animation (iterate to find Alpha animations)
    if glowFrame.ProcStartAnim then
        for _, anim in pairs({ glowFrame.ProcStartAnim:GetAnimations() }) do
            if anim:GetObjectType() == "Alpha" then
                local order = anim:GetOrder()
                if order == 0 then
                    anim:SetFromAlpha(alpha)
                    anim:SetToAlpha(alpha)
                elseif order == 2 then
                    anim:SetFromAlpha(alpha)
                end
            end
        end
    end
end
-- [ TICKER-BASED PANDEMIC GLOW ]--------------------------------------------------------------------
function Plugin:CheckPandemicFrames(viewer, systemIndex)
    if not viewer or not LibCustomGlow then
        return
    end

    local GlowType = Constants.PandemicGlow.Type
    local glowType = self:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
    if glowType == GlowType.None then
        return
    end
    local GlowConfig = Constants.PandemicGlow

    local pandemicColor = self:GetSetting(systemIndex, "PandemicGlowColor") or GlowConfig.DefaultColor
    local colorTable = { pandemicColor.r, pandemicColor.g, pandemicColor.b, pandemicColor.a }

    local icons = viewer.GetItemFrames and viewer:GetItemFrames() or {}

    for _, icon in ipairs(icons) do
        local inPandemic = icon.PandemicIcon and icon.PandemicIcon:IsShown()

        if inPandemic then
            if not icon.orbitPandemicGlowActive then
                icon.PandemicIcon:SetAlpha(0)

                if glowType == GlowType.Pixel then
                    local cfg = GlowConfig.Pixel
                    LibCustomGlow.PixelGlow_Start(
                        icon,
                        colorTable,
                        cfg.Lines,
                        cfg.Frequency,
                        cfg.Length,
                        cfg.Thickness,
                        cfg.XOffset,
                        cfg.YOffset,
                        cfg.Border,
                        "orbitPandemic"
                    )
                elseif glowType == GlowType.Proc then
                    local cfg = GlowConfig.Proc
                    LibCustomGlow.ProcGlow_Start(icon, {
                        color = colorTable,
                        startAnim = cfg.StartAnim,
                        duration = cfg.Duration,
                        key = "orbitPandemic",
                    })

                    local glowFrame = icon["_ProcGloworbitPandemic"]
                    if glowFrame then
                        glowFrame.startAnim = false
                        self:FixGlowTransparency(glowFrame, pandemicColor.a)
                    end
                elseif glowType == GlowType.Autocast then
                    local cfg = GlowConfig.Autocast
                    LibCustomGlow.AutoCastGlow_Start(icon, colorTable, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, "orbitPandemic")
                elseif glowType == GlowType.Button then
                    local cfg = GlowConfig.Button
                    LibCustomGlow.ButtonGlow_Start(icon, colorTable, cfg.Frequency, cfg.FrameLevel)
                end

                icon.orbitPandemicGlowActive = glowType
            end
        else
            if icon.orbitPandemicGlowActive then
                local activeType = icon.orbitPandemicGlowActive

                if activeType == GlowType.Pixel then
                    LibCustomGlow.PixelGlow_Stop(icon, "orbitPandemic")
                elseif activeType == GlowType.Proc then
                    LibCustomGlow.ProcGlow_Stop(icon, "orbitPandemic")
                elseif activeType == GlowType.Autocast then
                    LibCustomGlow.AutoCastGlow_Stop(icon, "orbitPandemic")
                elseif activeType == GlowType.Button then
                    LibCustomGlow.ButtonGlow_Stop(icon)
                end

                icon.orbitPandemicGlowActive = nil
            end
        end
    end
end

function Plugin:MonitorViewers()
    if self.monitorTicker then
        self.monitorTicker:Cancel()
    end

    local plugin = self

    self.monitorTicker = C_Timer.NewTicker(Constants.Timing.LayoutMonitorInterval, function()
        for systemIndex, entry in pairs(VIEWER_MAP) do
            plugin:CheckViewer(entry.viewer, entry.anchor)

            -- Check pandemic state via reliable polling
            if LibCustomGlow then
                plugin:CheckPandemicFrames(entry.viewer, systemIndex)
            end
        end
    end)
end

function Plugin:CheckViewer(viewer, anchor)
    if not viewer or not anchor then
        return
    end

    if viewer:GetParent() ~= anchor then
        self:EnforceViewerParentage(viewer, anchor)
        return
    end
    if not viewer:IsShown() then
        viewer:Show()
        viewer:SetAlpha(1)
    end

    local children = { viewer:GetChildren() }
    local count = 0
    for _, child in ipairs(children) do
        if child:IsShown() then
            count = count + 1
        end
    end

    -- If count changed, force update
    if count ~= (viewer.orbitLastCount or 0) then
        viewer.orbitLastCount = count
        self:ProcessChildren(anchor)
    end
end

function Plugin:SetupViewerHooks(viewer, anchor)
    if not viewer or not anchor then
        return
    end

    -- Disable Native Method Interactions
    if viewer.Selection then
        viewer.Selection:Hide()
        viewer.Selection:SetScript("OnShow", function(self)
            self:Hide()
        end)
    end

    local function LayoutHandler()
        if viewer._orbitResizing then
            return
        end
        self:ProcessChildren(anchor)
    end

    if viewer.UpdateLayout then
        hooksecurefunc(viewer, "UpdateLayout", LayoutHandler)
    end
    if viewer.RefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", LayoutHandler)
    end

    local function RestoreViewer(v, parent)
        if not v or not parent or not anchor:IsShown() then
            return
        end

        v:ClearAllPoints()

        local direction = self:GetGrowthDirection(anchor)
        local point = (direction == "UP") and "BOTTOM" or "TOP"
        v:SetPoint(point, parent, point, 0, 0)

        v:SetAlpha(1)
        v:Show()
    end

    OrbitEngine.Frame:Protect(viewer, anchor, RestoreViewer, { enforceShow = true })

    if not viewer.orbitAlphaHooked then
        hooksecurefunc(viewer, "SetAlpha", function(s, alpha)
            if s._orbitSettingAlpha or (anchor and not anchor:IsShown()) then
                return
            end
            if alpha < 0.1 then
                s._orbitSettingAlpha = true
                s:SetAlpha(1)
                s._orbitSettingAlpha = false
            end
        end)
        viewer.orbitAlphaHooked = true
    end
    if not viewer.orbitPosHooked then
        local function ReAnchor()
            if viewer._orbitRestoringPos or (anchor and not anchor:IsShown()) then
                return
            end
            viewer._orbitRestoringPos = true
            viewer:ClearAllPoints()
            local point = (self:GetGrowthDirection(anchor) == "UP") and "BOTTOM" or "TOP"
            viewer:SetPoint(point, anchor, point, 0, 0)
            viewer._orbitRestoringPos = false
        end

        hooksecurefunc(viewer, "SetPoint", function()
            ReAnchor()
        end)
        hooksecurefunc(viewer, "ClearAllPoints", function()
            ReAnchor()
        end)
        viewer.orbitPosHooked = true
    end

    if not viewer.orbitHideHooked then
        hooksecurefunc(viewer, "Hide", function(s)
            if s._orbitRestoringVis or (anchor and not anchor:IsShown()) then
                return
            end
            s._orbitRestoringVis = true
            s:Show()
            s:SetAlpha(1)
            s._orbitRestoringVis = false
        end)
        viewer.orbitHideHooked = true
    end

    -- Apply initial parentage
    self:EnforceViewerParentage(viewer, anchor)
end

function Plugin:ReapplyParentage()
    for _, entry in pairs(VIEWER_MAP) do
        self:EnforceViewerParentage(entry.viewer, entry.anchor)
    end
end

function Plugin:EnforceViewerParentage(viewer, anchor)
    if not viewer or not anchor then
        return
    end

    if viewer:GetParent() ~= anchor then
        viewer:SetParent(anchor)
    end
    viewer:SetScale(1)

    viewer:ClearAllPoints()

    local direction = self:GetGrowthDirection(anchor)
    local point = (direction == "UP") and "BOTTOM" or "TOP"
    viewer:SetPoint(point, anchor, point, 0, 0)

    viewer:SetAlpha(1)
    viewer:Show()

    -- Force layout update when re-asserting parentage
    self:ProcessChildren(anchor)
end

function Plugin:OnPlayerEnteringWorld()
    -- Retry parentage after a short delay to ensure clean state after load screens
    C_Timer.After(Constants.Timing.RetryShort, function()
        self:ReapplyParentage()
        self:ApplyAll()
    end)

    -- And again slightly later for slower machines/heavy loads
    C_Timer.After(Constants.Timing.RetryLong, function()
        self:ReapplyParentage()
    end)
end

function Plugin:ProcessChildren(anchor)
    if not anchor then
        return
    end

    local entry = VIEWER_MAP[anchor.systemIndex]
    local blizzFrame = entry and entry.viewer
    if not blizzFrame then
        return
    end

    local systemIndex = anchor.systemIndex

    -- Collect visible children
    local activeChildren = {}
    local children = { blizzFrame:GetChildren() }
    local plugin = self

    for _, child in ipairs(children) do
        if child.layoutIndex then
            -- Hook OnShow for immediate skinning/layout
            if not child.orbitOnShowHooked then
                child:HookScript("OnShow", function(c)
                    local parent = c:GetParent()
                    local anchor = parent and parent:GetParent()

                    -- 1. Apply Skin Immediately
                    if Orbit.Skin.Icons and Orbit.Skin.Icons.frameSettings then
                        local s = Orbit.Skin.Icons.frameSettings[parent]
                        if s then
                            Orbit.Skin.Icons:ApplyCustom(c, s)
                        end
                    end

                    -- Force Layout Update
                    if anchor and plugin.ProcessChildren then
                        plugin:ProcessChildren(anchor)
                    end
                end)
                child.orbitOnShowHooked = true
            end

            if child:IsShown() then
                table.insert(activeChildren, child)
            end
        end
    end

    -- Sort by Layout Index
    table.sort(activeChildren, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    -- Apply Skin and Layout via Orbit.Skin.Icons
    if Orbit.Skin.Icons and #activeChildren > 0 then
        local skinSettings = CooldownUtils:BuildSkinSettings(self, systemIndex, {
            verticalGrowth = self:GetGrowthDirection(anchor),
        })

        -- Store settings for the Skin system to use
        if not Orbit.Skin.Icons.frameSettings then
            Orbit.Skin.Icons.frameSettings = setmetatable({}, { __mode = "k" })
        end
        Orbit.Skin.Icons.frameSettings[blizzFrame] = skinSettings

        for _, icon in ipairs(activeChildren) do
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)

            -- [ GCD SWIPE REMOVAL ]
            if not icon.orbitGCDHooked and icon.RefreshSpellCooldownInfo then
                -- Store reference for dynamic lookup
                icon.orbitSystemIndex = systemIndex
                icon.orbitPlugin = self

                hooksecurefunc(icon, "RefreshSpellCooldownInfo", function(self)
                    -- Dynamically check current setting
                    local plugin = self.orbitPlugin
                    local sysIdx = self.orbitSystemIndex
                    if not plugin or not sysIdx then
                        return
                    end

                    local showGCD = plugin:GetSetting(sysIdx, "ShowGCDSwipe")
                    if showGCD then
                        return
                    end -- Setting is ON, show swipe normally

                    -- Fix: Do not hide if the swipe is actually coming from an Aura (e.g. debuff on target)
                    if self.isOnGCD and not self.wasSetFromAura then
                        local cooldown = self:GetCooldownFrame()
                        if cooldown then
                            cooldown:SetDrawSwipe(false)
                        end
                    end
                end)
                icon.orbitGCDHooked = true
            end

            -- Apply text customization (font, size, keybinds)
            self:ApplyTextSettings(icon, systemIndex)
        end

        -- Apply manual layout to the Blizzard container
        Orbit.Skin.Icons:ApplyManualLayout(blizzFrame, activeChildren, skinSettings)

        -- Resize our anchor to match the content size (only out of combat)
        if not InCombatLockdown() then
            local w, h = blizzFrame:GetSize()
            if w and h and w > 0 and h > 0 then
                anchor:SetSize(w, h)
            end

            anchor.orbitRowHeight = blizzFrame.orbitRowHeight
            anchor.orbitColumnWidth = blizzFrame.orbitColumnWidth
        end
    end
end

-- [ TEXT CUSTOMIZATION ]----------------------------------------------------------------------------
-- Text scale sizes matching OrbitOptionsPanel
local TEXT_SCALE_SIZES = {
    Small = 10,
    Medium = 12,
    Large = 14,
    ExtraLarge = 16,
}

function Plugin:GetBaseFontSize()
    local scale = Orbit.db.GlobalSettings.TextScale
    return TEXT_SCALE_SIZES[scale] or 12
end

function Plugin:GetGlobalFont()
    local fontName = Orbit.db.GlobalSettings.Font
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        return LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    end
    return STANDARD_TEXT_FONT
end

-- NOTE: Keybind system is defined in KeybindSystem.lua (Plugin:GetSpellKeybind)

-- Get or create a high-level text overlay frame
function Plugin:GetTextOverlay(icon)
    if icon.OrbitTextOverlay then
        return icon.OrbitTextOverlay
    end

    local overlay = CreateFrame("Frame", nil, icon)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(icon:GetFrameLevel() + 20) -- Well above glow effects
    icon.OrbitTextOverlay = overlay
    return overlay
end

function Plugin:CreateKeybindText(icon)
    local overlay = self:GetTextOverlay(icon)
    local keybind = overlay:CreateFontString(nil, "OVERLAY", nil, 7) -- Sublevel 7 (highest)
    keybind:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
    keybind:Hide()
    icon.OrbitKeybind = keybind
    return keybind
end

function Plugin:ApplyTextSettings(icon, systemIndex)
    local fontPath = self:GetGlobalFont()
    local baseSize = self:GetBaseFontSize()
    local LSM = LibStub("LibSharedMedia-3.0", true)

    -- Get Canvas Mode component positions and overrides
    local positions = self:GetSetting(systemIndex, "ComponentPositions") or {}

    -- Helper to apply style overrides
    local function GetComponentStyle(key, defaultOffset)
        local pos = positions[key] or {}
        local overrides = pos.overrides or {}

        local font = fontPath
        if overrides.Font and LSM then
            font = LSM:Fetch("font", overrides.Font) or fontPath
        end

        local size = overrides.FontSize or math.max(6, baseSize + (defaultOffset or 0))

        local flags = "OUTLINE"
        if overrides.ShowShadow then
            flags = "" -- Shadow instead of outline
        end

        return font, size, flags, pos, overrides
    end

    -- Helper to apply color overrides to a text element
    local function ApplyTextColor(textElement, overrides)
        if not textElement or not textElement.SetTextColor then
            return
        end
        if not overrides then
            return
        end

        -- Class colour takes priority over custom color
        if overrides.UseClassColour then
            local _, playerClass = UnitClass("player")
            local classColor = RAID_CLASS_COLORS[playerClass]
            if classColor then
                textElement:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            end
        elseif overrides.CustomColor and overrides.CustomColorValue and type(overrides.CustomColorValue) == "table" then
            -- CustomColor is boolean toggle, CustomColorValue is the actual color table
            local c = overrides.CustomColorValue
            textElement:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
        end
    end

    -- Timer (Cooldown countdown text)
    local cooldown = icon.Cooldown or (icon.GetCooldownFrame and icon:GetCooldownFrame())
    if cooldown then
        -- Check if Timer is disabled via Canvas Mode
        if self:IsComponentDisabled("Timer", systemIndex) then
            if cooldown.SetHideCountdownNumbers then
                cooldown:SetHideCountdownNumbers(true)
            end
        else
            local timerFont, timerSize, timerFlags, timerPos, timerOverrides = GetComponentStyle("Timer", 2)
            local timerText = nil
            if cooldown.Text and cooldown.Text.SetFont then
                timerText = cooldown.Text
            else
                -- Find FontString in regions
                local regions = { cooldown:GetRegions() }
                for _, region in ipairs(regions) do
                    if region:GetObjectType() == "FontString" then
                        timerText = region
                        break
                    end
                end
            end

            if timerText then
                timerText:SetFont(timerFont, timerSize, timerFlags)
                timerText:SetDrawLayer("OVERLAY", 7) -- Highest sublevel

                -- Apply color override (class colour > custom color)
                ApplyTextColor(timerText, timerOverrides)

                -- Apply position (use shared utility)
                local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
                if ApplyTextPosition then
                    ApplyTextPosition(timerText, icon, timerPos)
                end
            end
        end
    end

    -- Charges (ChargeCount.Current FontString)
    if icon.ChargeCount and icon.ChargeCount.Current then
        -- Check if Charges is disabled via Canvas Mode
        if self:IsComponentDisabled("Charges", systemIndex) then
            -- Use alpha to hide (more reliable than Hide for child elements)
            icon.ChargeCount.orbitForceHide = true
            icon.ChargeCount:SetAlpha(0)
            icon.ChargeCount.Current:SetAlpha(0)

            -- Hook SetAlpha on the FontString to force alpha back to 0
            if not icon.ChargeCount.Current.orbitAlphaHooked then
                icon.ChargeCount.Current.orbitAlphaHooked = true
                hooksecurefunc(icon.ChargeCount.Current, "SetAlpha", function(text, alpha)
                    if icon.ChargeCount.orbitForceHide and alpha > 0 then
                        text:SetAlpha(0)
                    end
                end)
            end

            -- Hook SetText to ensure text stays invisible even when updated
            if not icon.ChargeCount.Current.orbitTextHooked then
                icon.ChargeCount.Current.orbitTextHooked = true
                hooksecurefunc(icon.ChargeCount.Current, "SetText", function(text)
                    if icon.ChargeCount.orbitForceHide then
                        text:SetAlpha(0)
                    end
                end)
            end
        else
            icon.ChargeCount.orbitForceHide = nil
            icon.ChargeCount:SetAlpha(1)
            icon.ChargeCount.Current:SetAlpha(1)
            local chargesFont, chargesSize, chargesFlags, chargesPos, chargesOverrides = GetComponentStyle("Charges", 0)
            -- Don't call Show() - let Blizzard manage visibility based on actual charges
            icon.ChargeCount.Current:SetFont(chargesFont, chargesSize, chargesFlags)
            icon.ChargeCount.Current:SetDrawLayer("OVERLAY", 7) -- Highest sublevel

            -- Apply color override (class colour > custom color)
            ApplyTextColor(icon.ChargeCount.Current, chargesOverrides)

            -- Ensure ChargeCount frame is above glows
            if icon.ChargeCount.SetFrameLevel then
                icon.ChargeCount:SetFrameLevel(icon:GetFrameLevel() + 20)
            end

            -- Apply position (use shared utility)
            local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
            if ApplyTextPosition then
                ApplyTextPosition(icon.ChargeCount.Current, icon, chargesPos)
            end
        end
    end

    -- Stacks (BuffIcon viewer uses Applications.Applications)
    if icon.Applications then
        -- Check if Stacks is disabled via Canvas Mode
        if self:IsComponentDisabled("Stacks", systemIndex) then
            icon.Applications.orbitForceHide = true
            icon.Applications:Hide()
            -- Hook Show to prevent Blizzard from overriding
            if not icon.Applications.orbitShowHooked then
                icon.Applications.orbitShowHooked = true
                hooksecurefunc(icon.Applications, "Show", function(self)
                    if self.orbitForceHide then
                        self:Hide()
                    end
                end)
            end
        else
            icon.Applications.orbitForceHide = nil
            local stacksFont, stacksSize, stacksFlags, stacksPos, stacksOverrides = GetComponentStyle("Stacks", 0)
            -- Don't call Show() - let Blizzard manage visibility based on actual stacks
            local stackText = icon.Applications.Applications or icon.Applications
            if stackText and stackText.SetFont then
                stackText:SetFont(stacksFont, stacksSize, stacksFlags)
                if stackText.SetDrawLayer then
                    stackText:SetDrawLayer("OVERLAY", 7) -- Highest sublevel
                end

                -- Apply color override (class colour > custom color)
                ApplyTextColor(stackText, stacksOverrides)

                -- Ensure Applications frame is above glows
                if icon.Applications.SetFrameLevel then
                    icon.Applications:SetFrameLevel(icon:GetFrameLevel() + 20)
                end

                -- Apply position (use shared utility)
                local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
                if ApplyTextPosition then
                    ApplyTextPosition(stackText, icon, stacksPos)
                end
            end
        end
    end

    -- Keybind display (show unless disabled via Canvas Mode)
    local showKeybinds = not self:IsComponentDisabled("Keybind", systemIndex)
    local keybindFont, keybindSize, keybindFlags, keybindPos, keybindOverrides = GetComponentStyle("Keybind", -2)

    if showKeybinds then
        local keybind = icon.OrbitKeybind or self:CreateKeybindText(icon)
        keybind:SetFont(keybindFont, keybindSize, keybindFlags)

        -- Apply color override (class colour > custom color)
        ApplyTextColor(keybind, keybindOverrides)

        -- Apply position (use shared utility)
        local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
        if ApplyTextPosition then
            ApplyTextPosition(keybind, icon, keybindPos)
        end

        -- Get spell ID from the icon
        -- NOTE: GetSpellKeybind is defined in KeybindSystem.lua which loads after CooldownManager.lua
        local spellID = icon.GetSpellID and icon:GetSpellID()
        local keyText = self.GetSpellKeybind and self:GetSpellKeybind(spellID)

        if keyText then
            keybind:SetText(keyText)
            keybind:Show()
        else
            keybind:Hide()
        end
    elseif icon.OrbitKeybind then
        icon.OrbitKeybind:Hide()
    end
end

function Plugin:GetGrowthDirection(anchorFrame)
    if not anchorFrame then
        return "DOWN"
    end

    local Engine = Orbit.Engine
    local anchorInfo = Engine.FrameAnchor and Engine.FrameAnchor.anchors[anchorFrame]
    if not anchorInfo then
        return "DOWN"
    end
    local edge = anchorInfo.edge
    if edge == "TOP" then
        return "UP"
    end
    return "DOWN"
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplyAll()
    self:ReapplyParentage()

    if self.essentialAnchor then self:ApplySettings(self.essentialAnchor) end
    if self.utilityAnchor then self:ApplySettings(self.utilityAnchor) end
    if self.buffIconAnchor then self:ApplySettings(self.buffIconAnchor) end
    if self.trackedAnchor then self:ApplyTrackedSettings(self.trackedAnchor) end
end

function Plugin:ApplySettings(frame)
    if not frame then
        self:ApplyAll()
        return
    end
    if InCombatLockdown() then return end
    if (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player")) then return end

    local systemIndex = frame.systemIndex
    local resolvedFrame = self:GetFrameBySystemIndex(systemIndex)
    if resolvedFrame then frame = resolvedFrame end
    if not frame or not frame.SetScale then return end

    if frame.isTrackedBar then
        self:ApplyTrackedSettings(frame)
        return
    end

    local size, alpha = self:GetSetting(systemIndex, "IconSize") or 100, self:GetSetting(systemIndex, "Opacity") or 100
    frame:SetScale(size / 100)
    OrbitEngine.NativeFrame:Modify(frame, { alpha = alpha / 100 })
    frame:Show()
    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)
    self:ProcessChildren(frame)
end


function Plugin:UpdateVisuals(frame)
    if frame then self:ApplySettings(frame) end
end

function Plugin:GetFrameBySystemIndex(systemIndex)
    local entry = VIEWER_MAP[systemIndex]
    return entry and entry.anchor or nil
end

function Plugin:OnDisable()
    if self.monitorTicker then
        self.monitorTicker:Cancel()
        self.monitorTicker = nil
    end
    if self.trackedTicker then
        self.trackedTicker:Cancel()
        self.trackedTicker = nil
    end
end
