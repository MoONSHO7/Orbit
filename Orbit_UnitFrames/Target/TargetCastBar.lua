---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Target Cast Bar", "Orbit_TargetCastBar", {
    defaults = Orbit.CastBarMixin.sharedDefaults,
}, Orbit.Constants.PluginGroups.UnitFrames)

Mixin(Plugin, Orbit.CastBarMixin)

Plugin.previewText = "Target Cast"

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    self:AddCastBarSettings(dialog, systemFrame)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    local CastBar = self:CreateCastBarFrame("OrbitTargetCastBar", {
        editModeName = "Target Cast Bar",
        yOffset = Orbit.Constants.PlayerCastBar.DefaultY,
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
    self:RestorePositionDebounced(CastBar, "TargetCastBar")

    -- Register cast events and pass native spellbar for BorderShield interrupt detection
    local nativeSpellbar = TargetFrame and TargetFrame.spellbar
    self:RegisterUnitCastEvents(CastBar, "target")
    self:SetupUnitCastBar(CastBar, "target", nativeSpellbar)
    self:SetupCastBarOnUpdate(CastBar)

    self:RegisterEditModeCallbacks(CastBar)
    self:RegisterWorldEvent(CastBar, "TargetCastBar")
end

-- [ APPLY SETTINGS ]--------------------------------------------------------------------------------
function Plugin:ApplySettings(systemFrame)
    local bar = self.CastBar
    if not bar then return end
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(bar) ~= nil
    self:ApplyBaseSettings(bar, 1, isAnchored)
    OrbitEngine.Frame:RestorePosition(bar, self, 1)
end
