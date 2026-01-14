local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_TalkingHead"

local Plugin = Orbit:RegisterPlugin("Talking Head", SYSTEM_ID, {
    defaults = {
        Scale = 60,
        DisableTalkingHead = false,
    },
}, Orbit.Constants.PluginGroups.Misc)

-- Apply NativeBarMixin for mouseOver helpers
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local WL = OrbitEngine.WidgetLogic

    local schema = {
        hideNativeSettings = true,
        controls = {
            {
                type = "checkbox",
                key = "DisableTalkingHead",
                label = "Disable",
                tooltip = "Completely hides the Talking Head frame.",
                default = false,
            },
        },
    }

    -- Scale setting
    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "Scale",
        label = "Scale",
        default = 60,
    })

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create Container
    self.frame = CreateFrame("Frame", "OrbitTalkingHeadContainer", UIParent)
    self.frame:SetSize(500, 100) -- Approximate TalkingHead size
    self.frame:SetClampedToScreen(true) -- Prevent dragging off-screen
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Talking Head"

    -- Anchor Options: Allow anchoring but disable property sync
    self.frame.anchorOptions = {
        horizontal = false,
        vertical = false,
        syncScale = false,
        syncDimensions = false,
    }

    -- Default Position (top center, like native)
    self.frame:SetPoint("TOP", UIParent, "TOP", 0, -100)

    -- Register to Orbit
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()

    -- Hook TalkingHead addon loading
    local function HookTalkingHead()
        -- Reparent immediately
        self:ReparentAll()
        self:ApplySettings()

        -- Hook play events to ensure reparenting persists
        if TalkingHeadFrame_PlayCurrent then
            hooksecurefunc("TalkingHeadFrame_PlayCurrent", function()
                self:ReparentAll()
                self:ApplySettings()
            end)
        end
    end

    if C_AddOns.IsAddOnLoaded("Blizzard_TalkingHeadUI") then
        HookTalkingHead()
    else
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(f, event, addonName)
            if addonName == "Blizzard_TalkingHeadUI" then
                HookTalkingHead()
                f:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- [ LOGIC ]-----------------------------------------------------------------------------------------
function Plugin:ReparentAll()
    if not TalkingHeadFrame then
        return
    end
    if InCombatLockdown() then
        return
    end

    -- Reparent TalkingHeadFrame into our container
    if TalkingHeadFrame:GetParent() ~= self.frame then
        TalkingHeadFrame:SetParent(self.frame)
    end

    TalkingHeadFrame:ClearAllPoints()
    TalkingHeadFrame:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then
        return
    end
    if InCombatLockdown() then
        return
    end

    -- Visibility Guard (Pet Battle / Vehicle)
    if C_PetBattles and C_PetBattles.IsInBattle() then
        frame:Hide()
        return
    end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        frame:Hide()
        return
    end

    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()

    -- Get settings
    local scale = self:GetSetting(SYSTEM_ID, "Scale") or 100
    local opacity = self:GetSetting(SYSTEM_ID, "Opacity") or 100
    local disable = self:GetSetting(SYSTEM_ID, "DisableTalkingHead")

    -- Ensure reparented
    self:ReparentAll()

    -- Apply Scale and Opacity
    frame:SetScale(scale / 100)
    frame:SetAlpha(opacity / 100)

    -- Handle disable logic
    if disable and not isEditMode then
        frame:Hide()
        if TalkingHeadFrame then
            OrbitEngine.NativeFrame:Disable(TalkingHeadFrame)
        end
    else
        frame:Show()
        if TalkingHeadFrame then
            OrbitEngine.NativeFrame:Enable(TalkingHeadFrame)

            -- Resize container to match TalkingHead content
            local w, h = TalkingHeadFrame:GetSize()
            if w and h and w > 0 and h > 0 then
                frame:SetSize(w, h)
            end

            if isEditMode then
                TalkingHeadFrame:Show()
            end
        end
    end

    -- Apply MouseOver
    self:ApplyMouseOver(frame, SYSTEM_ID)
end
