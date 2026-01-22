---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Target Cast Bar", "Orbit_TargetCastBar", {
    defaults = Mixin(Orbit.CastBarMixin.sharedDefaults, {
        InterruptibleColor = { r = 1, g = 0.7, b = 0 },
        NonInterruptibleColor = { r = 0.7, g = 0.7, b = 0.7 },
        InterruptedColor = { r = 1, g = 0, b = 0 },
    }),
}, Orbit.Constants.PluginGroups.UnitFrames)

-- Apply CastBarMixin
Mixin(Plugin, Orbit.CastBarMixin)

-- Override preview text
Plugin.previewText = "Target Cast"

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    if not self.CastBar then
        return
    end

    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic

    -- Build base schema (height/width with anchor detection)
    local schema = self:BuildBaseSchema(self.CastBar, systemIndex)

    -- NOTE: Colors and Text/Timer keys are now inherited from Player Cast Bar
    -- We removed them from here to avoid duplicate/conflicting settings.

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- Use mixin's GetInheritedSetting for settings inheritance from Player Cast Bar
function Plugin:GetSetting(systemIndex, key)
    return self:GetInheritedSetting(systemIndex, key)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create frame using mixin helper
    local CastBar = self:CreateCastBarFrame("OrbitTargetCastBar", {
        editModeName = "Target Cast Bar",
        yOffset = Orbit.Constants.PlayerCastBar.DefaultY,
    })

    -- Enable Merge Borders
    CastBar.anchorOptions = {
        horizontal = false,
        vertical = true,
        syncScale = true,
        syncDimensions = true,
        mergeBorders = true,
    }

    self.CastBar = CastBar
    self.Frame = CastBar

    -- Initialize skin using mixin helper
    self:InitializeSkin(CastBar)

    -- Restore position
    self:RestorePositionDebounced(CastBar, "TargetCastBar")

    -- Hook native spellbar using mixin helper
    local targetSpellbar = TargetFrame and TargetFrame.spellbar
    if targetSpellbar then
        self:SetupSpellbarHooks(targetSpellbar, "target")
    end

    -- Register Edit Mode callbacks using mixin helper
    self:RegisterEditModeCallbacks(CastBar, "TargetCastBar")

    -- Register world event using mixin helper
    self:RegisterWorldEvent(CastBar, "TargetCastBar")
end

-- [ APPLY SETTINGS ]--------------------------------------------------------------------------------
function Plugin:ApplySettings(systemFrame)
    local bar = self.CastBar
    if not bar then
        return
    end

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(bar) ~= nil

    -- Apply base settings using mixin helper
    self:ApplyBaseSettings(bar, 1, isAnchored)

    -- Restore Position (critical for profile switching)
    OrbitEngine.Frame:RestorePosition(bar, self, 1)
end
