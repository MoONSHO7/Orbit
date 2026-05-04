---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_TargetFrame"
local TARGET_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Target
local FOCUS_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Focus or 3

local Plugin = Orbit:RegisterPlugin("Target Frame", SYSTEM_ID, {
    canvasMode = true, -- Enable Canvas Mode for component editing
    defaults = {
        Width = 160,
        Height = 30,
        SyncSize = TARGET_FRAME_INDEX,
        ReactionColour = true,
        ShowAuras = true,
        AuraSize = 20,
        MaxBuffs = 16,
        ShowLevel = true,
        ShowElite = true,
        ShowHealthValue = true,
        HealthTextMode = "percent_short",
        EnableTargetTarget = true,
        EnableTargetPower = true,
        -- Disabled components (Canvas Mode drag-to-disable)
        DisabledComponents = { "Portrait" },
        -- Default component positions (Canvas Mode is single source of truth)
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT", overrides = { FontSize = 14 } },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            LevelText = { anchorX = "RIGHT", offsetX = -3, anchorY = "TOP", offsetY = 6, justifyH = "LEFT" },
            RareEliteIcon = { anchorX = "RIGHT", offsetX = -8, anchorY = "BOTTOM", offsetY = 10, justifyH = "LEFT" },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 0 },
            Portrait = { anchorX = "LEFT", offsetX = 4, anchorY = "CENTER", offsetY = 0 },
        },
    },
})

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
local SYNC_LABELS = { L.PLU_UF_SYNC_PLAYER, L.PLU_UF_SYNC_TARGET, L.PLU_UF_SYNC_FOCUS }

local function ToggleControl(plugin, key, label, default)
    return {
        type = "checkbox", key = key, label = label, default = default,
        onChange = function(val)
            plugin:SetSetting(TARGET_FRAME_INDEX, key, val)
            Orbit.EventBus:Fire("TARGET_SETTINGS_CHANGED")
        end,
    }
end

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= TARGET_FRAME_INDEX then
        return
    end

    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_TARGET_TAB_LAYOUT, L.PLU_TARGET_TAB_BEHAVIOUR }, L.PLU_TARGET_TAB_LAYOUT)

    if currentTab == L.PLU_TARGET_TAB_LAYOUT then
        table.insert(schema.controls, {
            type = "slider", key = "SyncSize", label = L.PLU_TARGET_SYNC_SIZE,
            min = 1, max = 3, step = 1, default = TARGET_FRAME_INDEX,
            formatter = function(v) return SYNC_LABELS[v] or "" end,
            onChange = function(val)
                self:SetSetting(TARGET_FRAME_INDEX, "SyncSize", val)
                self:ApplySettings(self.frame)
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end,
        })

        if self:GetSyncSource(TARGET_FRAME_INDEX) == TARGET_FRAME_INDEX then
            local isAnchored = OrbitEngine.Frame:GetAnchorParent(self.frame) ~= nil
            local anchorAxis = isAnchored and OrbitEngine.Frame:GetAnchorAxis(self.frame) or nil
            local widthParams = { key = "Width", label = "Width", min = 50, max = 400, default = 160 }
            local heightParams = { key = "Height", label = "Height", min = 20, max = 100, default = 30 }
            if isAnchored and anchorAxis == "y" then
                widthParams, heightParams = nil, nil
            end
            SB:AddSizeSettings(self, schema, systemIndex, systemFrame, widthParams, heightParams)
        end
    elseif currentTab == L.PLU_TARGET_TAB_BEHAVIOUR then
        table.insert(schema.controls, ToggleControl(self, "EnableTargetTarget", L.PLU_TARGET_ENABLE_TOT, false))
        table.insert(schema.controls, ToggleControl(self, "EnableTargetPower", L.PLU_TARGET_ENABLE_POWER, false))
        table.insert(schema.controls, ToggleControl(self, "EnableBuffs", L.PLU_TARGET_ENABLE_BUFFS, true))
        table.insert(schema.controls, ToggleControl(self, "EnableDebuffs", L.PLU_TARGET_ENABLE_DEBUF, true))
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
-- Apply Mixins
Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin, Orbit.StatusIconMixin)
Plugin.supportsHealthText = true

