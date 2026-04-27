---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerFrame"
local PLAYER_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Player

-- Raid Target Icon constants
local RAID_TARGET_TEXTURE_COLUMNS = 4
local RAID_TARGET_TEXTURE_ROWS = 4

local Plugin = Orbit:RegisterPlugin("Player Frame", SYSTEM_ID, {
    canvasMode = true,
    defaults = {
        Width = 160,
        Height = 30,
        ClassColour = true,
        ShowHealthValue = true,
        ShowLevel = true,
        ShowCombatIcon = true,
        ShowPvpIcon = false,
        ShowRoleIcon = false,
        ShowLeaderIcon = false,
        ShowMarkerIcon = false,
        ShowGroupPosition = false,
        HealthTextMode = "percent_short",
        Opacity = 100,
        OutOfCombatFade = false,
        ShowOnMouseover = true,
        AggroIndicatorEnabled = true,
        AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        AggroThickness = 1,
        DisabledComponents = {},
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT", selfAnchorY = "CENTER", posX = -75, posY = 0, overrides = { FontSize = 14 } },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT", selfAnchorY = "CENTER", posX = 75, posY = 0, overrides = { FontSize = 14, HealthTextMode = "percent_short", ShowHealthValue = true } },
            LevelText = { anchorX = "RIGHT", offsetX = 5, anchorY = "TOP", offsetY = 6, justifyH = "LEFT", selfAnchorY = "TOP", posX = 75, posY = 9 },
            CombatIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", selfAnchorY = "CENTER", posX = 0, posY = 0 },
            RoleIcon = { anchorX = "RIGHT", offsetX = 10, anchorY = "TOP", offsetY = 3 },
            LeaderIcon = { anchorX = "LEFT", offsetX = 10, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", selfAnchorY = "TOP", posX = -70, posY = 15, overrides = { Scale = 1.1, LeaderIconStyle = "header" } },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 0, justifyH = "CENTER", selfAnchorY = "TOP", posX = 0, posY = 15, overrides = { Scale = 1 } },
            GroupPositionText = { anchorX = "RIGHT", offsetX = 5, anchorY = "BOTTOM", offsetY = 6, justifyH = "LEFT", selfAnchorY = "BOTTOM", posX = 75, posY = -9 },
            RestingIcon = { anchorX = "RIGHT", offsetX = -2, anchorY = "TOP", offsetY = -3, selfAnchorY = "TOP", posX = 81, posY = 17, overrides = { Scale = 0.6 } },
            ReadyCheckIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", selfAnchorY = "CENTER", posX = 0, posY = 0 },
            Portrait = { anchorX = "LEFT", offsetX = 4, anchorY = "CENTER", offsetY = 0 },
            PvpIcon = { anchorX = "RIGHT", offsetX = 25, anchorY = "BOTTOM", offsetY = -5, justifyH = "RIGHT", selfAnchorY = "BOTTOM", posX = 55, posY = -20, overrides = { IconSize = 22 } },
        },
    },
})

