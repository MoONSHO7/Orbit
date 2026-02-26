---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_TargetFrame"
local TARGET_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Target
local PLAYER_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Player

local Plugin = Orbit:RegisterPlugin("Target Frame", SYSTEM_ID, {
    canvasMode = true, -- Enable Canvas Mode for component editing
    defaults = {
        ReactionColour = true,
        ShowAuras = true,
        AuraSize = 20,
        MaxBuffs = 16,
        ShowLevel = true,
        ShowElite = true,
        EnableTargetTarget = true,
        EnableTargetPower = true,
        -- Disabled components (Canvas Mode drag-to-disable)
        DisabledComponents = {},
        -- Default component positions (Canvas Mode is single source of truth)
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            LevelText = { anchorX = "RIGHT", offsetX = -3, anchorY = "TOP", offsetY = 6, justifyH = "LEFT" },
            RareEliteIcon = { anchorX = "RIGHT", offsetX = -8, anchorY = "BOTTOM", offsetY = 10, justifyH = "LEFT" },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 0 },
            Portrait = { anchorX = "LEFT", offsetX = 4, anchorY = "CENTER", offsetY = 0 },
        },
    },
})

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= TARGET_FRAME_INDEX then
        return
    end

    local WL = OrbitEngine.WidgetLogic

    local schema = {
        hideNativeSettings = true,
        -- Note: ShowLevel and ShowElite removed - use Canvas Mode for component visibility
        controls = {
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
    Mixin(self, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin, Orbit.StatusIconMixin)
    if TargetFrame then
        OrbitEngine.NativeFrame:Hide(TargetFrame)
    end

    -- Note: TargetFrameToT is now managed by TargetOfTargetFrame.lua plugin

    self.container = self:CreateVisibilityContainer(UIParent, true)
    self.mountedConfig = { frame = nil, hoverReveal = true, combatRestore = true, targetReveal = true }
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

    self.frame:RegisterEvent("UNIT_FACTION")
    self.frame:RegisterEvent("UNIT_LEVEL")
    self.frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    self.frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    self.frame:RegisterEvent("PORTRAITS_UPDATED")
    self.frame:RegisterEvent("RAID_TARGET_UPDATE")

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
        self.frame.RareEliteIcon:SetSize(Constants.UnitFrame.StatusIconSize, Constants.UnitFrame.StatusIconSize)
        self.frame.RareEliteIcon:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", 2, 0)
        self.frame.RareEliteIcon:Hide()
    end

    if not self.frame.MarkerIcon then
        local iconSize = Constants.UnitFrame.StatusIconSize
        self.frame.MarkerIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.MarkerIcon:SetSize(iconSize, iconSize)
        self.frame.MarkerIcon.orbitOriginalWidth = iconSize
        self.frame.MarkerIcon.orbitOriginalHeight = iconSize
        self.frame.MarkerIcon:SetPoint("TOP", self.frame, "TOP", 0, -2)
        self.frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        self.frame.MarkerIcon:Hide()
    end

    self.frame:CreatePortrait()

    -- Register LevelText and RareEliteIcon for component drag with persistence callbacks
    local pluginRef = self
    if OrbitEngine.ComponentDrag then
        local MPC = function(key) return OrbitEngine.ComponentDrag:MakePositionCallback(pluginRef, TARGET_FRAME_INDEX, key) end
        OrbitEngine.ComponentDrag:Attach(self.frame.LevelText, self.frame, { key = "LevelText", onPositionChange = MPC("LevelText") })
        OrbitEngine.ComponentDrag:Attach(self.frame.RareEliteIcon, self.frame, { key = "RareEliteIcon", onPositionChange = MPC("RareEliteIcon") })
        OrbitEngine.ComponentDrag:Attach(self.frame.MarkerIcon, self.frame, { key = "MarkerIcon", onPositionChange = MPC("MarkerIcon") })
        OrbitEngine.ComponentDrag:Attach(self.frame.Portrait, self.frame, { key = "Portrait", onPositionChange = MPC("Portrait") })
    end

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
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "PORTRAITS_UPDATED" then
            f:UpdatePortrait()
        end
    end)

    self.frame.anchorOptions = { horizontal = true, vertical = false, syncScale = true, syncDimensions = true, useRowDimension = true, mergeBorders = true, independentHeight = true }
    self.frame.defaultPosition = { point = "CENTER", relativeTo = UIParent, relativePoint = "CENTER", x = 200, y = -140 }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, TARGET_FRAME_INDEX)

    self:ApplySettings(self.frame)

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
    if not frame or InCombatLockdown() then
        return
    end
    local systemIndex = TARGET_FRAME_INDEX
    local width = self:GetSetting(systemIndex, "Width") or self:GetPlayerSetting("Width") or 200
    local height = self:GetPlayerSetting("Height") or 40
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(frame) ~= nil
    if not isAnchored then
        frame:SetSize(width, height)
    else
        frame:SetWidth(width)
        frame:SetHeight(height)
    end
end

function Plugin:ApplySettings(frame)
    frame = self.frame
    if not frame then
        return
    end
    local systemIndex = TARGET_FRAME_INDEX
    local width = self:GetSetting(systemIndex, "Width")

    self:ApplyUnitFrameSettings(frame, systemIndex, {
        inheritFromPlayer = true,
        width = width,
        height = self:GetPlayerSetting("Height"),
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

    frame:UpdateAll()
    frame:UpdatePortrait()
    self:UpdateMarkerIcon(frame, self)
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
        self:UpdateVisualsExtended(frame, TARGET_FRAME_INDEX)
    end
end