function Plugin:OnLoad()
    if TargetFrame then
        OrbitEngine.NativeFrame:Park(TargetFrame)
    end

    -- Note: TargetFrameToT is now managed by TargetOfTargetFrame.lua plugin

    self.container = self:CreateVisibilityContainer(UIParent, true)
    self.mountedConfig = { frame = nil }
    self:UpdateVisibilityDriver()
    self.frame = OrbitEngine.UnitButton:Create(self.container, "target", "OrbitTargetFrame")
    self.mountedConfig.frame = self.frame
    if self.frame.HealthDamageBar then
        self.frame.HealthDamageBar:Hide()
        if self.frame.HealthDamageTexture then self.frame.HealthDamageTexture:Hide() end
        self.frame.HealthDamageBar = nil
    end
    self.frame.editModeName = "Target Frame"
    self.frame.systemIndex = TARGET_FRAME_INDEX
    self.frame.showFilterTabs = true

    RegisterUnitWatch(self.frame)

    self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")

    self.frame:RegisterUnitEvent("UNIT_FACTION", "target")
    self.frame:RegisterUnitEvent("UNIT_LEVEL", "target")
    self.frame:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", "target")
    self.frame:RegisterEvent("PLAYER_LEVEL_UP")
    self.frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "target")
    self.frame:RegisterEvent("PORTRAITS_UPDATED")
    self.frame:RegisterEvent("RAID_TARGET_UPDATE")

    self:CreateOverlayIcons(self.frame, TARGET_FRAME_INDEX)

    local originalOnEvent = self.frame:GetScript("OnEvent")
    self.frame:SetScript("OnEvent", function(f, event, unit, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            f:UpdateAll()
            f:UpdatePortrait()
            self:UpdateVisualsExtended(f, TARGET_FRAME_INDEX)
            self:UpdateMarkerIcon(f, self)
            return
        elseif event == "UNIT_FACTION" then
            if unit == "target" then
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
            self:UpdateVisualsExtended(f, TARGET_FRAME_INDEX)
        elseif event == "PLAYER_LEVEL_UP" then
            if UnitIsUnit("target", "player") then self:UpdateVisualsExtended(f, TARGET_FRAME_INDEX, unit) end
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "PORTRAITS_UPDATED" then
            f:UpdatePortrait()
        end
    end)

    self.frame.anchorOptions = { horizontal = true, vertical = false, useRowDimension = true, mergeBorders = { x = false, y = true }, independentHeight = true }
    self.frame.orbitHeightSync = true
    self.frame.orbitResizeBounds = { minW = 50, maxW = 400, minH = 10, maxH = 100 }
    self.frame.defaultPosition = { point = "CENTER", relativeTo = UIParent, relativePoint = "CENTER", x = 200, y = -140 }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, TARGET_FRAME_INDEX)

    self:ApplySettings(self.frame)

    self:RegisterStandardEvents() -- Handle PEW and Edit Mode

    -- Edit Mode Visibility: Show frame even without target for positioning
    -- Use "player" as preview unit so we can see colors/name/health
    OrbitEngine.EditMode:RegisterCallbacks({
        Enter = function()
            if self.frame and not InCombatLockdown() then
                self.isEditing = true
                UnregisterUnitWatch(self.frame)
                -- Use player as preview unit if no target exists
                if not UnitExists("target") then
                    self.frame.unit = "player"
                end
                self.frame:Show()
                self.frame:UpdateAll()
                -- Force visual update for preview
                self:UpdateVisualsExtended(self.frame, TARGET_FRAME_INDEX)
            end
        end,
        Exit = function()
            if self.frame and not InCombatLockdown() then
                self.isEditing = false
                -- Restore original unit
                self.frame.unit = "target"
                RegisterUnitWatch(self.frame)
                self.frame:UpdateAll()
                self:UpdateVisualsExtended(self.frame, TARGET_FRAME_INDEX)
            end
        end,
    }, self)

    Orbit.EventBus:On("PLAYER_SETTINGS_CHANGED", function() self:ApplySettings(self.frame) end, self)
    Orbit.EventBus:On("FOCUS_SETTINGS_CHANGED", function()
        if self:GetSyncSource(TARGET_FRAME_INDEX) == FOCUS_FRAME_INDEX then self:ApplySettings(self.frame) end
    end, self)

    OrbitEngine.FrameSelection:RegisterSymmetricPair("OrbitPlayerFrame", "OrbitTargetFrame")
end

-- [ SETTINGS APPLICATION ]---------------------------------------------------------------------------
function Plugin:UpdateLayout(frame)
    if not frame or InCombatLockdown() then
        return
    end
    local width, height = self:GetSyncedSize(TARGET_FRAME_INDEX)
    self:ApplySize(frame, width, height)
end

function Plugin:ApplySettings(frame)
    frame = self.frame
    if not frame or self._applying then
        return
    end
    self._applying = true
    local systemIndex = TARGET_FRAME_INDEX
    local width, height = self:GetSyncedSize(systemIndex)

    self:ApplyUnitFrameSettings(frame, systemIndex, { width = width, height = height })

    -- Target Specifics
    local reactionColour = self:GetSetting(systemIndex, "ReactionColour")
    local showAuras = self:GetSetting(systemIndex, "ShowAuras")
    local classColour = true

    -- Logic
    frame.aurasEnabled = showAuras
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

    -- Component positions + style overrides (positions, font, color, scale)
    -- Must run unconditionally to restore overrides after ApplyBaseVisuals resets text
    if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end

    self:UpdateVisualsExtended(frame, systemIndex)

    frame:UpdateAll()
    frame:UpdatePortrait()
    self:UpdateMarkerIcon(frame, self)

    local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, systemIndex, "OutOfCombatFade", enableHover) end

    Orbit.EventBus:Fire("TARGET_SETTINGS_CHANGED")
    self._applying = false
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
        self:UpdateVisualsExtended(frame, TARGET_FRAME_INDEX)
    end
end
