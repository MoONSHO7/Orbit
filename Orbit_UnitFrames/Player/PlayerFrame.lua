---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerFrame"
local PLAYER_FRAME_INDEX = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Player) or 1

-- [ ROLE ICON CONSTANTS ]--------------------------------------------------------------------------
-- Using tiny role icons matching native PlayerFrame (roleicon-tiny-*)
-- Alternative larger versions: UI-LFG-RoleIcon-*-Micro-GroupFinder
local ROLE_ATLASES = {
    TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}

-- Raid Target Icon constants
local RAID_TARGET_TEXTURE_COLUMNS = 4
local RAID_TARGET_TEXTURE_ROWS = 4

local Plugin = Orbit:RegisterPlugin("Player Frame", SYSTEM_ID, {
    canvasMode = true,  -- Enable Canvas Mode for component editing
    defaults = {
        Width = 160,
        Height = 40,
        ClassColour = true,
        HealthTextEnabled = true,
        ShowLevel = false,
        ShowCombatIcon = false,
        ShowRoleIcon = false,
        ShowLeaderIcon = false,
        ShowMarkerIcon = false,
        ShowGroupPosition = false,
        HealthTextMode = "percent_short",
        EnablePlayerPower = true,
        EnablePlayerResource = true,
        -- Aggro Indicator Settings
        AggroIndicatorEnabled = true,
        AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        AggroThickness = 2,
        -- Default component positions (Canvas Mode is single source of truth)
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            LevelText = { anchorX = "RIGHT", offsetX = -4, anchorY = "TOP", offsetY = 0, justifyH = "LEFT" },
            CombatIcon = { anchorX = "LEFT", offsetX = -2, anchorY = "TOP", offsetY = 0, justifyH = "CENTER" },
            RoleIcon = { anchorX = "LEFT", offsetX = 2, anchorY = "TOP", offsetY = -2 },
            LeaderIcon = { anchorX = "LEFT", offsetX = 20, anchorY = "TOP", offsetY = -2 },
            MarkerIcon = { anchorX = "RIGHT", offsetX = -2, anchorY = "TOP", offsetY = -2 },
            GroupPositionText = { anchorX = "LEFT", offsetX = 2, anchorY = "BOTTOM", offsetY = 2, justifyH = "LEFT" },
        },
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

-- Apply Mixins (including aggro indicator support)
Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.VisualsExtendedMixin, Orbit.AggroIndicatorMixin)

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
        key = "ShowRoleIcon",
        label = "Show Role Icon",
        default = false,
        onChange = function(val)
            self:SetSetting(PLAYER_FRAME_INDEX, "ShowRoleIcon", val)
            self:UpdateRoleIcon(self.frame, PLAYER_FRAME_INDEX)
        end,
    })

    table.insert(controls, {
        type = "checkbox",
        key = "ShowLeaderIcon",
        label = "Show Leader Icon",
        default = false,
        onChange = function(val)
            self:SetSetting(PLAYER_FRAME_INDEX, "ShowLeaderIcon", val)
            self:UpdateLeaderIcon(self.frame, PLAYER_FRAME_INDEX)
        end,
    })

    table.insert(controls, {
        type = "checkbox",
        key = "ShowMarkerIcon",
        label = "Show Marker Icon",
        default = false,
        onChange = function(val)
            self:SetSetting(PLAYER_FRAME_INDEX, "ShowMarkerIcon", val)
            self:UpdateMarkerIcon(self.frame, PLAYER_FRAME_INDEX)
        end,
    })

    table.insert(controls, {
        type = "checkbox",
        key = "ShowGroupPosition",
        label = "Show Group Position",
        default = false,
        onChange = function(val)
            self:SetSetting(PLAYER_FRAME_INDEX, "ShowGroupPosition", val)
            self:UpdateGroupPosition(self.frame, PLAYER_FRAME_INDEX)
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

    -- Create RoleIcon (Tank/Healer/DPS)
    local iconSize = 16
    if not self.frame.RoleIcon then
        self.frame.RoleIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.RoleIcon:SetSize(iconSize, iconSize)
        self.frame.RoleIcon:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 2, -2)
        self.frame.RoleIcon:Hide()
    end

    -- Create LeaderIcon
    if not self.frame.LeaderIcon then
        self.frame.LeaderIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.LeaderIcon:SetSize(iconSize, iconSize)
        self.frame.LeaderIcon:SetPoint("LEFT", self.frame.RoleIcon, "RIGHT", 2, 0)
        self.frame.LeaderIcon:Hide()
    end

    -- Create MarkerIcon (Raid Target Icon)
    if not self.frame.MarkerIcon then
        self.frame.MarkerIcon = self.frame.OverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        self.frame.MarkerIcon:SetSize(iconSize, iconSize)
        self.frame.MarkerIcon:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -2, -2)
        self.frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        self.frame.MarkerIcon:Hide()
    end

    -- Create GroupPositionText (uses global font, set in ApplySettings)
    if not self.frame.GroupPositionText then
        self.frame.GroupPositionText = self.frame.OverlayFrame:CreateFontString(nil, "OVERLAY")
        self.frame.GroupPositionText:SetDrawLayer("OVERLAY", 7)
        self.frame.GroupPositionText:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 2, 2)
        self.frame.GroupPositionText:Hide()
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
        OrbitEngine.ComponentDrag:Attach(self.frame.RoleIcon, self.frame, {
            key = "RoleIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.RoleIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.LeaderIcon, self.frame, {
            key = "LeaderIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.LeaderIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.MarkerIcon, self.frame, {
            key = "MarkerIcon",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.MarkerIcon = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end
        })
        OrbitEngine.ComponentDrag:Attach(self.frame.GroupPositionText, self.frame, {
            key = "GroupPositionText",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = pluginRef:GetSetting(PLAYER_FRAME_INDEX, "ComponentPositions") or {}
                positions.GroupPositionText = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                pluginRef:SetSetting(PLAYER_FRAME_INDEX, "ComponentPositions", positions)
            end
        })
    end

    -- Register combat events for CombatIcon
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("PLAYER_LEVEL_UP")

    -- Register events for Role/Leader/Marker/GroupPosition
    self.frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    self.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.frame:RegisterEvent("PARTY_LEADER_CHANGED")
    self.frame:RegisterEvent("RAID_TARGET_UPDATE")
    
    -- Register threat events for aggro indicator
    self.frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "player")

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
        elseif event == "PLAYER_ROLES_ASSIGNED" then
            self:UpdateRoleIcon(f, PLAYER_FRAME_INDEX)
            return
        elseif event == "GROUP_ROSTER_UPDATE" then
            self:UpdateRoleIcon(f, PLAYER_FRAME_INDEX)
            self:UpdateLeaderIcon(f, PLAYER_FRAME_INDEX)
            self:UpdateGroupPosition(f, PLAYER_FRAME_INDEX)
            return
        elseif event == "PARTY_LEADER_CHANGED" then
            self:UpdateLeaderIcon(f, PLAYER_FRAME_INDEX)
            return
        elseif event == "RAID_TARGET_UPDATE" then
            self:UpdateMarkerIcon(f, PLAYER_FRAME_INDEX)
            return
        elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
            -- Update aggro indicator
            if self.UpdateAggroIndicator then
                self:UpdateAggroIndicator(f, self)
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

    -- 3. Apply Extended Visuals (Level, Combat Icon, Status Icons)
    self:UpdateVisualsExtended(frame, systemIndex)
    self:UpdateCombatIcon(frame, systemIndex)
    self:UpdateRoleIcon(frame, systemIndex)
    self:UpdateLeaderIcon(frame, systemIndex)
    self:UpdateMarkerIcon(frame, systemIndex)
    self:UpdateGroupPosition(frame, systemIndex)

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
        self:UpdateRoleIcon(frame, PLAYER_FRAME_INDEX)
        self:UpdateLeaderIcon(frame, PLAYER_FRAME_INDEX)
        self:UpdateMarkerIcon(frame, PLAYER_FRAME_INDEX)
        self:UpdateGroupPosition(frame, PLAYER_FRAME_INDEX)
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

