local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- LibCustomGlow for pandemic/proc glow effects
local LibCustomGlow = LibStub("LibCustomGlow-1.0", true)

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
-- Use the Cooldown system indices from Constants
local ESSENTIAL_INDEX = Constants.Cooldown.SystemIndex.Essential
local UTILITY_INDEX = Constants.Cooldown.SystemIndex.Utility
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon

-- Lookup table for viewer mapping (populated after OnLoad)
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
        ShowTimer = true,
        -- Glow Settings (use PandemicGlow constants for consistency)
        PandemicGlowType = Constants.PandemicGlow.DefaultType,
        PandemicGlowColor = Constants.PandemicGlow.DefaultColor,
        ProcGlowType = Constants.PandemicGlow.DefaultType,
        ProcGlowColor = Constants.PandemicGlow.DefaultColor,
    },
})

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic

    -- Get the actual frame for this systemIndex
    local frame = self:GetFrameBySystemIndex(systemIndex)

    -- Anchor Detection
    local isAnchored = frame and OrbitEngine.Frame:GetAnchorParent(frame) ~= nil

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- 1. Orientation (hide when anchored - orientation becomes fixed by anchor)
    if not isAnchored then
        WL:AddOrientationSettings(self, schema, systemIndex, dialog, systemFrame, {
            options = {
                { text = "Horizontal", value = 0 },
                { text = "Vertical", value = 1 },
            },
            default = 0,
        })
    end

    -- 2. Icon Aspect Ratio
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

    -- 3. Icon Size (Scale as %)
    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "IconSize",
        label = "Scale",
        default = Constants.Cooldown.DefaultIconSize,
    })

    -- 4. Icon Padding
    table.insert(schema.controls, {
        type = "slider",
        key = "IconPadding",
        label = "Icon Padding",
        min = -1,
        max = 10,
        step = 1,
        default = Constants.Cooldown.DefaultPadding,
    })

    -- 5. Opacity
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame)

    -- 6. Columns
    table.insert(schema.controls, {
        type = "slider",
        key = "IconLimit",
        label = "# Columns",
        min = 1,
        max = 20,
        step = 1,
        default = Constants.Cooldown.DefaultLimit,
    })

    -- 7. Swipe Color
    WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
        key = "SwipeColor",
        label = "Swipe Colour",
        default = { r = 0, g = 0, b = 0, a = 0.8 },
    }, nil)

    -- 8. Show Timer
    table.insert(schema.controls, {
        type = "checkbox",
        key = "ShowTimer",
        label = "Show Timer",
        default = true,
    })

    -- Pandemic Glow Type
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

    -- Pandemic Glow Color
    WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
        key = "PandemicGlowColor",
        label = "Pandemic Glow Colour",
        default = Constants.PandemicGlow.DefaultColor,
    }, nil)

    -- Proc Glow Type (spell activation overlays)
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

    -- Proc Glow Color
    WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
        key = "ProcGlowColor",
        label = "Proc Glow Colour",
        default = Constants.PandemicGlow.DefaultColor,
    }, nil)

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self.essentialAnchor = self:CreateAnchor("OrbitEssentialCooldowns", ESSENTIAL_INDEX, "Essential Cooldowns")
    self.utilityAnchor = self:CreateAnchor("OrbitUtilityCooldowns", UTILITY_INDEX, "Utility Cooldowns")
    self.buffIconAnchor = self:CreateAnchor("OrbitBuffIconCooldowns", BUFFICON_INDEX, "Buff Icons")

    -- Populate viewer map after anchors are created
    VIEWER_MAP = {
        [ESSENTIAL_INDEX] = { viewer = EssentialCooldownViewer, anchor = self.essentialAnchor },
        [UTILITY_INDEX] = { viewer = UtilityCooldownViewer, anchor = self.utilityAnchor },
        [BUFFICON_INDEX] = { viewer = BuffIconCooldownViewer, anchor = self.buffIconAnchor },
    }

    -- Hook Blizzard viewers for layout sync
    self:HookBlizzardViewers()

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", self.OnPlayerEnteringWorld, self)
    self:RegisterVisibilityEvents()
