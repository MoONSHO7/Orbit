---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_FocusFrame"
local FOCUS_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Focus or 3
local TARGET_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Target

local Plugin = Orbit:RegisterPlugin("Focus Frame", SYSTEM_ID, {
    displayName = L.PLG_NAME_FOCUS_FRAME,
    canvasMode = true, -- Enable Canvas Mode for component editing
    defaults = {
        ReactionColour = false,
        ShowLevel = true,
        ShowElite = true,
        ShowHealthValue = true,
        HealthTextMode = "percent_short",
        Width = 99,
        Height = 26,
        SyncSize = FOCUS_FRAME_INDEX,
        EnableFocusTarget = false,
        EnableFocusPower = true,
        EnableBuffs = false,
        Is3D = true,
        PortraitStyle = "3d",
        PortraitShape = "square",
        PortraitBorder = true,
        PortraitScale = 125,
        DisabledComponents = { "Portrait", "Status" },
        ComponentPositions = {
            Name          = { anchorX = "LEFT",   offsetX = 5,  anchorY = "CENTER", offsetY = 0, justifyH = "LEFT",   selfAnchorY = "CENTER", posX = -45, posY = 0 },
            HealthText    = { anchorX = "RIGHT",  offsetX = 5,  anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT",  selfAnchorY = "CENTER", posX = 45,  posY = 0 },
            LevelText     = { anchorX = "RIGHT",  offsetX = -5, anchorY = "TOP",    offsetY = 5, justifyH = "RIGHT",  selfAnchorY = "TOP",    posX = 48,  posY = 7 },
            RareEliteIcon = { anchorX = "RIGHT",  offsetX = -1, anchorY = "BOTTOM", offsetY = 7, justifyH = "LEFT",   selfAnchorY = "BOTTOM", posX = 49,  posY = -5 },
            MarkerIcon    = { anchorX = "CENTER", offsetX = 0,  anchorY = "TOP",    offsetY = 0, justifyH = "CENTER", selfAnchorY = "TOP",    posX = 0,   posY = 13 },
            Portrait      = { anchorX = "LEFT",   offsetX = 4,  anchorY = "CENTER", offsetY = 0 },
        },
    },
})

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
local SYNC_LABELS = { L.PLU_UF_SYNC_PLAYER, L.PLU_UF_SYNC_TARGET, L.PLU_UF_SYNC_FOCUS }

local function ToggleControl(plugin, key, label, default)
    return {
        type = "checkbox", key = key, label = label, default = default,
        onChange = function(val)
            plugin:SetSetting(FOCUS_FRAME_INDEX, key, val)
            Orbit.EventBus:Fire("ORBIT_FOCUS_SETTINGS_CHANGED")
        end,
    }
end

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= FOCUS_FRAME_INDEX then
        return
    end

    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_FOCUS_TAB_LAYOUT, L.PLU_FOCUS_TAB_BEHAVIOUR }, L.PLU_FOCUS_TAB_LAYOUT)

    if currentTab == L.PLU_FOCUS_TAB_LAYOUT then
        table.insert(schema.controls, {
            type = "slider", key = "SyncSize", label = L.PLU_FOCUS_SYNC_SIZE,
            min = 1, max = 3, step = 1, default = FOCUS_FRAME_INDEX,
            formatter = function(v) return SYNC_LABELS[v] or "" end,
            onChange = function(val)
                self:SetSetting(FOCUS_FRAME_INDEX, "SyncSize", val)
                self:ApplySettings(self.frame)
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end,
        })

        if self:GetSyncSource(FOCUS_FRAME_INDEX) == FOCUS_FRAME_INDEX then
            local isAnchored = OrbitEngine.Frame:GetAnchorParent(self.frame) ~= nil
            local anchorAxis = isAnchored and OrbitEngine.Frame:GetAnchorAxis(self.frame) or nil
            local widthParams = { key = "Width", label = L.CMN_WIDTH, min = 50, max = 400, default = 160 }
            local heightParams = { key = "Height", label = L.CMN_HEIGHT, min = 20, max = 100, default = 40 }
            if isAnchored and anchorAxis == "y" then
                widthParams, heightParams = nil, nil
            end
            SB:AddSizeSettings(self, schema, systemIndex, systemFrame, widthParams, heightParams)
        end
    elseif currentTab == L.PLU_FOCUS_TAB_BEHAVIOUR then
        table.insert(schema.controls, ToggleControl(self, "EnableFocusTarget", L.PLU_FOCUS_ENABLE_TOT, false))
        table.insert(schema.controls, ToggleControl(self, "EnableFocusPower", L.PLU_FOCUS_ENABLE_POWER, false))
        table.insert(schema.controls, ToggleControl(self, "EnableBuffs", L.PLU_FOCUS_ENABLE_BUFFS, true))
        table.insert(schema.controls, ToggleControl(self, "EnableDebuffs", L.PLU_FOCUS_ENABLE_DEBUF, true))
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
-- Apply Mixins
Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin, Orbit.StatusIconMixin)
Plugin.supportsHealthText = true