-- [ ROLE ICON ]-------------------------------------------------------------------------------------

function Plugin:UpdateRoleIcon(frame, systemIndex)
    if not frame or not frame.RoleIcon then
        return
    end

    local showRoleIcon = self:GetSetting(systemIndex, "ShowRoleIcon")
    if not showRoleIcon then
        frame.RoleIcon:Hide()
        return
    end

    -- Check for vehicle first
    if UnitInVehicle("player") and UnitHasVehicleUI("player") then
        frame.RoleIcon:SetAtlas("RaidFrame-Icon-Vehicle")
        frame.RoleIcon:Show()
        return
    end

    local role = UnitGroupRolesAssigned("player")
    local roleAtlas = ROLE_ATLASES[role]
    
    -- In Edit Mode, show a preview role icon if no role assigned
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    if roleAtlas then
        frame.RoleIcon:SetAtlas(roleAtlas)
        frame.RoleIcon:Show()
    elseif inEditMode then
        -- Show DPS icon as preview in Edit Mode
        frame.RoleIcon:SetAtlas(ROLE_ATLASES["DAMAGER"])
        frame.RoleIcon:Show()
    else
        frame.RoleIcon:Hide()
    end
end

-- [ LEADER ICON ]-----------------------------------------------------------------------------------

function Plugin:UpdateLeaderIcon(frame, systemIndex)
    if not frame or not frame.LeaderIcon then
        return
    end

    local showLeaderIcon = self:GetSetting(systemIndex, "ShowLeaderIcon")
    if not showLeaderIcon then
        frame.LeaderIcon:Hide()
        return
    end

    -- In Edit Mode, show a preview leader icon
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    
    if UnitIsGroupLeader("player") then
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
        frame.LeaderIcon:Show()
    elseif UnitIsGroupAssistant("player") then
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-AssistantIcon")
        frame.LeaderIcon:Show()
    elseif inEditMode then
        -- Show leader icon as preview in Edit Mode
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
        frame.LeaderIcon:Show()
    else
        frame.LeaderIcon:Hide()
    end
