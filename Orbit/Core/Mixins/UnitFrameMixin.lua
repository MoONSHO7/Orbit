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
        textSize = Orbit.Skin:GetAdaptiveTextSize(height, Orbit.Constants.UnitFrame.AdaptiveTextMin, Orbit.Constants.UnitFrame.AdaptiveTextMax, 0.3)
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
    local barCurve = globalSettings.BarColorCurve
    
    -- Check if curve has class pins
    if barCurve and barCurve.pins and #barCurve.pins > 0 then
        local hasClassPin = OrbitEngine.WidgetLogic and OrbitEngine.WidgetLogic:CurveHasClassPin(barCurve)
        
        if hasClassPin then
            -- Resolve class pin based on preview context
            local resolvedColor
            if isPlayer and className then
                local classColor = RAID_CLASS_COLORS[className]
                if classColor then resolvedColor = { r = classColor.r, g = classColor.g, b = classColor.b } end
            elseif reaction and OrbitEngine.WidgetLogic then
                resolvedColor = OrbitEngine.WidgetLogic:GetReactionColor(reaction)
            end
            if resolvedColor then return resolvedColor.r, resolvedColor.g, resolvedColor.b end
        end
    end
    
    -- No class pins or fallback - use first color from curve
    local barColor = (OrbitEngine.WidgetLogic and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(barCurve)) or { r = 0.2, g = 0.8, b = 0.2 }
    return barColor.r, barColor.g, barColor.b
end

function Mixin:GetPreviewTextColor(isPlayer, className, reaction)
    local globalSettings = Orbit.db.GlobalSettings or {}
    local fontCurve = globalSettings.FontColorCurve

    if fontCurve and fontCurve.pins and #fontCurve.pins > 0 then
        local hasClassPin = OrbitEngine.WidgetLogic and OrbitEngine.WidgetLogic:CurveHasClassPin(fontCurve)
        if hasClassPin then
            local resolvedColor
            if isPlayer and className then
                local classColor = RAID_CLASS_COLORS[className]
                if classColor then resolvedColor = { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
            elseif reaction and OrbitEngine.WidgetLogic then
                resolvedColor = OrbitEngine.WidgetLogic:GetReactionColor(reaction)
            end
            if resolvedColor then return resolvedColor.r, resolvedColor.g, resolvedColor.b, resolvedColor.a or 1 end
        end
    end

    local fontColor = (OrbitEngine.WidgetLogic and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(fontCurve)) or { r = 1, g = 1, b = 1, a = 1 }
    return fontColor.r, fontColor.g, fontColor.b, fontColor.a or 1
end

function Mixin:ApplyPreviewBackdrop(frame)
    if not frame then return end
    self:CreateBackground(frame)
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(frame, globalSettings.UnitFrameBackdropColourCurve, { r = 0.08, g = 0.08, b = 0.08, a = 0.5 })
end

function Mixin:UpdateBackdropColor(frame, systemIndex, inheritFromPlayer)
    if not frame then return end
    self:CreateBackground(frame)
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(frame, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)
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

    local Pixel = OrbitEngine.Pixel
    local scale = frame:GetEffectiveScale()
    local powerBarRatio = options.powerBarRatio or DEFAULT_POWER_BAR_RATIO
    local powerHeight = showPowerBar and Pixel:Snap(height * powerBarRatio, scale) or 0
    local inset = Pixel:BorderInset(frame, borderSize or 0)

    local iL, iT, iR, iB = inset, inset, inset, inset
    if frame._barInsets then
        iL = frame._barInsets.x1
        iT = frame._barInsets.y1
        iR = frame._barInsets.x2
        iB = frame._barInsets.y2
    end

    if frame.Power then
        if showPowerBar then
            frame.Power:ClearAllPoints()
            frame.Power:SetPoint("BOTTOMLEFT", iL, iB)
            frame.Power:SetPoint("BOTTOMRIGHT", -iR, iB)
            frame.Power:SetHeight(powerHeight)
            frame.Power:SetFrameLevel(frame:GetFrameLevel() + 3)
            frame.Power:Show()
        else
            frame.Power:Hide()
        end
    end

    if frame.Health then
        frame.Health:ClearAllPoints()
        frame.Health:SetPoint("TOPLEFT", iL, -iT)
        if showPowerBar then
            frame.Health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -iR, powerHeight + iB)
        else
            frame.Health:SetPoint("BOTTOMRIGHT", -iR, iB)
        end
        frame.Health:SetFrameLevel(frame:GetFrameLevel() + 2)
        if frame.HealthDamageBar then
            frame.HealthDamageBar:ClearAllPoints()
            frame.HealthDamageBar:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", 0, 0)
            frame.HealthDamageBar:SetPoint("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
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
        local anchor = Orbit.Engine.FrameAnchor and Orbit.Engine.FrameAnchor.anchors[frame]
        local isHorizontalAnchor = anchor and (anchor.edge == "LEFT" or anchor.edge == "RIGHT")
        local opts = isHorizontalAnchor and frame.anchorOptions
        if isHorizontalAnchor and not (opts and opts.independentHeight) then
            frame:SetWidth(width)
        else
            frame:SetSize(width, height)
        end
    end)
end

-- [ VISIBILITY CONTAINER ]
function Mixin:CreateVisibilityContainer(parent, combatEssential)
    local container = CreateFrame("Frame", nil, parent or UIParent, "SecureHandlerStateTemplate")
    container:SetAllPoints()
    local baseDriver = "[petbattle] hide; show"
    local driver = Orbit.MountedVisibility and Orbit.MountedVisibility:GetMountedDriver(baseDriver, combatEssential) or baseDriver
    RegisterStateDriver(container, "visibility", driver)
    container.orbitBaseDriver = baseDriver
    container.orbitCombatEssential = combatEssential
    return container
end

function Mixin:UpdateVisibilityDriver()
    if not self.container or not self.container.orbitBaseDriver or InCombatLockdown() then return end
    local base = self.container.orbitBaseDriver
    local skipMountedDriver = Orbit:IsEditMode() or self.mountedHoverReveal
    local driver = (skipMountedDriver and base) or (Orbit.MountedVisibility and Orbit.MountedVisibility:GetMountedDriver(base, self.container.orbitCombatEssential) or base)
    RegisterStateDriver(self.container, "visibility", driver)
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
