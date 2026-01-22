---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_TargetFrame"
local TARGET_FRAME_INDEX = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Target) or 2
local PLAYER_FRAME_INDEX = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Player) or 1

local Plugin = Orbit:RegisterPlugin("Target Frame", SYSTEM_ID, {
    canvasMode = true,  -- Enable Canvas Mode for component editing
    defaults = {
        ReactionColour = true,
        ShowAuras = true,
        AuraSize = 20,
        MaxBuffs = 16,
        ShowLevel = true,
        ShowElite = true,
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
    if systemIndex ~= TARGET_FRAME_INDEX then
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
                    self:SetSetting(TARGET_FRAME_INDEX, "ShowLevel", val)
                    self:UpdateVisualsExtended(self.frame, TARGET_FRAME_INDEX)
                end,
            },
            {
                type = "checkbox",
                key = "ShowElite",
                label = "Show Elite Icon",
                default = true,
                onChange = function(val)
                    self:SetSetting(TARGET_FRAME_INDEX, "ShowElite", val)
                    self:UpdateVisualsExtended(self.frame, TARGET_FRAME_INDEX)
                end,
            },
            {
                type = "checkbox",
                key = "EnableTargetTarget",
                label = "Enable Target Target",
                default = false,
                onChange = function(val)
                    self:SetSetting(TARGET_FRAME_INDEX, "EnableTargetTarget", val)
                    -- Immediately trigger the TargetOfTarget plugin to update visibility
                    local totPlugin = Orbit:GetPlugin("Orbit_TargetOfTargetFrame")
                    if totPlugin and totPlugin.ApplySettings then
                        totPlugin:ApplySettings()
                    end
                end,
            },
            {
                type = "checkbox",
                key = "EnableTargetPower",
                label = "Enable Target Power",
                default = false,
                onChange = function(val)
                    self:SetSetting(TARGET_FRAME_INDEX, "EnableTargetPower", val)
                    -- Immediately trigger the TargetPower plugin to update visibility
                    local tpPlugin = Orbit:GetPlugin("Orbit_TargetPower")
                    if tpPlugin and tpPlugin.UpdateVisibility then
                        tpPlugin:UpdateVisibility()
                    end
                end,
            },
        },
    }

    local enableBuffs = self:GetSetting(TARGET_FRAME_INDEX, "EnableBuffs")
    if enableBuffs == nil then
        enableBuffs = true
    end

    table.insert(schema.controls, {
        type = "checkbox",
        key = "EnableBuffs",
        label = "Enable Buffs",
        default = true,
        onChange = function(val)
            self:SetSetting(TARGET_FRAME_INDEX, "EnableBuffs", val)
            -- Immediately trigger the TargetBuffs plugin to update visibility
            local tbPlugin = Orbit:GetPlugin("Orbit_TargetBuffs")
            if tbPlugin and tbPlugin.UpdateVisibility then
                tbPlugin:UpdateVisibility()
            end
        end,
    })

    table.insert(schema.controls, {
        type = "checkbox",
        key = "EnableDebuffs",
        label = "Enable Debuffs",
        default = true,
        onChange = function(val)
            self:SetSetting(TARGET_FRAME_INDEX, "EnableDebuffs", val)
            -- Immediately trigger the TargetDebuffs plugin to update visibility
            local tdPlugin = Orbit:GetPlugin("Orbit_TargetDebuffs")
            if tdPlugin and tdPlugin.UpdateVisibility then
                tdPlugin:UpdateVisibility()
            end
        end,
    })

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    Mixin(self, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin)

    local hiddenParent = CreateFrame("Frame", "OrbitHiddenTargetParent", UIParent)
    hiddenParent:Hide()

    -- Hide native TargetFrame by moving it offscreen
    local frame = TargetFrame
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

        if frame.SetTitle then
            frame:SetTitle("")
        end
    end

    -- Note: TargetFrameToT is now managed by TargetOfTargetFrame.lua plugin

    self.container = self:CreateVisibilityContainer(UIParent)
    self.frame = OrbitEngine.UnitButton:Create(self.container, "target", "OrbitTargetFrame")
    self.frame.editModeName = "Target Frame"
    self.frame.systemIndex = TARGET_FRAME_INDEX

    RegisterUnitWatch(self.frame)

    self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")

    self.frame:RegisterEvent("UNIT_FACTION")
    self.frame:RegisterEvent("UNIT_LEVEL")
    self.frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")

    -- Create overlay container for Level/EliteIcon (use frame level, not strata, to avoid appearing above UI dialogs)
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
                local positions = pluginRef:GetSetting(TARGET_FRAME_INDEX, "ComponentPositions") or {}
                positions.LevelText = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                pluginRef:SetSetting(TARGET_FRAME_INDEX, "ComponentPositions", positions)
            end
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.RareEliteIcon, self.frame, {
            key = "RareEliteIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = pluginRef:GetSetting(TARGET_FRAME_INDEX, "ComponentPositions") or {}
                positions.RareEliteIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                pluginRef:SetSetting(TARGET_FRAME_INDEX, "ComponentPositions", positions)
            end
        })
    end

    local originalOnEvent = self.frame:GetScript("OnEvent")
    self.frame:SetScript("OnEvent", function(f, event, unit, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            f:UpdateAll()
            self:UpdateVisualsExtended(f, TARGET_FRAME_INDEX)
            return
        elseif event == "UNIT_FACTION" then
            if unit == "target" then
                f:UpdateHealth()
            end
            return
        end

        if originalOnEvent then
            originalOnEvent(f, event, unit, ...)
        end

        if event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
            self:UpdateVisualsExtended(f, TARGET_FRAME_INDEX)
        end
    end)

    self:ApplySettings(self.frame)

    if not self.frame:GetPoint() then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 200, -140)
    end

    self.frame.anchorOptions = {
        horizontal = true, -- Can anchor side-by-side (LEFT/RIGHT)
        vertical = false, -- Cannot stack above/below (TOP/BOTTOM)
        syncScale = true,
        syncDimensions = true,
        useRowDimension = true,
        mergeBorders = true,
    }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, TARGET_FRAME_INDEX)

    self:RegisterStandardEvents() -- Handle PEW and Edit Mode

    -- Edit Mode Visibility: Show frame even without target for positioning
    -- Use "player" as preview unit so we can see colors/name/health
    if OrbitEngine.EditMode then
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
    end

    local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
    if playerPlugin and playerPlugin.ApplySettings then
        local originalApply = playerPlugin.ApplySettings
        playerPlugin.ApplySettings = function(...)
            local result = originalApply(...)
            self:ApplySettings(self.frame)
            return result
        end
    end

    -- Register symmetric pair for padding sync via mouse wheel
    OrbitEngine.FrameSelection:RegisterSymmetricPair("OrbitPlayerFrame", "OrbitTargetFrame")
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------

