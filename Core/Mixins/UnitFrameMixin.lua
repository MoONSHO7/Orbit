-- [ ORBIT UNIT FRAME MIXIN ]------------------------------------------------------------------------
-- Shared functionality for unit frame plugins (Player, Target, Focus, Pet)
-- Consolidates common visual setup, text styling, and settings inheritance

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

---@class OrbitUnitFrameMixin
Orbit.UnitFrameMixin = {}
local Mixin = Orbit.UnitFrameMixin

-- [ PLAYER SETTINGS INHERITANCE ]-------------------------------------------------------------------

-- Get a reference to the PlayerFrame plugin
function Mixin:GetPlayerFramePlugin()
    return Orbit:GetPlugin("Orbit_PlayerFrame")
end

-- Inherit a setting from PlayerFrame (for Target/Focus/Pet consistency)
function Mixin:GetPlayerSetting(key)
    local playerPlugin = self:GetPlayerFramePlugin()
    local playerIndex = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Player) or 1
    if playerPlugin and playerPlugin.GetSetting then
        return playerPlugin:GetSetting(playerIndex, key)
    end
    return nil
end

-- [ NATIVE FRAME HIDING ]----------------------------------------------------------------------------

-- Hide a native Blizzard unit frame (Target/Focus/Pet) by parenting to a hidden container
-- This is a DRY helper to consolidate the repeated pattern across unit frame plugins
function Mixin:HideNativeUnitFrame(nativeFrame, hiddenParentName)
    local hiddenParent = CreateFrame("Frame", hiddenParentName, UIParent)
    hiddenParent:Hide()

    if nativeFrame then
        nativeFrame:SetParent(hiddenParent)
        nativeFrame:UnregisterAllEvents()
        nativeFrame:ClearAllPoints()
        nativeFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
        nativeFrame:SetAlpha(0)
        nativeFrame:SetScale(0.001)
        nativeFrame:EnableMouse(false)
    end

    return hiddenParent
end

-- [ BACKGROUND CREATION ]---------------------------------------------------------------------------

function Mixin:CreateBackground(frame)
    if not frame then
        return
    end
    if frame.bg then
        return frame.bg
    end

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()

    local colors = Orbit.Constants.Colors.Background
    frame.bg:SetColorTexture(colors.r, colors.g, colors.b, colors.a)

    return frame.bg
end

-- [ TEXTURE APPLICATION ]---------------------------------------------------------------------------

function Mixin:ApplyTexture(frame, textureName)
    if not frame or not frame.Health then
        return
    end

    local texturePath = LSM:Fetch("statusbar", textureName)
    frame.Health:SetStatusBarTexture(texturePath)

    -- Ensure background exists
    self:CreateBackground(frame)
end

-- [ TEXT STYLING ]----------------------------------------------------------------------------------

function Mixin:ApplyTextStyling(frame, textSize)
    if not frame then
        return
    end

    -- Calculate adaptive text size if not provided (respects global TextScale setting)
    if not textSize or textSize <= 0 then
        local height = frame:GetHeight() or 40
        textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 24, 0.25)
    end

    -- Apply standard unit frame text styling with calculated text size
    Orbit.Skin:ApplyUnitFrameText(frame.Name, "LEFT", nil, textSize)
    Orbit.Skin:ApplyUnitFrameText(frame.HealthText, "RIGHT", nil, textSize)

    -- Ensure health text is properly layered
    if frame.HealthText then
        frame.HealthText:SetDrawLayer("OVERLAY", 7)
        frame.HealthText:SetAlpha(1)
        frame.HealthText:SetTextColor(1, 1, 1, 1)
    end
end

-- [ BACKDROP COLOR APPLICATION ]---------------------------------------------------------------------

function Mixin:UpdateBackdropColor(frame, systemIndex)
    if not frame then
        return
    end

    -- Ensure background exists
    local bg = self:CreateBackground(frame)
    if not bg then
        return
    end

    -- Get color from settings (inherits global due to PluginMixin update)
    local color = self:GetSetting(systemIndex, "BackdropColour")

    if color then
        -- Handle both table format {r,g,b,a} and potentially Hex string if that ever changes
        if type(color) == "table" then
            bg:SetColorTexture(color.r or 0, color.g or 0, color.b or 0, color.a or 0.5)
        end
    else
        -- Fallback to constant defaults
        local c = Orbit.Constants.Colors.Background
        bg:SetColorTexture(c.r, c.g, c.b, c.a)
    end