function Plugin:OnLoad()
    if FocusFrame then
        OrbitEngine.NativeFrame:Park(FocusFrame)
    end

    -- Note: FocusFrameToT is now managed by TargetOfFocusFrame.lua plugin

    self.container = self:CreateVisibilityContainer(UIParent)
    self.frame = OrbitEngine.UnitButton:Create(self.container, "focus", "OrbitFocusFrame")
    if self.frame.HealthDamageBar then
        self.frame.HealthDamageBar:Hide()
        if self.frame.HealthDamageTexture then self.frame.HealthDamageTexture:Hide() end
        self.frame.HealthDamageBar = nil
    end
    self.frame.editModeName = self.displayName
    self.frame.systemIndex = FOCUS_FRAME_INDEX
    self.frame.showFilterTabs = true


    self.frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    self.frame:RegisterUnitEvent("UNIT_FACTION", "focus")
    self.frame:RegisterUnitEvent("UNIT_LEVEL", "focus")
    self.frame:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", "focus")
    self.frame:RegisterEvent("PLAYER_LEVEL_UP")
    self.frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "focus")
    self.frame:RegisterEvent("PORTRAITS_UPDATED")
    self.frame:RegisterEvent("RAID_TARGET_UPDATE")

    self:CreateOverlayIcons(self.frame, FOCUS_FRAME_INDEX)

    -- Removed custom UpdateHealth override to align with Player/Target frame text behavior

    local originalOnEvent = self.frame:GetScript("OnEvent")
    self.frame:SetScript("OnEvent", function(f, event, unit, ...)
        if event == "PLAYER_FOCUS_CHANGED" then
            f:UpdateAll()
            f:UpdatePortrait()
            self:UpdateVisualsExtended(f, FOCUS_FRAME_INDEX)
            self:UpdateMarkerIcon(f, self)
            return
        elseif event == "UNIT_FACTION" then
            if unit == "focus" then
                f:UpdateHealth()
            end
            return
        elseif event == "RAID_TARGET_UPDATE" then
            self:UpdateMarkerIcon(f, self)
            return
        end

        if originalOnEvent then
            originalOnEvent(f, event, unit, ...)
        end

        if event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
            self:UpdateVisualsExtended(f, FOCUS_FRAME_INDEX)
        elseif event == "PLAYER_LEVEL_UP" then
            if UnitIsUnit("focus", "player") then self:UpdateVisualsExtended(f, FOCUS_FRAME_INDEX, unit) end
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "PORTRAITS_UPDATED" then
            f:UpdatePortrait()
        end
    end)

    self.frame.anchorOptions = { horizontal = true, vertical = false, useRowDimension = true, mergeBorders = { x = false, y = true }, independentHeight = true }
    self.frame.orbitHeightSync = true
    self.frame.orbitResizeBounds = { minW = 50, maxW = 400, minH = 10, maxH = 100 }
    self.frame.defaultPosition = { point = "CENTER", relativeTo = UIParent, relativePoint = "CENTER", x = Constants.UnitFrame.DefaultOffsetX, y = Constants.UnitFrame.DefaultOffsetY }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, FOCUS_FRAME_INDEX)

    self:ApplySettings(self.frame)

    -- Register standard events
    self:RegisterStandardEvents()

    -- Edit Mode: show even without focus; use "player" as preview unit for visible colors/name/health.
    OrbitEngine.EditMode:RegisterCallbacks({
        Enter = function()
            if self.frame and not InCombatLockdown() then
                self.isEditing = true
                UnregisterUnitWatch(self.frame)
                -- Use player as preview unit if no focus exists
                if not UnitExists("focus") then
                    self.frame.unit = "player"
                end
                self.frame:Show()
                self.frame:UpdateAll()
                self:UpdateVisualsExtended(self.frame, FOCUS_FRAME_INDEX)
            end
        end,
        Exit = function()
            if self.frame and not InCombatLockdown() then
                self.isEditing = false
                -- Restore original unit
                self.frame.unit = "focus"
                RegisterUnitWatch(self.frame)
                self.frame:UpdateAll()
                self:UpdateVisualsExtended(self.frame, FOCUS_FRAME_INDEX)
            end
        end,
    }, self)

    -- PLAYER_FOCUS_CHANGED is handled by the frame's own OnEvent (light update); no EventBus listener — matches TargetFrame.
    Orbit.EventBus:On("ORBIT_PLAYER_SETTINGS_CHANGED", function() self:ApplySettings(self.frame) end, self)
    Orbit.EventBus:On("ORBIT_TARGET_SETTINGS_CHANGED", function()
        if self:GetSyncSource(FOCUS_FRAME_INDEX) == TARGET_FRAME_INDEX then self:ApplySettings(self.frame) end
    end, self)
