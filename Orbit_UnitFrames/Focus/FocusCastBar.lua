---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Focus Cast Bar", "Orbit_FocusCastBar", {
    defaults = Mixin(Orbit.CastBarMixin.sharedDefaults, {
        CastBarColor = { r = 1, g = 0.7, b = 0, a = 1 },
        NonInterruptibleColor = { r = 0.7, g = 0.7, b = 0.7 },
        InterruptedColor = { r = 1, g = 0, b = 0 },
    }),
}, Orbit.Constants.PluginGroups.UnitFrames)

-- Apply CastBarMixin
Mixin(Plugin, Orbit.CastBarMixin)

-- Override preview text
Plugin.previewText = "Focus Cast"

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    if not self.CastBar then
        return
    end

    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic

    -- Build base schema (height/width with anchor detection)
    local schema = self:BuildBaseSchema(self.CastBar, systemIndex)

    -- Cast Bar Color (static - no dynamic curve due to secret values)
    WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
        key = "CastBarColor",
        label = "Cast Bar Colour",
        default = { r = 1, g = 0.7, b = 0, a = 1 },
    })

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- Override GetSetting to use own CastBarColor instead of inheriting from Player
function Plugin:GetSetting(systemIndex, key)
    if key == "CastBarColor" or key == "CastBarColorCurve" then
        local color = Orbit.PluginMixin.GetSetting(self, systemIndex, "CastBarColor")
        if key == "CastBarColorCurve" and color then
            return { pins = { { position = 0, color = color } } }
        end
        return color
    end
    return self:GetInheritedSetting(systemIndex, key)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create frame using mixin helper
    local CastBar = self:CreateCastBarFrame("OrbitFocusCastBar", {
        editModeName = "Focus Cast Bar",
        yOffset = (Orbit.Constants.PlayerCastBar.DefaultY or -150) + 50,
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
    self:RestorePositionDebounced(CastBar, "FocusCastBar")

    -- Hook native spellbar using mixin helper
    local focusSpellbar = FocusFrame and FocusFrame.spellbar
    if not focusSpellbar and FocusFrameSpellBar then
        focusSpellbar = FocusFrameSpellBar
    end

    if focusSpellbar then
        self:SetupSpellbarHooks(focusSpellbar, "focus")
    end

    -- Register Edit Mode callbacks using mixin helper
    self:RegisterEditModeCallbacks(CastBar, "FocusCastBar")

    -- Register world event using mixin helper
    self:RegisterWorldEvent(CastBar, "FocusCastBar")
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
