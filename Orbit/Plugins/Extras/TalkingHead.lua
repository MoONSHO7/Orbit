---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_TalkingHead"
local DEFAULT_OFFSET_Y = -100

local Plugin = Orbit:RegisterPlugin("Talking Head", SYSTEM_ID, {
    defaults = {
        Scale = 60,
    },
})

-- Apply NativeBarMixin for mouseOver helpers
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- Scale setting
    SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "Scale",
        label = L.PLU_TH_SCALE,
        default = 60,
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
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
    }

    -- Default Position (top center, like native)
    self.frame:SetPoint("TOP", UIParent, "TOP", 0, DEFAULT_OFFSET_Y)

    -- Register to Orbit
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()

    -- Hook TalkingHead addon loading
    local function HookTalkingHead()
        self:ReparentAll()
        self:ApplySettings()

        -- Hook play events to ensure settings persist (ReparentAll is called inside ApplySettings)
        if TalkingHeadFrame_PlayCurrent then
            hooksecurefunc("TalkingHeadFrame_PlayCurrent", function()
                self:ApplySettings()
            end)
        end
    end

    if C_AddOns.IsAddOnLoaded("Blizzard_TalkingHeadUI") then
        HookTalkingHead()
    else
        -- Store loader on self to prevent orphan frames on reload
        self._addonLoader = CreateFrame("Frame")
        self._addonLoader:RegisterEvent("ADDON_LOADED")
        self._addonLoader:SetScript("OnEvent", function(f, event, addonName)
            if addonName == "Blizzard_TalkingHeadUI" then
                HookTalkingHead()
                f:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- [ LOGIC ]------------------------------------------------------------------------------------------
function Plugin:ReparentAll()
    if not TalkingHeadFrame then
        return
    end
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function()
            self:ReparentAll()
        end)
        return
    end
    if TalkingHeadFrame:GetParent() ~= self.frame then
        local parent = TalkingHeadFrame:GetParent()
        -- Only capture from native Blizzard parents, never from another addon's container
        if parent ~= UIParent and parent ~= (TalkingHeadContainerFrame or UIParent) then
            self.conflicted = true
            return
        end
        TalkingHeadFrame:SetParent(self.frame)
    end

    TalkingHeadFrame:ClearAllPoints()
    TalkingHeadFrame:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    TalkingHeadFrame:EnableMouse(false)

    -- Mark as captured
    self._captured = true

    -- Suppress Blizzard's native Edit Mode selection (prevents double-highlight)
    if TalkingHeadFrame.Selection then
        TalkingHeadFrame.Selection:SetAlpha(0)
        TalkingHeadFrame.Selection:EnableMouse(false)
    end

    -- Protect TalkingHeadFrame from being stolen by other addons/Blizzard
    OrbitEngine.FrameGuard:Protect(TalkingHeadFrame, self.frame)
    OrbitEngine.FrameGuard:UpdateProtection(TalkingHeadFrame, self.frame, function()
        self:ApplySettings()
    end, { enforceShow = false })

    -- Hook SetPoint to prevent position jumping during Edit Mode transitions
    if not TalkingHeadFrame._orbitSetPointHooked then
        hooksecurefunc(TalkingHeadFrame, "SetPoint", function(f, ...)
            if f._orbitRestoringPoint then
                return
            end
            -- If Blizzard tries to reposition, immediately restore our position
            if f:GetParent() == self.frame then
                local point = ...
                if point ~= "CENTER" then
                    f._orbitRestoringPoint = true
                    f:ClearAllPoints()
                    f:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
                    f._orbitRestoringPoint = nil
                end
            end
        end)
        TalkingHeadFrame._orbitSetPointHooked = true
    end
end

function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then
        return
    end
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function()
            self:ApplySettings()
        end)
        return
    end

    local isEditMode = Orbit:IsEditMode()
    local scale = self:GetSetting(SYSTEM_ID, "Scale") or 100
    self:ReparentAll()
    frame:SetScale(scale / 100)
    frame:Show()

    if TalkingHeadFrame then
        -- Resize container to match TalkingHead content
        local w, h = TalkingHeadFrame:GetSize()
        if w and h and w > 0 and h > 0 then
            local s = frame:GetEffectiveScale()
            frame:SetSize(OrbitEngine.Pixel:Snap(w, s), OrbitEngine.Pixel:Snap(h, s))
        end

        if isEditMode then
            TalkingHeadFrame:Show()
        end
    end

    -- Apply MouseOver
    self:ApplyMouseOver(frame, SYSTEM_ID)
end

-- [ BLIZZARD HIDER ]---------------------------------------------------------------------------------
Orbit:RegisterBlizzardHider("Talking Head", function()
    if TalkingHeadFrame then OrbitEngine.NativeFrame:SecureHide(TalkingHeadFrame) end
end)