end

-- [ SETTINGS APPLICATION ]---------------------------------------------------------------------------
function Plugin:UpdateLayout(frame)
    if not frame or InCombatLockdown() then
        return
    end
    local width, height = self:GetSyncedSize(FOCUS_FRAME_INDEX)
    self:ApplySize(frame, width, height)
end

function Plugin:ApplySettings(frame)
    frame = self.frame
    if not frame or self._applying then
        return
    end
    self._applying = true
    local systemIndex = FOCUS_FRAME_INDEX
    local width, height = self:GetSyncedSize(systemIndex)

    self:ApplyUnitFrameSettings(frame, systemIndex, { width = width, height = height })

    -- Apply Focus Specific Visuals (Reaction Colour always enabled for Focus)
    local reactionColour = true
    local classColour = true

    -- Logic Props
    frame:SetClassColour(classColour)
    if frame.SetReactionColour then
        frame:SetReactionColour(reactionColour)
    else
        frame.reactionColour = reactionColour
    end
    -- Restore component positions (Transaction-aware for live canvas preview)
    local savedPositions = self:GetComponentPositions(systemIndex)
    if savedPositions and next(savedPositions) then
        OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
    end

    -- Unconditional — must run after ApplyBaseVisuals resets text overrides.
    if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end

    self:UpdateVisualsExtended(frame, systemIndex)

    frame:UpdateAll()
    frame:UpdatePortrait()
    self:UpdateMarkerIcon(frame, self)

    local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, systemIndex, "OutOfCombatFade", enableHover) end

    Orbit.EventBus:Fire("ORBIT_FOCUS_SETTINGS_CHANGED")
    self._applying = false
end

-- [ BLIZZARD HIDER ]---------------------------------------------------------------------------------
Orbit:RegisterBlizzardHider("Focus Frame", function()
    if FocusFrame then OrbitEngine.NativeFrame:Park(FocusFrame) end
end)
