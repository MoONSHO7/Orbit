local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerFrame"
local PLAYER_FRAME_INDEX = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Player) or 1

local Plugin = Orbit:RegisterPlugin("Player Frame", SYSTEM_ID, {
    defaults = {
        Width = 160,
        Height = 40,
        ClassColour = true,
        HealthTextEnabled = true,
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

-- Apply Mixin
Mixin(Plugin, Orbit.UnitFrameMixin)

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= PLAYER_FRAME_INDEX then
        return
    end

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(self.frame) ~= nil

    local controls = {
        { type = "slider", key = "Width", label = "Width", min = 120, max = 300, step = 5, default = 160 },
    }

    if not isAnchored then
        table.insert(
            controls,
            { type = "slider", key = "Height", label = "Height", min = 20, max = 60, step = 5, default = 40 }
        )
    end

    table.insert(controls, { type = "checkbox", key = "HealthTextEnabled", label = "Show Health Text", default = true })

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
        vertical = false, -- Cannot stack above/below (TOP/BOTTOM)
        syncScale = true,
        syncDimensions = true,
        useRowDimension = true,
        mergeBorders = true,
    }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, PLAYER_FRAME_INDEX)

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
    self:ApplyUnitFrameSettings(frame, systemIndex)

    -- 2. Apply Player Specific Logic
    local classColour = true -- Enforced
    frame:SetClassColour(classColour)
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
    end
end