-- Apply Mixins (including aggro indicator support and shared status icons)
Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin, Orbit.AggroIndicatorMixin, Orbit.StatusIconMixin)
Plugin.supportsHealthText = true

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= PLAYER_FRAME_INDEX then
        return
    end

    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(self.frame) ~= nil
    local anchorAxis = isAnchored and OrbitEngine.Frame:GetAnchorAxis(self.frame) or nil
    local sizeOnChange = function(key) return function(val) self:SetSetting(PLAYER_FRAME_INDEX, key, val); self:UpdateLayout(self.frame) end end
    table.insert(schema.controls, { type = "slider", key = "Width", label = "Width", min = 50, max = 400, step = 1, default = 160, onChange = sizeOnChange("Width") })
    if not isAnchored or anchorAxis ~= "y" then
        table.insert(schema.controls, { type = "slider", key = "Height", label = "Height", min = 20, max = 100, step = 1, default = 30, onChange = sizeOnChange("Height") })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self:RegisterStandardEvents()
    if PlayerFrame then
        OrbitEngine.NativeFrame:Disable(PlayerFrame)
    end

    self.container = self:CreateVisibilityContainer(UIParent, true)
    self.mountedConfig = { frame = nil }
    self:UpdateVisibilityDriver()
    self.frame = OrbitEngine.UnitButton:Create(self.container, "player", "OrbitPlayerFrame")
    self.mountedConfig.frame = self.frame
    self.frame.editModeName = "Player Frame"
    self.frame.systemIndex = PLAYER_FRAME_INDEX
    self.frame.showFilterTabs = true

    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
        useRowDimension = true,
        mergeBorders = { x = false, y = true },
        independentHeight = true,
    }
    self.frame.orbitWidthSync = true
    self.frame.orbitHeightSync = true
    self.frame.orbitResizeBounds = { minW = 50, maxW = 400, minH = 10, maxH = 100 }

    self.frame:HookScript("OnSizeChanged", function()
        Orbit.EventBus:Fire("PLAYER_FRAME_RESIZED")
    end)

    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, PLAYER_FRAME_INDEX)

    -- Create overlay container for Level/CombatIcon (use frame level, not strata, to avoid appearing above UI dialogs)
    if not self.frame.OverlayFrame then
        self.frame.OverlayFrame = CreateFrame("Frame", nil, self.frame)
        self.frame.OverlayFrame:SetAllPoints()
        self.frame.OverlayFrame:SetFrameLevel(self.frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
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

    -- Create PvpIcon
    if not self.frame.PvpIcon then
        self.frame.PvpIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        local atlas = previewAtlases.PvpIcon or "AllianceAssaultsMapBanner"
        self.frame.PvpIcon:SetAtlas(atlas, true)
        local nativeW, nativeH = self.frame.PvpIcon:GetWidth(), self.frame.PvpIcon:GetHeight()
        self.frame.PvpIcon.orbitOriginalWidth = nativeW > 0 and nativeW or iconSize
        self.frame.PvpIcon.orbitOriginalHeight = nativeH > 0 and nativeH or iconSize
        local ratio = self.frame.PvpIcon.orbitOriginalHeight / self.frame.PvpIcon.orbitOriginalWidth
        self.frame.PvpIcon:SetSize(iconSize, iconSize * ratio)
        self.frame.PvpIcon:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2, 2)
        self.frame.PvpIcon:Hide()
    end

    -- Create RestingIcon (animated FlipBook)
    if not self.frame.RestingIcon then
        local restingIconSize = 20
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
        self.frame.RestingIcon.flipbookRows = FLIPBOOK_ROWS
        self.frame.RestingIcon.flipbookCols = FLIPBOOK_COLS
        self.frame.RestingIcon.flipbookFrames = FLIPBOOK_FRAMES
        self.frame.RestingIcon.flipbookDuration = FLIPBOOK_DURATION
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

    -- Create Portrait
    self.frame:CreatePortrait()

    -- Register LevelText and CombatIcon for component drag with persistence callbacks
    local pluginRef = self
    local MPC = function(key) return OrbitEngine.ComponentDrag:MakePositionCallback(pluginRef, PLAYER_FRAME_INDEX, key) end
    OrbitEngine.ComponentDrag:Attach(self.frame.LevelText, self.frame, { key = "LevelText", onPositionChange = MPC("LevelText") })
    OrbitEngine.ComponentDrag:Attach(self.frame.CombatIcon, self.frame, { key = "CombatIcon", onPositionChange = MPC("CombatIcon") })
    OrbitEngine.ComponentDrag:Attach(self.frame.RoleIcon, self.frame, { key = "RoleIcon", onPositionChange = MPC("RoleIcon") })
    OrbitEngine.ComponentDrag:Attach(self.frame.LeaderIcon, self.frame, { key = "LeaderIcon", onPositionChange = MPC("LeaderIcon") })
    OrbitEngine.ComponentDrag:Attach(self.frame.MarkerIcon, self.frame, { key = "MarkerIcon", onPositionChange = MPC("MarkerIcon") })
    OrbitEngine.ComponentDrag:Attach(self.frame.GroupPositionText, self.frame, { key = "GroupPositionText", onPositionChange = MPC("GroupPositionText") })
    OrbitEngine.ComponentDrag:Attach(self.frame.ReadyCheckIcon, self.frame, { key = "ReadyCheckIcon", onPositionChange = MPC("ReadyCheckIcon") })
    OrbitEngine.ComponentDrag:Attach(self.frame.RestingIcon, self.frame, { key = "RestingIcon", onPositionChange = MPC("RestingIcon") })
    OrbitEngine.ComponentDrag:Attach(self.frame.PvpIcon, self.frame, { key = "PvpIcon", onPositionChange = MPC("PvpIcon") })
    OrbitEngine.ComponentDrag:Attach(self.frame.Portrait, self.frame, { key = "Portrait", onPositionChange = MPC("Portrait") })

    -- Register combat events for CombatIcon
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("PLAYER_LEVEL_UP")

    -- Register events for Role/Leader/Marker/GroupPosition/Resting
    self.frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    self.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.frame:RegisterEvent("PLAYER_UPDATE_RESTING")
    self.frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
    self.frame:RegisterUnitEvent("UNIT_FACTION", "player")
    self.frame:RegisterEvent("WAR_MODE_STATUS_UPDATE")
    self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.frame:RegisterEvent("PARTY_LEADER_CHANGED")
    self.frame:RegisterEvent("RAID_TARGET_UPDATE")

    -- Register ready check events
    self.frame:RegisterEvent("READY_CHECK")
    self.frame:RegisterEvent("READY_CHECK_CONFIRM")
    self.frame:RegisterEvent("READY_CHECK_FINISHED")
    self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")

    -- Register threat events for aggro indicator
    self.frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
    self.frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    self.frame:RegisterEvent("PORTRAITS_UPDATED")

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
            local newLevel = ...
            self:UpdateVisualsExtended(f, PLAYER_FRAME_INDEX, newLevel)
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
        elseif event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FACTION" or event == "WAR_MODE_STATUS_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
            self:UpdatePvpIcon(f, self)
            return
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "PORTRAITS_UPDATED" then
            f:UpdatePortrait()
            return
        elseif event == "PLAYER_TARGET_CHANGED" then
            return
        end
        if originalOnEvent then
            originalOnEvent(f, event, ...)
        end
    end)

    self:ApplySettings(self.frame)

    Orbit.EventBus:On("GROUP_ROSTER_SETTLED", function()
        self:UpdateGroupPosition(self.frame, self)
    end, self)

    if not self.frame:GetPoint() then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", Constants.UnitFrame.DefaultOffsetX, Constants.UnitFrame.DefaultOffsetY)
    end
