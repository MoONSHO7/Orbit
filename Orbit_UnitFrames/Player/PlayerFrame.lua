---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerFrame"
local PLAYER_FRAME_INDEX = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Player) or 1

local Plugin = Orbit:RegisterPlugin("Player Frame", SYSTEM_ID, {
    canvasMode = true,  -- Enable Canvas Mode for component editing
    defaults = {
        Width = 160,
        Height = 40,
        ClassColour = true,
        HealthTextEnabled = true,
        ShowLevel = false,
        ShowCombatIcon = false,
        HealthTextMode = "percent_short",
        EnablePlayerPower = true,
        EnablePlayerResource = true,
        -- Default component positions (Canvas Mode is single source of truth)
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            LevelText = { anchorX = "RIGHT", offsetX = -4, anchorY = "TOP", offsetY = 0, justifyH = "LEFT" },
            CombatIcon = { anchorX = "LEFT", offsetX = -2, anchorY = "TOP", offsetY = 0, justifyH = "CENTER" },
        },
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

-- Apply Mixins
Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin)

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= PLAYER_FRAME_INDEX then
        return
    end

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(self.frame) ~= nil

    local controls = {
        { type = "slider", key = "Width", label = "Width", min = 120, max = 300, step = 10, default = 160 },
    }

    if not isAnchored then
        table.insert(
            controls,
            { type = "slider", key = "Height", label = "Height", min = 20, max = 60, step = 10, default = 40 }
        )
    end

    table.insert(controls, {
        type = "dropdown",
        key = "HealthTextMode",
        label = "Health Text",
        options = {
            { text = "Hide", value = "hide" },
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

    table.insert(controls, {
        type = "checkbox",
        key = "ShowLevel",
        label = "Show Level",
        default = false,
        onChange = function(val)
            self:SetSetting(PLAYER_FRAME_INDEX, "ShowLevel", val)
            self:UpdateVisualsExtended(self.frame, PLAYER_FRAME_INDEX)
        end,
    })

    table.insert(controls, {
        type = "checkbox",
        key = "ShowCombatIcon",
        label = "Show Combat Icon",
        default = false,
        onChange = function(val)
            self:SetSetting(PLAYER_FRAME_INDEX, "ShowCombatIcon", val)
            self:UpdateCombatIcon(self.frame, PLAYER_FRAME_INDEX)
        end,
    })

    table.insert(controls, {
        type = "checkbox",
        key = "EnablePlayerPower",
        label = "Enable Player Power",
        default = true,
        onChange = function(val)
            self:SetSetting(PLAYER_FRAME_INDEX, "EnablePlayerPower", val)
            -- Immediately trigger the PlayerPower plugin to update visibility
            local ppPlugin = Orbit:GetPlugin("Orbit_PlayerPower")
            if ppPlugin and ppPlugin.UpdateVisibility then
                ppPlugin:UpdateVisibility()
            end
        end,
    })

    table.insert(controls, {
        type = "checkbox",
        key = "EnablePlayerResource",
        label = "Enable Player Resource",
        default = true,
        onChange = function(val)
            self:SetSetting(PLAYER_FRAME_INDEX, "EnablePlayerResource", val)
            -- Immediately trigger the PlayerResources plugin to update visibility
            local prPlugin = Orbit:GetPlugin("Orbit_PlayerResources")
            if prPlugin and prPlugin.UpdateVisibility then
                prPlugin:UpdateVisibility()
            end
        end,
    })

    local schema = {
        hideNativeSettings = true,
        controls = controls,
    }

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self:RegisterStandardEvents() -- Auto-register PEW, EditMode -> ApplySettings

    -- Move native PlayerFrame off-screen but keep it "shown"
    -- This allows class resource bars (EvokerEbonMightBar, DemonHunterSoulFragmentsBar) to function
    if PlayerFrame then
        OrbitEngine.NativeFrame:Protect(PlayerFrame) -- Use Engine helper to protect frame state
        PlayerFrame:SetClampedToScreen(false)
        PlayerFrame:SetClampRectInsets(0, 0, 0, 0)
        PlayerFrame:ClearAllPoints()
        PlayerFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
        PlayerFrame:SetAlpha(0)
        -- Prevent user interaction
        PlayerFrame:EnableMouse(false)
        -- Hook SetPoint to prevent Edit Mode/Layout resets
        if not PlayerFrame.orbitSetPointHooked then
            hooksecurefunc(PlayerFrame, "SetPoint", function(self)
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
            PlayerFrame.orbitSetPointHooked = true
        end
    end

    self.container = self:CreateVisibilityContainer(UIParent)
    self.frame = OrbitEngine.UnitButton:Create(self.container, "player", "OrbitPlayerFrame")
    self.frame.editModeName = "Player Frame"
    self.frame.systemIndex = PLAYER_FRAME_INDEX

    self.frame.anchorOptions = {
        horizontal = true, -- Can anchor side-by-side (LEFT/RIGHT)
        vertical = true, -- Can stack above/below (TOP/BOTTOM)
        syncScale = true,
        syncDimensions = true,
        useRowDimension = true,
        mergeBorders = true,
    }
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
    if not self.frame.CombatIcon then
        self.frame.CombatIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.CombatIcon:SetAtlas("UI-HUD-UnitFrame-Player-CombatIcon", true) -- useAtlasSize=true
        self.frame.CombatIcon:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -2, 0)
        self.frame.CombatIcon:Hide()
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
            end
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.CombatIcon, self.frame, {
            key = "CombatIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.CombatIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end
        })
    end

    -- Register combat events for CombatIcon
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("PLAYER_LEVEL_UP")

    -- Hook into existing OnEvent
    local originalOnEvent = self.frame:GetScript("OnEvent")
    self.frame:SetScript("OnEvent", function(f, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            self:UpdateCombatIcon(f, PLAYER_FRAME_INDEX)
            return
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:UpdateCombatIcon(f, PLAYER_FRAME_INDEX)
            return
        elseif event == "PLAYER_LEVEL_UP" then
            self:UpdateVisualsExtended(f, PLAYER_FRAME_INDEX)
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
    if not frame then
        return
    end
    if InCombatLockdown() then
        return
    end

    local systemIndex = PLAYER_FRAME_INDEX
    local width = self:GetSetting(systemIndex, "Width")
    local height = self:GetSetting(systemIndex, "Height")
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

    -- 3. Apply Extended Visuals (Level, Combat Icon)
    self:UpdateVisualsExtended(frame, systemIndex)
    self:UpdateCombatIcon(frame, systemIndex)

    -- 4. Apply Health Text Mode
    local healthTextMode = self:GetSetting(systemIndex, "HealthTextMode") or "percent_short"
    if frame.SetHealthTextMode then
        frame:SetHealthTextMode(healthTextMode)
    end

    -- 5. Restore saved component positions LAST (overrides any defaults set above)
    -- Skip if in Canvas Mode to avoid resetting during editing
    local isInCanvasMode = OrbitEngine.ComponentEdit and OrbitEngine.ComponentEdit:IsActive(frame)
    if not isInCanvasMode then
        local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
        if savedPositions then
            -- Apply via ComponentDrag (for LevelText, CombatIcon)
            if OrbitEngine.ComponentDrag then
                OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
            end
            -- Apply via UnitButton mixin (for Name/HealthText with justifyH)
            if frame.ApplyComponentPositions then
                frame:ApplyComponentPositions()
            end
        end
    end
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
        self:UpdateVisualsExtended(frame, PLAYER_FRAME_INDEX)
        self:UpdateCombatIcon(frame, PLAYER_FRAME_INDEX)
    end
end

-- [ COMBAT ICON ]-----------------------------------------------------------------------------------

function Plugin:UpdateCombatIcon(frame, systemIndex)
    if not frame or not frame.CombatIcon then
        return
    end

    local showCombatIcon = self:GetSetting(systemIndex, "ShowCombatIcon")
    if not showCombatIcon then
        frame.CombatIcon:Hide()
        return
    end

    -- Show icon in combat, OR in Edit Mode for preview
    local inCombat = UnitAffectingCombat("player")
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    
    if inCombat or inEditMode then
        frame.CombatIcon:Show()
    else
        frame.CombatIcon:Hide()
    end
end
