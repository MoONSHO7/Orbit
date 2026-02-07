---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Focus Cast Bar", "Orbit_FocusCastBar", {
    defaults = Orbit.CastBarMixin.sharedDefaults,
}, Orbit.Constants.PluginGroups.UnitFrames)

Mixin(Plugin, Orbit.CastBarMixin)

Plugin.previewText = "Focus Cast"

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    self:AddCastBarSettings(dialog, systemFrame)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    local CastBar = self:CreateCastBarFrame("OrbitFocusCastBar", {
        editModeName = "Focus Cast Bar",
        yOffset = (Orbit.Constants.PlayerCastBar.DefaultY or -150) + 50,
    })

    CastBar.anchorOptions = {
        horizontal = false,
        vertical = true,
        syncScale = true,
        syncDimensions = true,
        mergeBorders = true,
    }

    self.CastBar = CastBar
    self.Frame = CastBar

    self:InitializeSkin(CastBar)
    self:RestorePositionDebounced(CastBar, "FocusCastBar")

    -- Register cast events and pass native spellbar for BorderShield interrupt detection
    local nativeSpellbar = FocusFrame and FocusFrame.spellbar
    self:RegisterUnitCastEvents(CastBar, "focus")
    self:SetupUnitCastBar(CastBar, "focus", nativeSpellbar)
    self:SetupCastBarOnUpdate(CastBar)

    self:RegisterEditModeCallbacks(CastBar)
    self:RegisterWorldEvent(CastBar, "FocusCastBar")
end

-- [ APPLY SETTINGS ]--------------------------------------------------------------------------------
function Plugin:ApplySettings(systemFrame)
    local bar = self.CastBar
    if not bar then return end
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(bar) ~= nil
    self:ApplyBaseSettings(bar, 1, isAnchored)
    OrbitEngine.Frame:RestorePosition(bar, self, 1)
end