end

-- [ BASE VISUALS APPLICATION ]----------------------------------------------------------------------

function Mixin:ApplyBaseVisuals(frame, systemIndex, options)
    if not frame then
        return
    end
    options = options or {}

    -- Determine settings source
    local borderSize, textureName, healthTextEnabled

    if options.inheritFromPlayer then
        -- Target/Focus/Pet inherit from PlayerFrame
        borderSize = self:GetPlayerSetting("BorderSize")
        textureName = self:GetPlayerSetting("Texture")
        healthTextEnabled = self:GetPlayerSetting("HealthTextEnabled")
        if healthTextEnabled == nil then
            healthTextEnabled = true
        end

        -- Backdrop Colour is ALWAYS global (enforced in PluginMixin),
        -- but access via PlayerFrame ensures inheritance logic flows if we ever localise it.
        -- For now, calling UpdateBackdropColor uses simple GetSetting which handles global fallback.
    else
        -- PlayerFrame uses its own settings
        borderSize = self:GetSetting(systemIndex, "BorderSize")
        textureName = self:GetSetting(systemIndex, "Texture")
        healthTextEnabled = self:GetSetting(systemIndex, "HealthTextEnabled")
    end

    -- Calculate adaptive text size based on frame height (respects global TextScale setting)
    local height = frame:GetHeight() or 40
    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 24, 0.25)

    -- Apply texture
    self:ApplyTexture(frame, textureName)

    -- Apply Backrop Colour
    self:UpdateBackdropColor(frame, systemIndex)

    -- Apply border
    if frame.SetBorder then
        frame:SetBorder(borderSize)
    end

    -- Apply text styling
    self:ApplyTextStyling(frame, textSize)

    -- Apply health text visibility
    if frame.SetHealthTextEnabled then
        frame:SetHealthTextEnabled(healthTextEnabled)
    end

    -- Apply absorbs (if available)
    if frame.SetAbsorbsEnabled then
        frame:SetAbsorbsEnabled(true)
        frame:SetHealAbsorbsEnabled(true)
    end
end

-- [ COMBAT-SAFE SIZE APPLICATION ]------------------------------------------------------------------

function Mixin:ApplySize(frame, width, height)
    if not frame then
        return
    end

    Orbit:SafeAction(function()
        frame:SetSize(width, height)
    end)
end

-- [ VISIBILITY CONTAINER ]--------------------------------------------------------------------------

function Mixin:CreateVisibilityContainer(parent)
    local container = CreateFrame("Frame", nil, parent or UIParent, "SecureHandlerStateTemplate")
    container:SetAllPoints() -- Fill parent (usually UIParent) so children anchor relative to screen

    -- Standard driver for Pet Battle (hides frames)
    -- Note: Removed [vehicleui] so UnitFrames remain visible in vehicles (Player/Target/Focus)
    RegisterStateDriver(container, "visibility", "[petbattle] hide; show")

    return container
end

-- [ STANDARD RESTORE POSITION ]---------------------------------------------------------------------

function Mixin:RestoreFramePosition(frame, systemIndex)
    if not frame then
        return
    end
    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)
end

-- [ COMPLETE APPLY SETTINGS HELPER ]----------------------------------------------------------------

function Mixin:ApplyUnitFrameSettings(frame, systemIndex, options)
    if not frame then
        return
    end
    options = options or {}

    -- Get size settings
    local width = options.width or self:GetSetting(systemIndex, "Width")
    local height = options.height or self:GetSetting(systemIndex, "Height")

    if options.inheritFromPlayer then
        width = width or self:GetPlayerSetting("Width")
        height = height or self:GetPlayerSetting("Height")
    end

    width = width or 200
    height = height or 40

    -- Apply size (combat-safe)
    self:ApplySize(frame, width, height)

    -- Apply visuals
    self:ApplyBaseVisuals(frame, systemIndex, options)

    -- Update frame if it has UpdateAll
    if frame.UpdateAll then
        frame:UpdateAll()
    end

    -- Restore position
    self:RestoreFramePosition(frame, systemIndex)
end
