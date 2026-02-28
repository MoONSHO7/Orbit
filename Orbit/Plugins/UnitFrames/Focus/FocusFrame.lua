---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_FocusFrame"
local FOCUS_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Focus or 3

local Plugin = Orbit:RegisterPlugin("Focus Frame", SYSTEM_ID, {
    canvasMode = true, -- Enable Canvas Mode for component editing
    defaults = {
        ReactionColour = false,
        ShowLevel = true,
        ShowElite = true,
        Width = 160,
        Height = 40,
        EnableFocusTarget = true,
        EnableFocusPower = true,
        -- Disabled components (Canvas Mode drag-to-disable)
        DisabledComponents = {},
        -- Default component positions (Canvas Mode is single source of truth)
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            LevelText = { anchorX = "RIGHT", offsetX = -3, anchorY = "TOP", offsetY = 6, justifyH = "LEFT" },
            RareEliteIcon = { anchorX = "RIGHT", offsetX = -8, anchorY = "BOTTOM", offsetY = 9, justifyH = "LEFT" },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 0 },
            Portrait = { anchorX = "LEFT", offsetX = 4, anchorY = "CENTER", offsetY = 0 },
        },
    },
})

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= FOCUS_FRAME_INDEX then
        return
    end

    local SB = OrbitEngine.SchemaBuilder

    local schema = {
        hideNativeSettings = true,
        controls = {
            {
                type = "checkbox",
                key = "EnableFocusTarget",
                label = "Enable Focus Target",
                default = false,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "EnableFocusTarget", val)
                    Orbit.EventBus:Emit("FOCUS_SETTINGS_CHANGED")
                end,
            },
            {
                type = "checkbox",
                key = "EnableFocusPower",
                label = "Enable Focus Power",
                default = false,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "EnableFocusPower", val)
                    Orbit.EventBus:Emit("FOCUS_SETTINGS_CHANGED")
                end,
            },
            {
                type = "checkbox",
                key = "EnableBuffs",
                label = "Enable Buffs",
                default = true,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "EnableBuffs", val)
                    Orbit.EventBus:Emit("FOCUS_SETTINGS_CHANGED")
                end,
            },
            {
                type = "checkbox",
                key = "EnableDebuffs",
                label = "Enable Debuffs",
                default = true,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "EnableDebuffs", val)
                    Orbit.EventBus:Emit("FOCUS_SETTINGS_CHANGED")
                end,
            },
        },
    }

    -- Width/Height settings are now standard via SchemaBuilder if available, or we check if anchored
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(self.frame) ~= nil
    local anchorAxis = isAnchored and OrbitEngine.Frame:GetAnchorAxis(self.frame) or nil

    local widthParams = { key = "Width", label = "Width", min = 50, max = 400, default = 160 }
    local heightParams = { key = "Height", label = "Height", min = 10, max = 100, default = 40 }

    if isAnchored and anchorAxis == "y" then
        widthParams = nil
        heightParams = nil
    end

    SB:AddSizeSettings(self, schema, systemIndex, systemFrame, widthParams, heightParams)

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
-- Apply Mixins
Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin, Orbit.StatusIconMixin)

function Plugin:OnLoad()
    if FocusFrame then
        OrbitEngine.NativeFrame:Hide(FocusFrame)
    end

    -- Note: FocusFrameToT is now managed by TargetOfFocusFrame.lua plugin

    self.container = self:CreateVisibilityContainer(UIParent)
    self.frame = OrbitEngine.UnitButton:Create(self.container, "focus", "OrbitFocusFrame")
    if self.frame.HealthDamageBar then
        self.frame.HealthDamageBar:Hide()
        if self.frame.HealthDamageTexture then self.frame.HealthDamageTexture:Hide() end
        self.frame.HealthDamageBar = nil
    end
    self.frame.editModeName = "Focus Frame"
    self.frame.systemIndex = FOCUS_FRAME_INDEX
    self.frame.showFilterTabs = true


    self.frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    self.frame:RegisterEvent("UNIT_FACTION")
    self.frame:RegisterEvent("UNIT_LEVEL")
    self.frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    self.frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
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
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "PORTRAITS_UPDATED" then
            f:UpdatePortrait()
        end
    end)

    self:ApplySettings(self.frame)

    -- Default Position
    if not self.frame:GetPoint() then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", -200, -140)
    end

    -- Can only anchor side-by-side (horizontal), not above/below (vertical)
    self.frame.anchorOptions = { horizontal = true, vertical = false, syncScale = true, syncDimensions = true, mergeBorders = true, independentHeight = true }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, FOCUS_FRAME_INDEX)

    -- Register standard events
    self:RegisterStandardEvents()

    -- Edit Mode Visibility: Show frame even without focus for positioning
    -- Use "player" as preview unit so we can see colors/name/health
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

    -- Also listen for Focus Changed to re-apply if needed (mostly for ensuring visual state)
    Orbit.EventBus:On("PLAYER_FOCUS_CHANGED", function()
        self:ApplySettings(self.frame)
    end, self)

    -- Subscribe to PlayerFrame events (replaces monkeypatch)
    Orbit.EventBus:On("PLAYER_SETTINGS_CHANGED", function() self:ApplySettings(self.frame) end, self)
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings(frame)
    frame = self.frame
    if not frame then
        return
    end
    local systemIndex = FOCUS_FRAME_INDEX

    -- Use Mixin for base settings (Size, Texture, Border, Text Style, Absorbs)
    self:ApplyUnitFrameSettings(frame, systemIndex, { inheritFromPlayer = true })

    -- Apply Focus Specific Visuals (Reaction Colour always enabled for Focus)
    local reactionColour = true
    local classColour = self:GetPlayerSetting("ClassColour") -- Inherit class colour setting

    -- Logic Props
    frame:SetClassColour(classColour)
    if frame.SetReactionColour then
        frame:SetReactionColour(reactionColour)
    else
        frame.reactionColour = reactionColour
    end
    -- Restore positions before visuals (SetFont in overrides clobbers text color)
    local isInCanvasMode = OrbitEngine.CanvasMode:IsActive(frame)
    if not isInCanvasMode then
        local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
        if savedPositions then
            OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
            if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end
        end
    end

    self:UpdateVisualsExtended(frame, systemIndex)

    frame:UpdateAll()
    frame:UpdatePortrait()
    self:UpdateMarkerIcon(frame, self)
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
        self:UpdateVisualsExtended(frame, FOCUS_FRAME_INDEX)
    end
end
