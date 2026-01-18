local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_FocusFrame"
local FOCUS_FRAME_INDEX = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Focus) or 3 -- Default to 3 if not found, assume Focus
local PLAYER_FRAME_INDEX = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Player) or 1

-- Verify index if needed, but Enum.EditModeUnitFrameSystemIndices.Focus usually exists in modern WoW
if not Enum.EditModeUnitFrameSystemIndices.Focus then
    FOCUS_FRAME_INDEX = 3 -- Fallback
end

local Plugin = Orbit:RegisterPlugin("Focus Frame", SYSTEM_ID, {
    canvasMode = true,  -- Enable Canvas Mode for component editing
    defaults = {
        ReactionColour = true,
        ShowLevel = true,
        ShowElite = true,
        Width = 160,
        Height = 40,
        -- Default component positions (Canvas Mode is single source of truth)
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            LevelText = { anchorX = "RIGHT", offsetX = -4, anchorY = "TOP", offsetY = 0, justifyH = "LEFT" },
            RareEliteIcon = { anchorX = "RIGHT", offsetX = -2, anchorY = "BOTTOM", offsetY = 0, justifyH = "CENTER" },
        },
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= FOCUS_FRAME_INDEX then
        return
    end

    local WL = OrbitEngine.WidgetLogic

    local schema = {
        hideNativeSettings = true,
        controls = {
            {
                type = "checkbox",
                key = "ShowLevel",
                label = "Show Level",
                default = true,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "ShowLevel", val)
                    self:UpdateVisualsExtended(self.frame, FOCUS_FRAME_INDEX)
                end,
            },
            {
                type = "checkbox",
                key = "ShowElite",
                label = "Show Elite Icon",
                default = true,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "ShowElite", val)
                    self:UpdateVisualsExtended(self.frame, FOCUS_FRAME_INDEX)
                end,
            },
            {
                type = "checkbox",
                key = "EnableFocusTarget",
                label = "Enable Focus Target",
                default = false,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "EnableFocusTarget", val)
                    -- Immediately trigger the TargetOfFocus plugin to update visibility
                    local tofPlugin = Orbit:GetPlugin("Orbit_TargetOfFocusFrame")
                    if tofPlugin and tofPlugin.ApplySettings then
                        tofPlugin:ApplySettings()
                    end
                end,
            },
            {
                type = "checkbox",
                key = "EnableFocusPower",
                label = "Enable Focus Power",
                default = false,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "EnableFocusPower", val)
                    -- Immediately trigger the FocusPower plugin to update visibility
                    local fpPlugin = Orbit:GetPlugin("Orbit_FocusPower")
                    if fpPlugin and fpPlugin.UpdateVisibility then
                        fpPlugin:UpdateVisibility()
                    end
                end,
            },
            {
                type = "checkbox",
                key = "EnableBuffs",
                label = "Enable Buffs",
                default = true,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "EnableBuffs", val)
                    local fbPlugin = Orbit:GetPlugin("Orbit_FocusBuffs")
                    if fbPlugin and fbPlugin.UpdateVisibility then
                        fbPlugin:UpdateVisibility()
                    end
                end,
            },
            {
                type = "checkbox",
                key = "EnableDebuffs",
                label = "Enable Debuffs",
                default = true,
                onChange = function(val)
                    self:SetSetting(FOCUS_FRAME_INDEX, "EnableDebuffs", val)
                    local fdPlugin = Orbit:GetPlugin("Orbit_FocusDebuffs")
                    if fdPlugin and fdPlugin.UpdateVisibility then
                        fdPlugin:UpdateVisibility()
                    end
                end,
            },
        },
    }

    -- Width/Height settings are now standard via WidgetLogic if available, or we check if anchored
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(self.frame) ~= nil
    local anchorAxis = isAnchored and OrbitEngine.Frame:GetAnchorAxis(self.frame) or nil

    local widthParams = { key = "Width", label = "Width", min = 100, max = 400, default = 160 }
    local heightParams = { key = "Height", label = "Height", min = 20, max = 100, default = 40 }

    if isAnchored and anchorAxis == "x" then
        heightParams = nil
    end -- Horizontal stack locks height
    if isAnchored and anchorAxis == "y" then
        widthParams = nil
    end -- Vertical stack locks width

    if WL and WL.AddSizeSettings then
        WL:AddSizeSettings(self, schema, systemIndex, systemFrame, widthParams, heightParams)
    else
        if widthParams then
            table.insert(
                schema.controls,
                { type = "slider", key = "Width", label = "Width", min = 100, max = 400, step = 1, default = 160 }
            )
        end
        if heightParams then
            table.insert(
                schema.controls,
                { type = "slider", key = "Height", label = "Height", min = 20, max = 100, step = 1, default = 40 }
            )
        end
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    Mixin(self, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin)

    local hiddenParent = CreateFrame("Frame", "OrbitHiddenFocusParent", UIParent)
    hiddenParent:Hide()

    -- Hide native FocusFrame by moving it offscreen
    local frame = FocusFrame
    if frame then
        OrbitEngine.NativeFrame:Protect(frame)
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
        frame:SetUserPlaced(true)
        frame:SetClampRectInsets(0, 0, 0, 0)
        frame:SetClampedToScreen(false)
        -- Hook SetPoint to prevent Edit Mode/Layout resets
        if not frame.orbitSetPointHooked then
            hooksecurefunc(frame, "SetPoint", function(self)
                if InCombatLockdown() then
                    return
                end
                if not self.isMovingOffscreen then
                    self.isMovingOffscreen = true
                    self:ClearAllPoints()
                    self:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
                    self.isMovingOffscreen = false
                end
            end)
            frame.orbitSetPointHooked = true
        end

        frame:SetAlpha(0)
        frame:SetScale(0.001)
        frame:EnableMouse(false)
    end

    -- Note: FocusFrameToT is now managed by TargetOfFocusFrame.lua plugin

    self.container = self:CreateVisibilityContainer(UIParent)
    self.frame = OrbitEngine.UnitButton:Create(self.container, "focus", "OrbitFocusFrame")
    self.frame.editModeName = "Focus Frame"
    self.frame.systemIndex = FOCUS_FRAME_INDEX

    self.frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    self.frame:RegisterEvent("UNIT_FACTION")
    self.frame:RegisterEvent("UNIT_LEVEL")
    self.frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")

    -- Create a HIGH strata container for overlays (Level, EliteIcon) so they render above all frame content
    if not self.frame.OverlayFrame then
        self.frame.OverlayFrame = CreateFrame("Frame", nil, self.frame)
        self.frame.OverlayFrame:SetAllPoints()
        self.frame.OverlayFrame:SetFrameStrata("HIGH")
    end

    -- Create LevelText (on overlay frame so it stays above health bars)
    if not self.frame.LevelText then
        self.frame.LevelText = self.frame.OverlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.frame.LevelText:SetDrawLayer("OVERLAY", 7)
        self.frame.LevelText:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 4, 0)
    end

    -- Create RareEliteIcon (on overlay frame) for proper z-ordering
    if not self.frame.RareEliteIcon then
        self.frame.RareEliteIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.RareEliteIcon:SetSize(16, 16)
        self.frame.RareEliteIcon:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", 2, 0)
        self.frame.RareEliteIcon:Hide()
    end

    -- Register LevelText and RareEliteIcon for component drag with persistence callbacks
    local pluginRef = self
    if OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:Attach(self.frame.LevelText, self.frame, {
            key = "LevelText",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = pluginRef:GetSetting(FOCUS_FRAME_INDEX, "ComponentPositions") or {}
                positions.LevelText = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                pluginRef:SetSetting(FOCUS_FRAME_INDEX, "ComponentPositions", positions)
            end
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.RareEliteIcon, self.frame, {
            key = "RareEliteIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = pluginRef:GetSetting(FOCUS_FRAME_INDEX, "ComponentPositions") or {}
                positions.RareEliteIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                pluginRef:SetSetting(FOCUS_FRAME_INDEX, "ComponentPositions", positions)
            end
        })
    end

    -- Removed custom UpdateHealth override to align with Player/Target frame text behavior

    local originalOnEvent = self.frame:GetScript("OnEvent")
    self.frame:SetScript("OnEvent", function(f, event, unit, ...)
        if event == "PLAYER_FOCUS_CHANGED" then
            f:UpdateAll()
            self:UpdateVisualsExtended(f, FOCUS_FRAME_INDEX)
            return
        elseif event == "UNIT_FACTION" then
            if unit == "focus" then
                f:UpdateHealth()
            end
            return
        end

        if originalOnEvent then
            originalOnEvent(f, event, unit, ...)
        end

        if event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
            self:UpdateVisualsExtended(f, FOCUS_FRAME_INDEX)
        end
    end)

    self:ApplySettings(self.frame)

    -- Default Position
    if not self.frame:GetPoint() then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", -200, -140)
    end

    -- Can only anchor side-by-side (horizontal), not above/below (vertical)
    self.frame.anchorOptions = {
        horizontal = true,
        vertical = false,
        syncScale = true,
        syncDimensions = true,
        mergeBorders = true,
    }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, FOCUS_FRAME_INDEX)

    -- Register standard events
    self:RegisterStandardEvents()

    -- Edit Mode Visibility: Show frame even without focus for positioning
    -- Use "player" as preview unit so we can see colors/name/health
    if OrbitEngine.EditMode then
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
    end

    -- Also listen for Focus Changed to re-apply if needed (mostly for ensuring visual state)
    Orbit.EventBus:On("PLAYER_FOCUS_CHANGED", function()
        self:ApplySettings(self.frame)
    end, self)

    local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
    if playerPlugin and playerPlugin.ApplySettings then
        local originalApply = playerPlugin.ApplySettings
        playerPlugin.ApplySettings = function(...)
            local result = originalApply(...)
            self:ApplySettings(self.frame)
            return result
        end
    end
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

    -- Level Text / Classification (Handled by VisualsExtendedMixin)
    self:UpdateVisualsExtended(frame, systemIndex)

    -- Restore saved component positions LAST (overrides any defaults set above)
    -- Skip if in Canvas Mode to avoid resetting during editing
    local isInCanvasMode = OrbitEngine.ComponentEdit and OrbitEngine.ComponentEdit:IsActive(frame)
    if not isInCanvasMode then
        local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
        if savedPositions then
            -- Apply via ComponentDrag (for LevelText, RareEliteIcon)
            if OrbitEngine.ComponentDrag then
                OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
            end
            -- Apply via UnitButton mixin (for Name/HealthText with justifyH)
            if frame.ApplyComponentPositions then
                frame:ApplyComponentPositions()
            end
        end
    end

    -- Refresh Visuals
    frame:UpdateAll()
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
        self:UpdateVisualsExtended(frame, FOCUS_FRAME_INDEX)
    end
end
