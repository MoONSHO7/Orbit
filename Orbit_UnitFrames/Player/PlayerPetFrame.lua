---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerPetFrame"
local PET_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Pet
local FRAME_LEVEL_DEMOTE = 5

local Plugin = Orbit:RegisterPlugin("Pet Frame", SYSTEM_ID, {
    canvasMode = true, -- Enable Canvas Mode for component editing
    defaults = {
        Width = 90,
        Height = 20,
        Opacity = 100,
        OutOfCombatFade = false,
        ShowOnMouseover = true,
        DisabledComponents = { "HealthText" },
        ComponentPositions = {
            Name = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
        },
    },
})

-- Apply Mixin
Mixin(Plugin, Orbit.UnitFrameMixin)

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= PET_FRAME_INDEX then
        return
    end

    local schema = {
        hideNativeSettings = true,
        controls = {
            { type = "slider", key = "Width", label = "Width", min = 50, max = 400, step = 1, default = 100 },
            { type = "slider", key = "Height", label = "Height", min = 10, max = 100, step = 1, default = 20 },
        },
    }

    -- Opacity (resting alpha when visible)
    local WL = OrbitEngine.WidgetLogic
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame)

    table.insert(schema.controls, {
        type = "checkbox",
        key = "OutOfCombatFade",
        label = "Out of Combat Fade",
        default = false,
        tooltip = "Hide frame when out of combat with no target",
        onChange = function(val)
            Plugin:SetSetting(systemIndex, "OutOfCombatFade", val)
            if Orbit.OOCFadeMixin then
                Orbit.OOCFadeMixin:RefreshAll()
            end
            OrbitEngine.Layout:Reset(dialog)
            self:AddSettings(dialog, systemFrame)
        end,
    })

    if self:GetSetting(PET_FRAME_INDEX, "OutOfCombatFade") then
        table.insert(schema.controls, {
            type = "checkbox",
            key = "ShowOnMouseover",
            label = "Show on Mouseover",
            default = true,
            tooltip = "Reveal frame when mousing over it",
            onChange = function(val)
                self:SetSetting(PET_FRAME_INDEX, "ShowOnMouseover", val)
                self:ApplySettings()
            end,
        })
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self:RegisterStandardEvents()
    if PetFrame then
        self:HideNativeUnitFrame(PetFrame, "OrbitHiddenPetParent")
    end

    self.container = self:CreateVisibilityContainer(UIParent)
    self.frame = OrbitEngine.UnitButton:Create(self.container, "pet", "OrbitPlayerPetFrame")
    self.frame:SetFrameLevel(math.max(1, self.frame:GetFrameLevel() - FRAME_LEVEL_DEMOTE))
    self.frame.editModeName = "Pet Frame"
    self.frame.systemIndex = PET_FRAME_INDEX
    self.frame.anchorOptions = { horizontal = false, vertical = true, syncScale = false, syncDimensions = false }

    -- Register Edit Mode callbacks for visibility updates
    if EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnShow", function()
            self:UpdateVisibility()
        end)
        EditModeManagerFrame:HookScript("OnHide", function()
            self:UpdateVisibility()
        end)
    end

    -- Attach to Orbit Frame system
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, PET_FRAME_INDEX)

    -- Canvas Mode: Register draggable components
    if OrbitEngine.ComponentDrag then
        if self.frame.Name then
            OrbitEngine.ComponentDrag:Attach(self.frame.Name, self.frame, {
                key = "Name",
                onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH, justifyV)
                    local positions = self:GetSetting(PET_FRAME_INDEX, "ComponentPositions") or {}
                    positions.Name = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH, justifyV = justifyV }
                    self:SetSetting(PET_FRAME_INDEX, "ComponentPositions", positions)
                end,
            })
        end
        if self.frame.HealthText then
            OrbitEngine.ComponentDrag:Attach(self.frame.HealthText, self.frame, {
                key = "HealthText",
                onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH, justifyV)
                    local positions = self:GetSetting(PET_FRAME_INDEX, "ComponentPositions") or {}
                    positions.HealthText = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH, justifyV = justifyV }
                    self:SetSetting(PET_FRAME_INDEX, "ComponentPositions", positions)
                end,
            })
        end
    end

    -- Apply settings
    self:ApplySettings(self.frame)

    -- Initial visibility check
    self:UpdateVisibility()

    -- Default Position
    if not self.frame:GetPoint() then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", -250, -100)
    end
end

-- [ VISIBILITY ]------------------------------------------------------------------------------------
function Plugin:UpdateVisibility()
    if not self.frame then
        return
    end
    local isEditMode = Orbit:IsEditMode()
    local hasPet = UnitExists("pet")

    if isEditMode then
        if not InCombatLockdown() then
            UnregisterUnitWatch(self.frame)
        end
        Orbit:SafeAction(function()
            self.frame:Show()
        end)
        self.frame:SetAlpha(hasPet and 1 or 0.5)
        return
    end

    if not InCombatLockdown() then
        RegisterUnitWatch(self.frame)
    else
        Orbit.CombatManager:RegisterCombatCallback(nil, function()
            if self.frame and not Orbit:IsEditMode() then
                RegisterUnitWatch(self.frame)
            end
        end)
    end
    if Orbit.OOCFadeMixin then
        Orbit.OOCFadeMixin:RefreshAll()
    else
        self.frame:SetAlpha(1)
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings(frame)
    frame = self.frame
    if not frame or InCombatLockdown() then
        return
    end
    local systemIndex = PET_FRAME_INDEX
    self:ApplyUnitFrameSettings(frame, systemIndex)

    local globalFontName = Orbit.db.GlobalSettings.Font
    local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"
    local frameHeight = frame:GetHeight()

    if frame.Name then
        local textSize = Orbit.Skin:GetAdaptiveTextSize(frameHeight, 12, 24, 0.25)
        frame.Name:SetFont(fontPath, textSize, Orbit.Skin:GetFontOutline())
        frame.Name:ClearAllPoints()
        frame.Name:SetPoint("CENTER", 0, 0)
        frame.Name:SetJustifyH("CENTER")
        frame.Name:SetShadowColor(0, 0, 0, 1)
        frame.Name:SetShadowOffset(1, -1)
    end

    local healthTextDisabled = self:IsComponentDisabled("HealthText")
    if frame.HealthText then
        if healthTextDisabled then
            frame.HealthText:Hide()
            frame.healthTextEnabled = false
        else
            frame.healthTextEnabled = true
        end
    end

    frame.UpdateTextLayout = function() end

    if frame.Power then
        frame.Power:Hide()
    end

    if frame.SetReactionColour then
        frame:SetReactionColour(true)
    end

    frame:UpdateAll()

    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)

    local isInCanvasMode = OrbitEngine.ComponentEdit and OrbitEngine.ComponentEdit:IsActive(frame)
    if not isInCanvasMode then
        local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
        if savedPositions then
            if OrbitEngine.ComponentDrag then OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions) end
            if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end
        end
    end

    if Orbit.OOCFadeMixin then
        local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, systemIndex, "OutOfCombatFade", enableHover)
    end

    -- Ensure visibility is correctly set (Edit Mode awareness)
    self:UpdateVisibility()
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
    end
end