end

-- [ SETTINGS APPLICATION ]---------------------------------------------------------------------------
function Plugin:UpdateLayout(frame)
    if not frame or InCombatLockdown() then
        return
    end
    local systemIndex = PLAYER_FRAME_INDEX
    local width, height = self:GetSetting(systemIndex, "Width"), self:GetSetting(systemIndex, "Height")
    self:ApplySize(frame, width, height)
    self:UpdateTextSize(frame)
    if frame.ConstrainNameWidth then frame:ConstrainNameWidth() end
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

    -- Restore component positions (Transaction-aware for live canvas preview)
    local savedPositions = self:GetComponentPositions(systemIndex)
    if savedPositions and next(savedPositions) then
        OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
    end
    
    -- Component positions + style overrides (positions, font, color, scale)
    -- Must run unconditionally to restore overrides after ApplyBaseVisuals resets text
    if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end

    self:UpdateVisualsExtended(frame, systemIndex)
    self:UpdateCombatIcon(frame, self)
    self:UpdateRoleIcon(frame, self)
    self:UpdateLeaderIcon(frame, self)
    self:UpdateMarkerIcon(frame, self)
    self:UpdateGroupPosition(frame, self)
    self:UpdateReadyCheck(frame, self)
    self:UpdatePvpIcon(frame, self)
    self:UpdateRestingIcon(frame)
    frame:UpdatePortrait()

    local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, systemIndex, "OutOfCombatFade", enableHover) end
    Orbit.EventBus:Fire("PLAYER_SETTINGS_CHANGED")
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
        self:UpdatePvpIcon(frame, self)
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
