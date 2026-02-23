---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerFrame"
local PLAYER_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Player

-- Raid Target Icon constants
local RAID_TARGET_TEXTURE_COLUMNS = 4
local RAID_TARGET_TEXTURE_ROWS = 4

local Plugin = Orbit:RegisterPlugin("Player Frame", SYSTEM_ID, {
    canvasMode = true,
    defaults = {
        Width = 160,
        Height = 40,
        ClassColour = true,
        HealthTextEnabled = true,
        ShowLevel = true,
        ShowCombatIcon = true,
        ShowRoleIcon = false,
        ShowLeaderIcon = false,
        ShowMarkerIcon = false,
        ShowGroupPosition = false,
        HealthTextMode = "percent_short",
        Opacity = 100,
        OutOfCombatFade = false,
        ShowOnMouseover = true,
        EnablePlayerPower = true,
        EnablePlayerResource = true,
        AggroIndicatorEnabled = true,
        AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        AggroThickness = 1,
        DisabledComponents = {},
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            LevelText = { anchorX = "RIGHT", offsetX = 1, anchorY = "TOP", offsetY = 6, justifyH = "LEFT" },
            CombatIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
            RoleIcon = { anchorX = "RIGHT", offsetX = 10, anchorY = "TOP", offsetY = 3 },
            LeaderIcon = { anchorX = "LEFT", offsetX = 10, anchorY = "TOP", offsetY = 0 },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 0 },
            GroupPositionText = { anchorX = "RIGHT", offsetX = 0, anchorY = "BOTTOM", offsetY = 6, justifyH = "LEFT" },
            RestingIcon = { anchorX = "LEFT", offsetX = 10, anchorY = "TOP", offsetY = 5, overrides = { Scale = 0.5 } },
            ReadyCheckIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
        },
    },
})

