-- [ ORBIT UNIT FRAME MIXIN ]------------------------------------------------------------------------
-- Shared functionality for unit frame plugins (Player, Target, Focus, Pet)

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

---@class OrbitUnitFrameMixin
Orbit.UnitFrameMixin = {}
local Mixin = Orbit.UnitFrameMixin

-- [ PLAYER SETTINGS INHERITANCE ]
function Mixin:GetPlayerFramePlugin()
    return Orbit:GetPlugin("Orbit_PlayerFrame")
end

function Mixin:GetPlayerSetting(key)
    local playerPlugin = self:GetPlayerFramePlugin()
    local playerIndex = Enum.EditModeUnitFrameSystemIndices.Player
    if playerPlugin and playerPlugin.GetSetting then
        return playerPlugin:GetSetting(playerIndex, key)
    end
    return nil
end

function Mixin:GetInheritedSetting(systemIndex, key, inheritFromPlayer)
    if inheritFromPlayer then
        return self:GetPlayerSetting(key)
    end
    return self:GetSetting(systemIndex, key)
end

-- [ NATIVE FRAME HIDING ]
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

-- [ BACKGROUND CREATION ]
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

-- [ TEXTURE APPLICATION ]
function Mixin:ApplyTexture(frame, textureName)
    if not frame or not frame.Health then
        return
    end
    Orbit.Skin:SkinStatusBar(frame.Health, textureName, nil, true)
    self:CreateBackground(frame)
end

-- [ TEXT STYLING ]
function Mixin:ApplyTextStyling(frame, textSize)
    if not frame then
        return
    end
    if not textSize or textSize <= 0 then
        local height = frame:GetHeight() or 40
        textSize = Orbit.Skin:GetAdaptiveTextSize(height, 14, 24, 0.3)
    end
    Orbit.Skin:ApplyUnitFrameText(frame.Name, "LEFT", nil, textSize)
    Orbit.Skin:ApplyUnitFrameText(frame.HealthText, "RIGHT", nil, textSize)
    if frame.HealthText then
        frame.HealthText:SetDrawLayer("OVERLAY", 7)
        frame.HealthText:SetAlpha(1)
        frame.HealthText:SetTextColor(1, 1, 1, 1)
    end
end

-- [ PREVIEW COLOR HELPERS ]

function Mixin:GetPreviewHealthColor(isPlayer, className, reaction)
    local globalSettings = Orbit.db.GlobalSettings or {}
    local useClassColors = globalSettings.UseClassColors ~= false -- Default true

    if useClassColors then
        if isPlayer and className then
            local classColor = C_ClassColor.GetClassColor(className)
            if classColor then
                return classColor.r, classColor.g, classColor.b
            end
        else
            -- NPC/Boss - use reaction color (hostile = red)
            if reaction and reaction >= 4 then
                return 0.2, 0.8, 0.2 -- Friendly green
            else
                return 1, 0.1, 0.1 -- Hostile red
            end
        end
    end

    -- Fall back to global bar color
    local barColor = globalSettings.BarColor or { r = 0.2, g = 0.8, b = 0.2 }
    return barColor.r, barColor.g, barColor.b
end

function Mixin:GetPreviewTextColor(isPlayer, className, reaction)
    local globalSettings = Orbit.db.GlobalSettings or {}
    local useClassColorFont = globalSettings.UseClassColorFont ~= false -- Default true

    if useClassColorFont then
        if isPlayer and className then
            local classColor = C_ClassColor.GetClassColor(className)
            if classColor then
                return classColor.r, classColor.g, classColor.b, 1
            end
        else
            -- NPC/Boss - use reaction color
            if reaction and reaction >= 4 then
                return 0.2, 0.8, 0.2, 1 -- Friendly green
            else
                return 1, 0.1, 0.1, 1 -- Hostile red
            end
        end
        -- Fallback to white
        return 1, 1, 1, 1
    end

    local fontColor = globalSettings.FontColor or { r = 1, g = 1, b = 1, a = 1 }
    return fontColor.r, fontColor.g, fontColor.b, fontColor.a or 1
end

function Mixin:ApplyPreviewBackdrop(frame)
    if not frame or not frame.bg then
        return
    end

    local globalSettings = Orbit.db.GlobalSettings or {}
    local classColorBackdrop = globalSettings.ClassColorBackground or false
    local backdropColor = globalSettings.BackdropColour or { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }

    if classColorBackdrop then
        local _, playerClass = UnitClass("player")
        if playerClass then
            local classColor = C_ClassColor.GetClassColor(playerClass)
            if classColor then
                frame.bg:SetColorTexture(classColor.r, classColor.g, classColor.b, 1)
                return
            end
        end
    end

    frame.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a or 0.5)
end