function Plugin:UpdateLayout(frame)
    if not frame then
        return
    end
    if InCombatLockdown() then
        return
    end

    local systemIndex = TARGET_FRAME_INDEX

    local width = self:GetSetting(systemIndex, "Width") or self:GetPlayerSetting("Width") or 200
    local height = self:GetSetting(systemIndex, "Height") or self:GetPlayerSetting("Height") or 40

    -- Physical Updates only
    if not OrbitEngine.Frame:GetAnchorParent(frame) then
        frame:SetSize(width, height)
    end
end

function Plugin:ApplySettings(frame)
    frame = self.frame
    if not frame then
        return
    end

    local systemIndex = TARGET_FRAME_INDEX

    -- Use Mixin for base settings
    -- Use Mixin for base settings
    -- inheritFromPlayer handles: Border, Texture, HealthTextEnabled
    -- Explicitly pass width/height to force inheritance (ignoring local overrides)
    local width = self:GetPlayerSetting("Width")
    local height = self:GetPlayerSetting("Height")

    self:ApplyUnitFrameSettings(frame, systemIndex, {
        inheritFromPlayer = true,
        width = width,
        height = height,
    })

    -- Target Specifics
    local reactionColour = self:GetSetting(systemIndex, "ReactionColour")
    local showAuras = self:GetSetting(systemIndex, "ShowAuras")
    local classColour = self:GetPlayerSetting("ClassColour") -- Inherit class colour

    -- Logic
    frame.aurasEnabled = showAuras
    frame:SetClassColour(classColour)
    if frame.SetReactionColour then
        frame:SetReactionColour(reactionColour)
    else
        frame.reactionColour = reactionColour
    end

    -- Level/Visuals Extra (Mixin)
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

    frame:UpdateAll()
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
        self:UpdateVisualsExtended(frame, TARGET_FRAME_INDEX)
    end
end