end

-- [ MARKER ICON ]-----------------------------------------------------------------------------------

function Plugin:UpdateMarkerIcon(frame, systemIndex)
    if not frame or not frame.MarkerIcon then
        return
    end

    local showMarkerIcon = self:GetSetting(systemIndex, "ShowMarkerIcon")
    if not showMarkerIcon then
        frame.MarkerIcon:Hide()
        return
    end

    local raidTargetIndex = GetRaidTargetIndex("player")
    
    -- In Edit Mode or Canvas Mode, show a preview marker icon if none assigned
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local inCanvasMode = OrbitEngine.ComponentEdit and OrbitEngine.ComponentEdit:IsActive(frame)
    
    -- Helper to set raid target icon using sprite sheet
    -- Also stores the index for Canvas Mode cloning
    local function SetMarkerTexCoords(iconIndex)
        frame.MarkerIcon:SetSpriteSheetCell(iconIndex, RAID_TARGET_TEXTURE_ROWS, RAID_TARGET_TEXTURE_COLUMNS)
        frame.MarkerIcon.orbitSpriteIndex = iconIndex  -- Store for Canvas Mode clone
    end
    
    if raidTargetIndex then
        SetMarkerTexCoords(raidTargetIndex)
        frame.MarkerIcon:Show()
    elseif inEditMode or inCanvasMode then
        -- Show skull marker as preview in Edit Mode or Canvas Mode (index 8)
        SetMarkerTexCoords(8)
        frame.MarkerIcon:Show()
    else
        frame.MarkerIcon:Hide()
    end
end

-- [ GROUP POSITION TEXT ]---------------------------------------------------------------------------

function Plugin:UpdateGroupPosition(frame, systemIndex)
    if not frame or not frame.GroupPositionText then
        return
    end

    local showGroupPosition = self:GetSetting(systemIndex, "ShowGroupPosition")
    if not showGroupPosition then
        frame.GroupPositionText:Hide()
        return
    end

    -- Apply global font
    local globalFontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"
    local textSize = 10
    frame.GroupPositionText:SetFont(fontPath, textSize, "OUTLINE")
    frame.GroupPositionText:SetShadowColor(0, 0, 0, 1)
    frame.GroupPositionText:SetShadowOffset(1, -1)

    -- Only show in raids
    local isInRaid = IsInRaid()
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    
    if isInRaid then
        -- Show the player's raid subgroup number (e.g., "G1")
        local raidIndex = UnitInRaid("player")
        if raidIndex then
            local _, _, subgroup = GetRaidRosterInfo(raidIndex + 1)
            if subgroup then
                frame.GroupPositionText:SetText("G" .. subgroup)
                frame.GroupPositionText:Show()
            else
                frame.GroupPositionText:Hide()
            end
        else
            frame.GroupPositionText:Hide()
        end
    elseif inEditMode then
        -- Show preview in Edit Mode
        frame.GroupPositionText:SetText("G1")
        frame.GroupPositionText:Show()
    else
        frame.GroupPositionText:Hide()
    end
end