function Mixin:UpdateBackdropColor(frame, systemIndex, inheritFromPlayer)
    if not frame then
        return
    end
    local bg = self:CreateBackground(frame)
    if not bg then
        return
    end

    -- Check global ClassColorBackground setting first
    -- When enabled, use player's class color with full opacity for unit frame backdrops
    local useClassColorBg = Orbit.db.GlobalSettings.ClassColorBackground
    if useClassColorBg then
        local _, class = UnitClass("player")
        if class then
            local classColor = C_ClassColor.GetClassColor(class)
            if classColor then
                bg:SetColorTexture(classColor.r, classColor.g, classColor.b, 1) -- 100% opacity
                return
            end
        end
    end

    local color = self:GetInheritedSetting(systemIndex, "BackdropColour", inheritFromPlayer)
    if color and type(color) == "table" then
        bg:SetColorTexture(color.r or 0, color.g or 0, color.b or 0, color.a or 0.5)
    else
        local c = Orbit.Constants.Colors.Background
        bg:SetColorTexture(c.r, c.g, c.b, c.a)
    end
end

-- [ BASE VISUALS APPLICATION ]
function Mixin:ApplyBaseVisuals(frame, systemIndex, options)
    if not frame then
        return
    end
    options = options or {}

    local borderSize = Orbit.db.GlobalSettings.BorderSize
    local textureName = self:GetInheritedSetting(systemIndex, "Texture", options.inheritFromPlayer)
    local healthTextMode = self:GetInheritedSetting(systemIndex, "HealthTextMode", options.inheritFromPlayer) or "percent_short"

    -- Apply texture
    self:ApplyTexture(frame, textureName)

    -- Apply Backrop Colour
    self:UpdateBackdropColor(frame, systemIndex, options.inheritFromPlayer)

    -- Apply border
    if frame.SetBorder then
        frame:SetBorder(borderSize)
    end

    -- Apply text styling
    self:ApplyTextStyling(frame)

    -- Apply health text mode (replaces simple enabled boolean)
    if frame.SetHealthTextMode then
        frame:SetHealthTextMode(healthTextMode)
    end

    -- Apply absorbs (if available)
    if frame.SetAbsorbsEnabled then
        frame:SetAbsorbsEnabled(true)
        frame:SetHealAbsorbsEnabled(true)
    end
end

-- [ FRAME LAYOUT ]
local DEFAULT_POWER_BAR_RATIO = 0.2

function Mixin:UpdateFrameLayout(frame, borderSize, options)
    if not frame then
        return
    end
    local height = frame:GetHeight()
    if height < 1 then
        return
    end
    options = options or {}
    local showPowerBar = (options.showPowerBar == nil) and true or options.showPowerBar

    local powerBarRatio = options.powerBarRatio or DEFAULT_POWER_BAR_RATIO
    local powerHeight = showPowerBar and (height * powerBarRatio) or 0
    local inset = frame.borderPixelSize or borderSize or 0

    if frame.Power then
        if showPowerBar then
            frame.Power:ClearAllPoints()
            frame.Power:SetPoint("BOTTOMLEFT", inset, inset)
            frame.Power:SetPoint("BOTTOMRIGHT", -inset, inset)
            frame.Power:SetHeight(powerHeight)
            frame.Power:SetFrameLevel(frame:GetFrameLevel() + 3)
            frame.Power:Show()
        else
            frame.Power:Hide()
        end
    end

    if frame.Health then
        frame.Health:ClearAllPoints()
        frame.Health:SetPoint("TOPLEFT", inset, -inset)
        if showPowerBar then
            frame.Health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, powerHeight + inset)
        else
            frame.Health:SetPoint("BOTTOMRIGHT", -inset, inset)
        end
        frame.Health:SetFrameLevel(frame:GetFrameLevel() + 2)
        if frame.HealthDamageBar then
            frame.HealthDamageBar:ClearAllPoints()
            frame.HealthDamageBar:SetAllPoints(frame.Health)
            frame.HealthDamageBar:SetFrameLevel(frame:GetFrameLevel() + 1)
        end
    end
end

-- [ COMBAT-SAFE SIZE APPLICATION ]
function Mixin:ApplySize(frame, width, height)
    if not frame then
        return
    end
    Orbit:SafeAction(function()
        frame:SetSize(width, height)
    end)
end

-- [ VISIBILITY CONTAINER ]
function Mixin:CreateVisibilityContainer(parent)
    local container = CreateFrame("Frame", nil, parent or UIParent, "SecureHandlerStateTemplate")
    container:SetAllPoints()
    RegisterStateDriver(container, "visibility", "[petbattle] hide; show")
    return container
end

-- [ STANDARD RESTORE POSITION ]
function Mixin:RestoreFramePosition(frame, systemIndex)
    if not frame then
        return
    end
    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)
end

-- [ COMPLETE APPLY SETTINGS HELPER ]
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
