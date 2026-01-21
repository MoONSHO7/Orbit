local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerPetFrame"
local SYSTEM_INDEX = 1 -- Arbitrary index for simple plugin? Or specific enum?
-- Pet Frame isn't in standard Enums typically, let's treat it as generic or use custom index.
-- UnitButton:Create uses systemIndex for storage. Let's use 5 (Pet) or similar if available.
-- EditModeUnitFrameSystemIndices.Pet = 3 usually.
local PET_FRAME_INDEX = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Pet) or 3

local Plugin = Orbit:RegisterPlugin("Pet Frame", SYSTEM_ID, {
    defaults = {
        Width = 100,
        Height = 20,
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

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
            { type = "slider", key = "Width", label = "Width", min = 80, max = 300, step = 5, default = 100 },
            { type = "slider", key = "Height", label = "Height", min = 10, max = 60, step = 5, default = 20 },
        },
    }

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self:RegisterStandardEvents()

    -- Hide native PetFrame
    if PetFrame then
        OrbitEngine.NativeFrame:Protect(PetFrame)
        PetFrame:SetClampedToScreen(false)
        PetFrame:SetClampRectInsets(0, 0, 0, 0)
        PetFrame:ClearAllPoints()
        PetFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
        PetFrame:SetAlpha(0)
        PetFrame:EnableMouse(false)
        -- Hook SetPoint to prevent Edit Mode/Layout resets
        if not PetFrame.orbitSetPointHooked then
            hooksecurefunc(PetFrame, "SetPoint", function(self)
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
            PetFrame.orbitSetPointHooked = true
        end
    end

    self.container = self:CreateVisibilityContainer(UIParent)
    -- Create Custom Orbit Pet Frame
    self.frame = OrbitEngine.UnitButton:Create(self.container, "pet", "OrbitPlayerPetFrame")
    self.frame.editModeName = "Pet Frame"
    self.frame.systemIndex = PET_FRAME_INDEX

    -- Enable Anchoring: vertical only (can stack above/below)
    -- Disable Property Sync: syncScale=false, syncDimensions=false
    self.frame.anchorOptions = {
        horizontal = false, -- Cannot anchor side-by-side (LEFT/RIGHT)
        vertical = true, -- Can stack above/below (TOP/BOTTOM)
        syncScale = false,
        syncDimensions = false,
    }

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

    local isEditMode = EditModeManagerFrame
        and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive()

    local hasPet = UnitExists("pet")

    if isEditMode then
        -- Disable automatic unit-based hiding in Edit Mode
        UnregisterUnitWatch(self.frame)
        
        -- Always show in Edit Mode for positioning, even without a pet
        self.frame:Show()
        self.frame:SetAlpha(hasPet and 1 or 0.5) -- Dimmed if no pet
        return
    end

    -- Re-enable automatic unit-based visibility outside Edit Mode
    RegisterUnitWatch(self.frame)
    self.frame:SetAlpha(1)
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings(frame)
    frame = self.frame
    if not frame then
        return
    end
    if InCombatLockdown() then
        return
    end

    local systemIndex = PET_FRAME_INDEX

    -- Get settings
    -- 1. Apply Base Settings via Mixin
    self:ApplyUnitFrameSettings(frame, systemIndex)

    -- 2. Pet Specific Visuals override
    -- Font
    local globalFontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"

    if frame.Name then
        local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 24, 0.25)
        frame.Name:SetFont(fontPath, textSize, "OUTLINE")
        frame.Name:ClearAllPoints()
        frame.Name:SetPoint("CENTER", 0, 0) -- Centered name since no values
        frame.Name:SetJustifyH("CENTER")
        frame.Name:SetShadowColor(0, 0, 0, 1)
        frame.Name:SetShadowOffset(1, -1)
    end

    -- Disable Health Text (too small for this frame)
    frame.healthTextEnabled = false
    if frame.HealthText then
        frame.HealthText:Hide()
    end

    -- Stub UpdateTextLayout to prevent it from overriding centered name
    frame.UpdateTextLayout = function() end

    -- Hide Power Bar if it exists (UnitButton might create it)
    if frame.Power then
        frame.Power:Hide()
    end

    -- Enable Reaction Color for consistency with Target Frame
    -- (Matches FACTION_BAR_COLORS instead of pure 0,1,0 fallback)
    if frame.SetReactionColour then
        frame:SetReactionColour(true)
    end

    -- Update frame
    frame:UpdateAll()

    -- Restore position (Again, to be safe post-update)
    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)
    
    -- Ensure visibility is correctly set (Edit Mode awareness)
    self:UpdateVisibility()
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll then
        frame:UpdateAll()
    end
end