end

function Plugin:CreateAnchor(name, systemIndex, label)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(40, 40) -- Starting size
    frame:SetClampedToScreen(true) -- Prevent dragging off-screen
    frame.systemIndex = systemIndex
    frame.editModeName = label

    frame:EnableMouse(true)

    -- Enable anchoring in any direction
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

    self:ApplySettings(frame)
    return frame
end

function Plugin:HookBlizzardViewers()
    for _, entry in pairs(VIEWER_MAP) do
        self:SetupViewerHooks(entry.viewer, entry.anchor)
    end

    -- Re-apply parentage when Edit Mode layout changes (e.g. exit)
    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            self:ReapplyParentage()
        end, self)
    end

    -- Hook spell activation (proc) glows
    self:HookProcGlow()

    self:MonitorViewers()
end

-- Hook ActionButtonSpellAlertManager to apply custom proc glows
function Plugin:HookProcGlow()
    if not LibCustomGlow then
        return
    end
    if self.procGlowHooked then
        return
    end
    if not ActionButtonSpellAlertManager then
        return
    end

    local plugin = self

    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
        -- Check if this button belongs to one of our viewers
        local viewer = button.viewerFrame
        if not viewer then
            return
        end

        local systemIndex = nil
        if viewer == EssentialCooldownViewer then
            systemIndex = ESSENTIAL_INDEX
        elseif viewer == UtilityCooldownViewer then
            systemIndex = UTILITY_INDEX
        elseif viewer == BuffIconCooldownViewer then
            systemIndex = BUFFICON_INDEX
        end

        if not systemIndex then
            return
        end

        local GlowType = Constants.PandemicGlow.Type
        local GlowConfig = Constants.PandemicGlow

        local glowType = plugin:GetSetting(systemIndex, "ProcGlowType") or GlowType.None
        if glowType == GlowType.None then
            return
        end

        local procColor = plugin:GetSetting(systemIndex, "ProcGlowColor") or GlowConfig.DefaultColor
        local colorTable = { procColor.r, procColor.g, procColor.b, procColor.a }

        -- (Attempt to) Hide Blizzard's glow
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
                -- Fix for recycled frames: prevent start animation loop on hide/show
                local glowFrame = button["_ProcGloworbitProc"]
                if glowFrame then
                    glowFrame.startAnim = false
                    -- Fix Transparency: LibCustomGlow animations force alpha to 1. We must patch them.
                    plugin:FixGlowTransparency(glowFrame, procColor.a)
                end
            elseif glowType == GlowType.Autocast then
                local cfg = GlowConfig.Autocast
                LibCustomGlow.AutoCastGlow_Start(
                    button,
                    colorTable,
                    cfg.Particles,
                    cfg.Frequency,
                    cfg.Scale,
                    cfg.XOffset,
                    cfg.YOffset,
                    "orbitProc"
                )
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

-- Workaround for LibCustomGlow animations overriding alpha values
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
                -- Order 0 is Fade In / Hold
                -- Order 2 is Fade Out
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
-- Check pandemic state via PandemicIcon:IsShown() - reliable detection for WoW 11.0+ secret values.
-- Called from MonitorViewers ticker (every 0.25s) for efficiency.

