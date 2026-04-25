---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerPetFrame"
local PET_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Pet
local FRAME_LEVEL_DEMOTE = 5
local DEFAULT_POSITION_X = -250
local DEFAULT_POSITION_Y = -100

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

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= PET_FRAME_INDEX then
        return
    end

    local schema = {
        hideNativeSettings = true,
        controls = {
            { type = "slider", key = "Width", label = "Width", min = 50, max = 400, step = 1, default = 100 },
            { type = "slider", key = "Height", label = "Height", min = 20, max = 100, step = 1, default = 20 },
        },
    }

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
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
    self.frame.anchorOptions = { horizontal = false, vertical = true }
    self.frame.orbitResizeBounds = { minW = 50, maxW = 400, minH = 20, maxH = 100 }

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
    if self.frame.Name then
        OrbitEngine.ComponentDrag:Attach(self.frame.Name, self.frame, {
            key = "Name",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, PET_FRAME_INDEX, "Name"),
        })
    end
    if self.frame.HealthText then
        OrbitEngine.ComponentDrag:Attach(self.frame.HealthText, self.frame, {
            key = "HealthText",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, PET_FRAME_INDEX, "HealthText"),
        })
    end

    -- Apply settings
    self:ApplySettings(self.frame)

    -- Initial visibility check
    self:UpdateVisibility()

    -- Default Position
    if not self.frame:GetPoint() then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_POSITION_X, DEFAULT_POSITION_Y)
    end

    -- Force refresh on pet change (mount/dismount/summon/dismiss)
    self.frame:RegisterUnitEvent("UNIT_PET", "player")
    self.frame:HookScript("OnEvent", function(_, event, unit)
        if event == "UNIT_PET" and unit == "player" then
            C_Timer.After(0.2, function()
                if self.frame and UnitExists("pet") then
                    local opacity = (self:GetSetting(PET_FRAME_INDEX, "Opacity") or 100) / 100
                    self.frame:SetAlpha(opacity)
                    self.frame:UpdateAll()
                end
            end)
        end
    end)
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
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
        local opacity = (self:GetSetting(PET_FRAME_INDEX, "Opacity") or 100) / 100
        self.frame:SetAlpha(hasPet and opacity or 0.5)
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
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
end

-- [ SETTINGS APPLICATION ]---------------------------------------------------------------------------
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
        local textSize = 12
        frame.Name:SetFont(fontPath, textSize, Orbit.Skin:GetFontOutline())
        Orbit.Skin:ApplyFontShadow(frame.Name)
        frame.Name:ClearAllPoints()
        frame.Name:SetPoint("CENTER", 0, 0)
        frame.Name:SetJustifyH("CENTER")
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

    -- Restore component positions (Transaction-aware for live canvas preview)
    local savedPositions = self:GetComponentPositions(systemIndex)
    if savedPositions and next(savedPositions) then
        OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
        if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end
    end

    -- Apply Opacity (hover fade enforcement)
    local baseAlpha = (self:GetSetting(systemIndex, "Opacity") or 100) / 100
    Orbit.Animation:ApplyHoverFade(frame, baseAlpha, 1, Orbit:IsEditMode())

    local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, systemIndex, "OutOfCombatFade", enableHover) end
    -- Ensure visibility is correctly set (Edit Mode awareness)
    self:UpdateVisibility()
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
    end
end