-- Apply Mixins (including aggro indicator support and shared status icons)
Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin, Orbit.AggroIndicatorMixin, Orbit.StatusIconMixin)

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= PLAYER_FRAME_INDEX then
        return
    end

    local WL = OrbitEngine.WidgetLogic
    local schema = { hideNativeSettings = true, controls = {} }

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Visibility" }, "Layout")

    if currentTab == "Layout" then
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(self.frame) ~= nil
        local anchorAxis = isAnchored and OrbitEngine.Frame:GetAnchorAxis(self.frame) or nil
        table.insert(schema.controls, { type = "slider", key = "Width", label = "Width", min = 50, max = 300, step = 1, default = 160 })
        if not isAnchored or anchorAxis ~= "y" then
            table.insert(schema.controls, { type = "slider", key = "Height", label = "Height", min = 20, max = 60, step = 1, default = 40 })
        end
        table.insert(schema.controls, {
            type = "dropdown",
            key = "HealthTextMode",
            label = "Health Text",
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
            },
            default = "percent_short",
            onChange = function(val)
                self:SetSetting(PLAYER_FRAME_INDEX, "HealthTextMode", val)
                self:ApplySettings()
            end,
        })
        table.insert(schema.controls, {
            type = "checkbox",
            key = "EnablePlayerPower",
            label = "Enable Player Power",
            default = true,
            onChange = function(val)
                self:SetSetting(PLAYER_FRAME_INDEX, "EnablePlayerPower", val)
                local ppPlugin = Orbit:GetPlugin("Orbit_PlayerPower")
                if ppPlugin and ppPlugin.UpdateVisibility then
                    ppPlugin:UpdateVisibility()
                end
            end,
        })
        table.insert(schema.controls, {
            type = "checkbox",
            key = "EnablePlayerResource",
            label = "Enable Player Resource",
            default = true,
            onChange = function(val)
                self:SetSetting(PLAYER_FRAME_INDEX, "EnablePlayerResource", val)
                local prPlugin = Orbit:GetPlugin("Orbit_PlayerResources")
                if prPlugin and prPlugin.UpdateVisibility then
                    prPlugin:UpdateVisibility()
                end
            end,
        })
    elseif currentTab == "Visibility" then
        WL:AddOpacitySettings(self, schema, PLAYER_FRAME_INDEX, systemFrame)
        table.insert(schema.controls, {
            type = "checkbox",
            key = "OutOfCombatFade",
            label = "Out of Combat Fade",
            default = false,
            tooltip = "Hide frame when out of combat with no target",
            onChange = function(val)
                self:SetSetting(PLAYER_FRAME_INDEX, "OutOfCombatFade", val)
                if Orbit.OOCFadeMixin then
                    Orbit.OOCFadeMixin:RefreshAll()
                end
                if dialog.orbitTabCallback then
                    dialog.orbitTabCallback()
                end
            end,
        })
        if self:GetSetting(PLAYER_FRAME_INDEX, "OutOfCombatFade") then
            table.insert(schema.controls, {
                type = "checkbox",
                key = "ShowOnMouseover",
                label = "Show on Mouseover",
                default = true,
                tooltip = "Reveal frame when mousing over it",
                onChange = function(val)
                    self:SetSetting(PLAYER_FRAME_INDEX, "ShowOnMouseover", val)
                    self:ApplySettings()
                end,
            })
        end
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self:RegisterStandardEvents()
    if PlayerFrame then
        OrbitEngine.NativeFrame:Hide(PlayerFrame)
    end

    self.container = self:CreateVisibilityContainer(UIParent, true)
    self.mountedFrame = self.container
    self.mountedHoverReveal = true
    self.mountedCombatRestore = true
    self:UpdateVisibilityDriver()
    self.frame = OrbitEngine.UnitButton:Create(self.container, "player", "OrbitPlayerFrame")
    self.mountedFrame = self.frame
    self.frame.editModeName = "Player Frame"
    self.frame.systemIndex = PLAYER_FRAME_INDEX

    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
        syncScale = true,
        syncDimensions = true,
        useRowDimension = true,
        mergeBorders = true,
        independentHeight = true,
    }

    self.frame:HookScript("OnSizeChanged", function()
        local targetPlugin = Orbit:GetPlugin("Orbit_TargetFrame")
        if targetPlugin and targetPlugin.frame and targetPlugin.UpdateLayout then
            targetPlugin:UpdateLayout(targetPlugin.frame)
        end
    end)

    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, PLAYER_FRAME_INDEX)

    -- Create overlay container for Level/CombatIcon (use frame level, not strata, to avoid appearing above UI dialogs)
    if not self.frame.OverlayFrame then
        self.frame.OverlayFrame = CreateFrame("Frame", nil, self.frame)
        self.frame.OverlayFrame:SetAllPoints()
        self.frame.OverlayFrame:SetFrameLevel(self.frame:GetFrameLevel() + 20)
    end

    -- Create LevelText (on overlay frame so it stays above health bars)
    if not self.frame.LevelText then
        self.frame.LevelText = self.frame.OverlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.frame.LevelText:SetDrawLayer("OVERLAY", 7)
        self.frame.LevelText:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 4, 0)
    end

    -- Create CombatIcon (on overlay frame) using modern Blizzard atlas
    local previewAtlases = Orbit.IconPreviewAtlases or {}
    local combatIconSize = Constants.UnitFrame.CombatIconSize
    if not self.frame.CombatIcon then
        self.frame.CombatIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.CombatIcon:SetSize(combatIconSize, combatIconSize)
        self.frame.CombatIcon.orbitOriginalWidth = combatIconSize
        self.frame.CombatIcon.orbitOriginalHeight = combatIconSize
        self.frame.CombatIcon:SetAtlas(previewAtlases.CombatIcon or "UI-HUD-UnitFrame-Player-CombatIcon", false)
        self.frame.CombatIcon:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -2, 0)
        self.frame.CombatIcon:Hide()
    end

    -- Create RoleIcon (Tank/Healer/DPS)
    local iconSize = Constants.UnitFrame.StatusIconSize
    if not self.frame.RoleIcon then
        self.frame.RoleIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.RoleIcon:SetSize(iconSize, iconSize)
        self.frame.RoleIcon.orbitOriginalWidth = iconSize
        self.frame.RoleIcon.orbitOriginalHeight = iconSize
        self.frame.RoleIcon:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 2, -2)
        self.frame.RoleIcon:SetAtlas(previewAtlases.RoleIcon)
        self.frame.RoleIcon:Hide()
    end

    -- Create LeaderIcon
    if not self.frame.LeaderIcon then
        self.frame.LeaderIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.LeaderIcon:SetSize(iconSize, iconSize)
        self.frame.LeaderIcon.orbitOriginalWidth = iconSize
        self.frame.LeaderIcon.orbitOriginalHeight = iconSize
        self.frame.LeaderIcon:SetPoint("LEFT", self.frame.RoleIcon, "RIGHT", 2, 0)
        self.frame.LeaderIcon:SetAtlas(previewAtlases.LeaderIcon)
        self.frame.LeaderIcon:Hide()
    end

    -- Create MarkerIcon (Raid Target Icon)
    if not self.frame.MarkerIcon then
        self.frame.MarkerIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.MarkerIcon:SetSize(iconSize, iconSize)
        self.frame.MarkerIcon.orbitOriginalWidth = iconSize
        self.frame.MarkerIcon.orbitOriginalHeight = iconSize
        self.frame.MarkerIcon:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -2, -2)
        self.frame.MarkerIcon:SetTexture(previewAtlases.MarkerIcon or "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        local tc = Orbit.MarkerIconTexCoord or { 0.75, 1, 0.25, 0.5 }
        self.frame.MarkerIcon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        self.frame.MarkerIcon:Hide()
    end

    -- Create GroupPositionText (uses global font, set in ApplySettings)
    if not self.frame.GroupPositionText then
        self.frame.GroupPositionText = self.frame.OverlayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.frame.GroupPositionText:SetDrawLayer("OVERLAY", 7)
        self.frame.GroupPositionText:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 2, 2)
        self.frame.GroupPositionText:Hide()
    end

    -- Create ReadyCheckIcon
    if not self.frame.ReadyCheckIcon then
        self.frame.ReadyCheckIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.ReadyCheckIcon:SetSize(iconSize, iconSize)
        self.frame.ReadyCheckIcon.orbitOriginalWidth = iconSize
        self.frame.ReadyCheckIcon.orbitOriginalHeight = iconSize
        self.frame.ReadyCheckIcon:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
        self.frame.ReadyCheckIcon:SetAtlas(previewAtlases.ReadyCheckIcon or "UI-LFG-ReadyMark-Raid")
        self.frame.ReadyCheckIcon:Hide()
    end

    -- Create RestingIcon (animated FlipBook)
    if not self.frame.RestingIcon then
        local restingIconSize = 30
        self.frame.RestingIcon = CreateFrame("Frame", nil, self.frame.OverlayFrame)
        self.frame.RestingIcon:SetSize(restingIconSize, restingIconSize)
        self.frame.RestingIcon.orbitOriginalWidth = restingIconSize
        self.frame.RestingIcon.orbitOriginalHeight = restingIconSize
        self.frame.RestingIcon:SetPoint("RIGHT", self.frame, "LEFT", -2, 0)

        self.frame.RestingIcon.Texture = self.frame.RestingIcon:CreateTexture(nil, "ARTWORK")
        self.frame.RestingIcon.Texture:SetAllPoints()
        self.frame.RestingIcon.Texture:SetAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook")
        -- Icon alias for Canvas Mode detection
        self.frame.RestingIcon.Icon = self.frame.RestingIcon.Texture
        -- Preview TexCoords for Canvas Mode (frame 20 of 7x6 grid - shows full zZZ)
        self.frame.RestingIcon.Icon.orbitPreviewTexCoord = { 2 / 6, 3 / 6, 3 / 7, 4 / 7 }

        -- FlipBook animation parameters (matches Blizzard's native implementation)
        local FLIPBOOK_ROWS = 7
        local FLIPBOOK_COLS = 6
        local FLIPBOOK_FRAMES = 42
        local FLIPBOOK_DURATION = 1.5
        local frameTime = FLIPBOOK_DURATION / FLIPBOOK_FRAMES
        local frameWidth = 1 / FLIPBOOK_COLS
        local frameHeight = 1 / FLIPBOOK_ROWS

        self.frame.RestingIcon.currentFrame = 0
        self.frame.RestingIcon.elapsed = 0

        local function SetFlipBookFrame(frameIndex)
            local col = frameIndex % FLIPBOOK_COLS
            local row = math.floor(frameIndex / FLIPBOOK_COLS)
            self.frame.RestingIcon.Texture:SetTexCoord(col * frameWidth, (col + 1) * frameWidth, row * frameHeight, (row + 1) * frameHeight)
        end
        SetFlipBookFrame(0)

        self.frame.RestingIcon:SetScript("OnUpdate", function(restFrame, elapsed)
            restFrame.elapsed = restFrame.elapsed + elapsed
            if restFrame.elapsed >= frameTime then
                restFrame.elapsed = restFrame.elapsed - frameTime
                restFrame.currentFrame = (restFrame.currentFrame + 1) % FLIPBOOK_FRAMES
                SetFlipBookFrame(restFrame.currentFrame)
            end
        end)
        self.frame.RestingIcon:Hide()
    end

    -- Register LevelText and CombatIcon for component drag with persistence callbacks
    local pluginRef = self
    if OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:Attach(self.frame.LevelText, self.frame, {
            key = "LevelText",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.LevelText = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.CombatIcon, self.frame, {
            key = "CombatIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.CombatIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.RoleIcon, self.frame, {
            key = "RoleIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.RoleIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.LeaderIcon, self.frame, {
            key = "LeaderIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.LeaderIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.MarkerIcon, self.frame, {
            key = "MarkerIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.MarkerIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.GroupPositionText, self.frame, {
            key = "GroupPositionText",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.GroupPositionText = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.ReadyCheckIcon, self.frame, {
            key = "ReadyCheckIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.ReadyCheckIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.RestingIcon, self.frame, {
            key = "RestingIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.RestingIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
    end

    -- Register combat events for CombatIcon
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("PLAYER_LEVEL_UP")

    -- Register events for Role/Leader/Marker/GroupPosition/Resting
    self.frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    self.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.frame:RegisterEvent("PLAYER_UPDATE_RESTING")
    self.frame:RegisterEvent("PARTY_LEADER_CHANGED")
    self.frame:RegisterEvent("RAID_TARGET_UPDATE")

    -- Register ready check events
    self.frame:RegisterEvent("READY_CHECK")
    self.frame:RegisterEvent("READY_CHECK_CONFIRM")
    self.frame:RegisterEvent("READY_CHECK_FINISHED")
    self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")

    -- Register threat events for aggro indicator
    self.frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "player")

    -- Hook into existing OnEvent
    local originalOnEvent = self.frame:GetScript("OnEvent")
    self.frame:SetScript("OnEvent", function(f, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            self:UpdateCombatIcon(f, self)
            return
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:UpdateCombatIcon(f, self)
            return
        elseif event == "PLAYER_LEVEL_UP" then
            self:UpdateVisualsExtended(f, PLAYER_FRAME_INDEX)
            return
        elseif event == "PLAYER_ROLES_ASSIGNED" then
            self:UpdateRoleIcon(f, self)
            return
        elseif event == "GROUP_ROSTER_UPDATE" then
            self:UpdateRoleIcon(f, self)
            self:UpdateLeaderIcon(f, self)
            self:UpdateGroupPosition(f, self)
            return
        elseif event == "PARTY_LEADER_CHANGED" then
            self:UpdateLeaderIcon(f, self)
            return
        elseif event == "RAID_TARGET_UPDATE" then
            self:UpdateMarkerIcon(f, self)
            return
        elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
            -- Update aggro indicator
            if self.UpdateAggroIndicator then
                self:UpdateAggroIndicator(f, self)
            end
            return
        elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            self:UpdateReadyCheck(f, self)
            return
        elseif event == "PLAYER_UPDATE_RESTING" then
            self:UpdateRestingIcon(f)
            return
        elseif event == "PLAYER_TARGET_CHANGED" then
            local mf = self.mountedFrame
            if mf and Orbit.MountedVisibility and Orbit.MountedVisibility:ShouldHide() and mf.orbitHoverOverlay then
                if UnitExists("target") then
                    mf.orbitTargetRevealed = true
                    mf.orbitMountedSuppressed = false
                    mf:SetAlpha(1)
                    mf:SetScript("OnUpdate", nil)
                    mf.orbitHoverOverlay:Hide()
                else
                    mf.orbitTargetRevealed = false
                    mf.orbitMountedSuppressed = true
                    mf:SetAlpha(0)
                    mf.orbitHoverOverlay:Show()
                end
            end
            return
        end
        if originalOnEvent then
            originalOnEvent(f, event, ...)
        end
    end)

    self:ApplySettings(self.frame)

    if not self.frame:GetPoint() then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", -200, -140)
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:UpdateLayout(frame)
    if not frame or InCombatLockdown() then
        return
    end
    local systemIndex = PLAYER_FRAME_INDEX
    local width, height = self:GetSetting(systemIndex, "Width"), self:GetSetting(systemIndex, "Height")
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(frame) ~= nil
    if not isAnchored then
        frame:SetSize(width, height)
    else
        frame:SetWidth(width)
    end
end

function Plugin:ApplySettings(frame)
    frame = self.frame
    if not frame then
        return
    end
    local systemIndex = PLAYER_FRAME_INDEX

    -- 1. Apply Base Settings via Mixin (Handling Size, Visuals, RestorePosition)
    -- Note: UpdateTextLayout runs here but only applies defaults if no custom positions
    self:ApplyUnitFrameSettings(frame, systemIndex)

    -- 2. Apply Player Specific Logic
    local classColour = true -- Enforced
    frame:SetClassColour(classColour)

    -- Restore positions before visuals (SetFont in overrides clobbers text color)
    local isInCanvasMode = OrbitEngine.ComponentEdit and OrbitEngine.ComponentEdit:IsActive(frame)
    if not isInCanvasMode then
        local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
        if savedPositions then
            if OrbitEngine.ComponentDrag then OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions) end
            if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end
        end
    end

    self:UpdateVisualsExtended(frame, systemIndex)
    self:UpdateCombatIcon(frame, self)
    self:UpdateRoleIcon(frame, self)
    self:UpdateLeaderIcon(frame, self)
    self:UpdateMarkerIcon(frame, self)
    self:UpdateGroupPosition(frame, self)
    self:UpdateReadyCheck(frame, self)
    self:UpdateRestingIcon(frame)

    local healthTextMode = self:GetSetting(systemIndex, "HealthTextMode") or "percent_short"
    if frame.SetHealthTextMode then frame:SetHealthTextMode(healthTextMode) end

    if Orbit.OOCFadeMixin then
        local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, systemIndex, "OutOfCombatFade", enableHover)
    end
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
        self:UpdateVisualsExtended(frame, PLAYER_FRAME_INDEX)
        self:UpdateCombatIcon(frame, self)
        self:UpdateRoleIcon(frame, self)
        self:UpdateLeaderIcon(frame, self)
        self:UpdateMarkerIcon(frame, self)
        self:UpdateGroupPosition(frame, self)
    end
end

-- Icon update functions (UpdateCombatIcon, UpdateRoleIcon, UpdateLeaderIcon, UpdateMarkerIcon, UpdateGroupPosition)
-- are now provided by StatusIconMixin (mixed in above)

function Plugin:UpdateRestingIcon(frame)
    frame = frame or self.frame
    if not frame or not frame.RestingIcon then
        return
    end
    if self:IsComponentDisabled("RestingIcon") then
        frame.RestingIcon:Hide()
        return
    end
    if IsResting() then
        frame.RestingIcon:Show()
    else
        frame.RestingIcon:Hide()
    end
end