function Plugin:CheckPandemicFrames(viewer, systemIndex)
    if not viewer then
        return
    end
    if not LibCustomGlow then
        return
    end

    local GlowType = Constants.PandemicGlow.Type
    local GlowConfig = Constants.PandemicGlow

    local glowType = self:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
    if glowType == GlowType.None then
        return
    end

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

                    -- Fix for recycled frames: prevent start animation loop
                    local glowFrame = icon["_ProcGloworbitPandemic"]
                    if glowFrame then
                        glowFrame.startAnim = false
                        self:FixGlowTransparency(glowFrame, pandemicColor.a)
                    end
                elseif glowType == GlowType.Autocast then
                    local cfg = GlowConfig.Autocast
                    LibCustomGlow.AutoCastGlow_Start(
                        icon,
                        colorTable,
                        cfg.Particles,
                        cfg.Frequency,
                        cfg.Scale,
                        cfg.XOffset,
                        cfg.YOffset,
                        "orbitPandemic"
                    )
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

    -- [ CRITICAL ]
    -- Check if Blizzard (e.g. Personal Resource Display) stole our frame
    if viewer:GetParent() ~= anchor then
        self:EnforceViewerParentage(viewer, anchor)
        return
    end

    -- [ CRITICAL ]
    -- Check if Blizzard Hidden the frame (PRD can do this without reparenting)
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

    -- Hook Layout updates
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

    -- [ ANTI-FLICKER ]
    -- Protect against PRD stealing/hiding using centralized Engine Guard
    -- Pass a restore callback (3rd arg) to re-anchor if the parent was stolen
    local function RestoreViewer(v, parent)
        if not v or not parent then
            return
        end
        -- Only restore if the anchor itself is visible
        if not anchor:IsShown() then
            return
        end

        v:ClearAllPoints()
        v:SetPoint("CENTER", parent, "CENTER", 0, 0)
        v:SetAlpha(1)
        v:Show()
    end

    OrbitEngine.Frame:Protect(viewer, anchor, RestoreViewer, { enforceShow = true })

    -- 1. Alpha Guard
    if not viewer.orbitAlphaHooked then
        hooksecurefunc(viewer, "SetAlpha", function(s, alpha)
            if s._orbitSettingAlpha then
                return
            end
            -- Only enforce if anchor is visible
            if anchor and not anchor:IsShown() then
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

    -- 2. Position Guard (SetPoint / ClearAllPoints)
    -- If Blizzard tries to move it away from our anchor
    if not viewer.orbitPosHooked then
        local function ReAnchor()
            if viewer._orbitRestoringPos then
                return
            end
            if anchor and not anchor:IsShown() then
                return
            end

            viewer._orbitRestoringPos = true
            viewer:ClearAllPoints()
            viewer:SetPoint("CENTER", anchor, "CENTER", 0, 0)
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

    -- 3. Visibility Guard (Hide)
    -- Guard.lua handles OnHide, but explicit hook helps catch it immediately
    if not viewer.orbitHideHooked then
        hooksecurefunc(viewer, "Hide", function(s)
            if s._orbitRestoringVis then
                return
            end
            if anchor and not anchor:IsShown() then
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
    viewer:ClearAllPoints()
    viewer:SetPoint("CENTER", anchor, "CENTER", 0, 0)
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

-- [ LAYOUT ENGINE ]---------------------------------------------------------------------------------
function Plugin:ProcessChildren(anchor)
    -- Layout allowed in combat (viewers are not secure headers)
    if not anchor then
        return
    end

    local entry = VIEWER_MAP[anchor.systemIndex]
    local blizzFrame = entry and entry.viewer
    if not blizzFrame then
        return
    end

    local systemIndex = anchor.systemIndex

    -- Collect visible children directly from the Blizzard container
    -- Collect visible children directly from the Blizzard container
    local activeChildren = {}
    local children = { blizzFrame:GetChildren() }
    local plugin = self

    for _, child in ipairs(children) do
        if child.layoutIndex then
            -- [ INSTANT UPDATE ]
            -- Hook OnShow to force immediate skinning/layout when Blizzard shows a frame.
            -- This prevents the "jarring" resize/jump by catching it before the next render frame.
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

                    -- 2. Force Layout Update
                    -- Check against recursion if needed, but ProcessChildren is generally safe
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
        -- Build settings for the Skin module
        local skinSettings = {
            style = 1,
            aspectRatio = self:GetSetting(systemIndex, "aspectRatio"),
            zoom = 0,
            borderStyle = 1,
            borderSize = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderSize or 2,
            swipeColor = self:GetSetting(systemIndex, "SwipeColor"),
            orientation = self:GetSetting(systemIndex, "Orientation"),
            limit = self:GetSetting(systemIndex, "IconLimit"),
            padding = self:GetSetting(systemIndex, "IconPadding"),
            size = self:GetSetting(systemIndex, "IconSize"),
            showTimer = self:GetSetting(systemIndex, "ShowTimer"),
            backdropColor = self:GetSetting(systemIndex, "BackdropColour"),
            showTooltip = false,
        }

        -- Store settings for the Skin system to use
        if not Orbit.Skin.Icons.frameSettings then
            Orbit.Skin.Icons.frameSettings = setmetatable({}, { __mode = "k" })
        end
        Orbit.Skin.Icons.frameSettings[blizzFrame] = skinSettings

        for _, icon in ipairs(activeChildren) do
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)

            -- [ GCD SWIPE REMOVAL ]
            -- Hook the refresh function to forcibly hide the swipe if it's just a GCD
            -- Blizzard's internal logic forces the swipe for GCDs, so we must correct it after the fact.
            if not icon.orbitGCDHooked and icon.RefreshSpellCooldownInfo then
                hooksecurefunc(icon, "RefreshSpellCooldownInfo", function(self)
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
        end

        -- Apply manual layout to the Blizzard container
        Orbit.Skin.Icons:ApplyManualLayout(blizzFrame, activeChildren, skinSettings)

        -- Resize our anchor to match the content size (only out of combat)
        if not InCombatLockdown() then
            local w, h = blizzFrame:GetSize()
            if w and h and w > 0 and h > 0 then
                anchor:SetSize(w, h)
            end

            -- Copy row/column dimensions for anchored children
            -- This allows syncDimensions to use row height instead of container height
            anchor.orbitRowHeight = blizzFrame.orbitRowHeight
            anchor.orbitColumnWidth = blizzFrame.orbitColumnWidth
        end
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplyAll()
    -- Ensure Blizzard frames are properly parented to our anchors before applying settings
    self:ReapplyParentage()

    if self.essentialAnchor then
        self:ApplySettings(self.essentialAnchor)
    end
    if self.utilityAnchor then
        self:ApplySettings(self.utilityAnchor)
    end
    if self.buffIconAnchor then
        self:ApplySettings(self.buffIconAnchor)
    end
end

function Plugin:ApplySettings(frame)
    -- If called without a specific frame (e.g. from ProfileManager or Init), apply to all
    if not frame then
        self:ApplyAll()
        return
    end

    if InCombatLockdown() then
        return
    end

    -- Visibility Guard (Pet Battle / Vehicle)
    if C_PetBattles and C_PetBattles.IsInBattle() then
        return
    end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        return
    end

    -- Resolve actual frame if we received a config object
    local systemIndex = frame.systemIndex
    local resolvedFrame = self:GetFrameBySystemIndex(systemIndex)
    if resolvedFrame then
        frame = resolvedFrame
    end

    if not frame or not frame.SetScale then
        return
    end

    -- Get settings
    local size = self:GetSetting(systemIndex, "IconSize") or 100
    local alpha = self:GetSetting(systemIndex, "Opacity") or 100

    -- Apply Scale (size is percentage, e.g., 100 = 100%)
    frame:SetScale(size / 100)

    -- Apply Opacity
    OrbitEngine.NativeFrame:Modify(frame, { alpha = alpha / 100 })

    -- Always visible
    frame:Show()

    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)

    -- Trigger layout refresh
    self:ProcessChildren(frame)
end

function Plugin:UpdateVisuals(frame)
    if frame then
        self:ApplySettings(frame)
    end
end

function Plugin:GetFrameBySystemIndex(systemIndex)
    local entry = VIEWER_MAP[systemIndex]
    return entry and entry.anchor or nil
end

-- Cleanup to prevent memory leaks when plugin is disabled
function Plugin:OnDisable()
    if self.monitorTicker then
        self.monitorTicker:Cancel()
        self.monitorTicker = nil
    end
end
