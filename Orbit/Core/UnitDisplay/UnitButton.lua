-- [ UNIT BUTTON ]------------------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local Constants = Orbit.Constants
local L = Orbit.L

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SMOOTH_ANIM = Enum.StatusBarInterpolation.ExponentialEaseOut
local DAMAGE_BAR_DELAY = 0.2
local DAMAGE_COLOR = { r = 0.8, g = 0.1, b = 0.1, a = 0.6 }
local MY_HEAL_COLOR = { r = 0.66, g = 1, b = 0.66, a = 0.6 }
local OTHER_HEAL_COLOR = { r = 0.66, g = 1, b = 0.66, a = 0.6 }
local ABSORB_COLOR = Constants.Colors.Absorb
local HEAL_ABSORB_ALPHA = 0.15
local HEAL_ABSORB_PATTERN_SIZE = 3200
local HEAL_ABSORB_TEXCOORD = 100

-- Stretched statusbar fill would shear the diagonal stripes — draw as a clip-masked horizTile/vertTile instead; PATTERN_SIZE is the oversized square the mask crops, TILE_W/H are native dims for texcoords.
local ABSORB_PATTERN_SIZE = 3200
local ABSORB_TILE_W = 256
local ABSORB_TILE_H = 64

local TEXT_INSET = 5
local SHADOW_OFFSET_X = 1
local SHADOW_OFFSET_Y = -1
local NECROTIC_PATH = "Interface\\AddOns\\Orbit\\Core\\Assets\\Statusbar\\necrotic.tga"
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"

-- [ COMPOSE MIXIN ]----------------------------------------------------------------------------------
local UnitButtonMixin = {}

if UnitButton.CoreMixin then Mixin(UnitButtonMixin, UnitButton.CoreMixin) end
if UnitButton.HealthMixin then Mixin(UnitButtonMixin, UnitButton.HealthMixin) end
if UnitButton.TextMixin then Mixin(UnitButtonMixin, UnitButton.TextMixin) end
if UnitButton.PredictionMixin then Mixin(UnitButtonMixin, UnitButton.PredictionMixin) end
if UnitButton.CanvasMixin then Mixin(UnitButtonMixin, UnitButton.CanvasMixin) end
if UnitButton.PortraitMixin then Mixin(UnitButtonMixin, UnitButton.PortraitMixin) end

UnitButton.Mixin = UnitButtonMixin
table.freeze(UnitButtonMixin)

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function CreatePredictionBar(parent, healthBar, color)
    local bar = CreateFrame("StatusBar", nil, healthBar)
    bar:SetStatusBarTexture(WHITE_TEXTURE)
    bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetFrameLevel(healthBar:GetFrameLevel())
    bar:Hide()
    return bar
end

local function AttachComponentDrag(f, component, key)
    if not Engine.ComponentDrag then return end
    Engine.ComponentDrag:Attach(component, f, {
        key = key,
        onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY, justifyH, justifyV)
            if f.orbitPlugin and f.orbitPlugin.SetSetting then
                local systemIndex = f.systemIndex or 1
                local positions = f.orbitPlugin:GetSetting(systemIndex, "ComponentPositions") or {}
                positions[key] = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH, justifyV = justifyV }
                f.orbitPlugin:SetSetting(systemIndex, "ComponentPositions", positions)
            end
        end,
    })
end

-- [ FACTORY ]----------------------------------------------------------------------------------------
function UnitButton:Create(parent, unit, name, skipEventRegistration)
    local f = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate,BackdropTemplate")
    if Engine.Pixel then Engine.Pixel:Enforce(f) end
    f:SetClampedToScreen(true)
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:SetAttribute("ping-receiver", true)
    Mixin(f, PingableType_UnitFrameMixin)
    f.unit = unit

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    local bg = Orbit.Constants.Colors.Background
    f.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    Orbit.Skin:RegisterMaskedSurface(f, f.bg)

    f.HealthDamageBar = CreateFrame("StatusBar", nil, f)
    f.HealthDamageBar:SetPoint("TOPLEFT", 0, 0)
    f.HealthDamageBar:SetPoint("BOTTOMRIGHT", 0, 0)
    f.HealthDamageBar:SetMinMaxValues(0, 1)
    f.HealthDamageBar:SetValue(1)
    f.HealthDamageBar:SetStatusBarTexture(WHITE_TEXTURE)
    f.HealthDamageBar:SetStatusBarColor(0, 0, 0, 0)
    f.HealthDamageBar:SetFrameLevel(f:GetFrameLevel() + Constants.Levels.StatusBar)
    Orbit.Skin:RegisterMaskedSurface(f, f.HealthDamageBar:GetStatusBarTexture())

    f.Health = CreateFrame("StatusBar", nil, f)
    f.Health:SetPoint("TOPLEFT", 0, 0)
    f.Health:SetPoint("BOTTOMRIGHT", 0, 0)
    f.Health:SetMinMaxValues(0, 1)
    f.Health:SetValue(1)
    f.Health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    f.Health:SetStatusBarColor(0, 1, 0)
    f.Health:SetClipsChildren(true)
    f.Health:SetFrameLevel(f:GetFrameLevel() + Constants.Levels.StatusBar)
    Orbit.Skin:RegisterMaskedSurface(f, f.Health:GetStatusBarTexture())

    f.HealthDamageTexture = f.Health:CreateTexture(nil, "BACKGROUND")
    f.HealthDamageTexture:SetColorTexture(DAMAGE_COLOR.r, DAMAGE_COLOR.g, DAMAGE_COLOR.b, DAMAGE_COLOR.a)
    f.HealthDamageTexture:SetPoint("TOPLEFT", f.Health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    f.HealthDamageTexture:SetPoint("BOTTOMLEFT", f.Health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    f.HealthDamageTexture:SetPoint("TOPRIGHT", f.HealthDamageBar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    f.HealthDamageTexture:SetPoint("BOTTOMRIGHT", f.HealthDamageBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    Orbit.Skin:RegisterMaskedSurface(f, f.HealthDamageTexture)

    -- Pre-create the (hidden) overlay so it inherits the rounded mask; SkinStatusBar fills or hides per OverlayTexture.
    Orbit.Skin:AddOverlay(f.Health)
    if f.Health.Overlay then Orbit.Skin:RegisterMaskedSurface(f, f.Health.Overlay) end

    f.MyIncomingHealBar = CreatePredictionBar(f, f.Health, MY_HEAL_COLOR)
    f.OtherIncomingHealBar = CreatePredictionBar(f, f.Health, OTHER_HEAL_COLOR)
    Orbit.Skin:RegisterMaskedSurface(f, f.MyIncomingHealBar:GetStatusBarTexture())
    Orbit.Skin:RegisterMaskedSurface(f, f.OtherIncomingHealBar:GetStatusBarTexture())

    f.TotalAbsorbBar = CreateFrame("StatusBar", nil, f.Health)
    -- Placeholder so GetStatusBarTexture() is valid for the mask anchors below; ApplyAbsorbTexture sets the real fill at the end.
    f.TotalAbsorbBar:SetStatusBarTexture(WHITE_TEXTURE)
    f.TotalAbsorbBar:SetStatusBarColor(ABSORB_COLOR.r, ABSORB_COLOR.g, ABSORB_COLOR.b, ABSORB_COLOR.a)
    f.TotalAbsorbBar:SetMinMaxValues(0, 1)
    f.TotalAbsorbBar:SetValue(0)
    f.TotalAbsorbBar:SetFrameLevel(f.Health:GetFrameLevel() + 1)
    f.TotalAbsorbBar:Hide()
    Orbit.Skin:RegisterMaskedSurface(f, f.TotalAbsorbBar:GetStatusBarTexture())

    -- MOD-blended tiled pattern, clipped to the fill by TotalAbsorbMask; Skin:ApplyAbsorbTexture toggles it per tiling/stretched fill.
    f.TotalAbsorbMask = CreateFrame("Frame", nil, f.TotalAbsorbBar)
    f.TotalAbsorbMask:SetClipsChildren(true)
    f.TotalAbsorbMask:SetFrameLevel(f.TotalAbsorbBar:GetFrameLevel() + Constants.Levels.StatusBar)
    f.TotalAbsorbMask:SetPoint("TOPLEFT", f.TotalAbsorbBar:GetStatusBarTexture(), "TOPLEFT", 0, 0)
    f.TotalAbsorbMask:SetPoint("BOTTOMRIGHT", f.TotalAbsorbBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)

    f.TotalAbsorbPattern = f.TotalAbsorbMask:CreateTexture(nil, "ARTWORK")
    f.TotalAbsorbPattern:SetSize(ABSORB_PATTERN_SIZE, ABSORB_PATTERN_SIZE)
    f.TotalAbsorbPattern:SetPoint("TOPLEFT", f.TotalAbsorbMask, "TOPLEFT", 0, 0)
    f.TotalAbsorbPattern:SetTexture(LSM:Fetch("statusbar", "Orbit Absorb"), "REPEAT", "REPEAT")
    -- UV-repeat tiling (TexCoord > 1 over a REPEAT-wrapped texture), NOT SetHorizTile: identical constant
    -- tile scale, but maskable — so the pattern rounds under a rounded border style instead of bleeding.
    f.TotalAbsorbPattern:SetTexCoord(0, ABSORB_PATTERN_SIZE / ABSORB_TILE_W, 0, ABSORB_PATTERN_SIZE / ABSORB_TILE_H)
    f.TotalAbsorbPattern:SetBlendMode("MOD")
    -- Stamp tileCoord so ApplyAbsorbTexture re-asserts them after texture swap (all tiling fills share 256x64).
    f.TotalAbsorbPattern.tileCoordX = ABSORB_PATTERN_SIZE / ABSORB_TILE_W
    f.TotalAbsorbPattern.tileCoordY = ABSORB_PATTERN_SIZE / ABSORB_TILE_H
    f.TotalAbsorbBar.TiledPattern = f.TotalAbsorbPattern
    Orbit.Skin:RegisterMaskedSurface(f, f.TotalAbsorbPattern)

    hooksecurefunc(f.TotalAbsorbBar, "Show", function() f.TotalAbsorbMask:Show() end)
    hooksecurefunc(f.TotalAbsorbBar, "Hide", function() f.TotalAbsorbMask:Hide() end)

    local absorbTextureName = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.AbsorbTexture
    Orbit.Skin:ApplyAbsorbTexture(f.TotalAbsorbBar, absorbTextureName)

    f.HealAbsorbBar = CreateFrame("StatusBar", nil, f.Health)
    f.HealAbsorbBar:SetReverseFill(true)

    local healthTexture = f.Health:GetStatusBarTexture():GetTexture()
    f.HealAbsorbBar:SetStatusBarTexture(healthTexture or WHITE_TEXTURE)
    local c = Orbit.Constants.Colors.Background
    f.HealAbsorbBar:SetStatusBarColor(c.r, c.g, c.b, c.a)
    f.HealAbsorbBar:SetMinMaxValues(0, 1)
    f.HealAbsorbBar:SetValue(0)
    f.HealAbsorbBar:SetFrameLevel(f.Health:GetFrameLevel() + Constants.Levels.StatusBar)
    f.HealAbsorbBar:Hide()
    Orbit.Skin:RegisterMaskedSurface(f, f.HealAbsorbBar:GetStatusBarTexture())

    f.HealAbsorbMask = CreateFrame("Frame", nil, f.HealAbsorbBar)
    f.HealAbsorbMask:SetClipsChildren(true)
    f.HealAbsorbMask:SetFrameLevel(f.HealAbsorbBar:GetFrameLevel() + Constants.Levels.StatusBar)
    f.HealAbsorbMask:SetPoint("TOPLEFT", f.HealAbsorbBar:GetStatusBarTexture(), "TOPLEFT", 0, 0)
    f.HealAbsorbMask:SetPoint("BOTTOMRIGHT", f.HealAbsorbBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)

    f.HealAbsorbPattern = f.HealAbsorbMask:CreateTexture(nil, "ARTWORK")
    f.HealAbsorbPattern:SetSize(HEAL_ABSORB_PATTERN_SIZE, HEAL_ABSORB_PATTERN_SIZE)
    f.HealAbsorbPattern:SetPoint("TOPLEFT", f.HealAbsorbMask, "TOPLEFT", 0, 0)
    f.HealAbsorbPattern:SetTexture(NECROTIC_PATH, "REPEAT", "REPEAT")
    f.HealAbsorbPattern:SetTexCoord(0, HEAL_ABSORB_TEXCOORD, 0, HEAL_ABSORB_TEXCOORD)
    f.HealAbsorbPattern:SetBlendMode("BLEND")
    f.HealAbsorbPattern:SetAlpha(HEAL_ABSORB_ALPHA)
    Orbit.Skin:RegisterMaskedSurface(f, f.HealAbsorbPattern)

    hooksecurefunc(f.HealAbsorbBar, "Show", function() f.HealAbsorbMask:Show() end)
    hooksecurefunc(f.HealAbsorbBar, "Hide", function() f.HealAbsorbMask:Hide() end)

    f.TextFrame = CreateFrame("Frame", nil, f)
    f.TextFrame:SetAllPoints(f.Health)
    f.TextFrame:SetFrameLevel(f.Health:GetFrameLevel() + Constants.Levels.Overlay)

    f.NameFrame = CreateFrame("Frame", nil, f)
    f.NameFrame:SetAllPoints(f.Health)
    f.NameFrame:SetFrameLevel(f:GetFrameLevel() + Constants.Levels.Overlay)

    local fScale = f:GetEffectiveScale() or 1
    local textInset = Engine.Pixel:Multiple(TEXT_INSET, fScale)
    local shadowX = Engine.Pixel:Multiple(SHADOW_OFFSET_X, fScale)
    local shadowY = -Engine.Pixel:Multiple(math.abs(SHADOW_OFFSET_Y), fScale)

    f.Name = f.NameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Name:SetPoint("LEFT", f.TextFrame, "LEFT", textInset, 0)
    f.Name:SetJustifyH("LEFT")
    f.Name:SetShadowOffset(shadowX, shadowY)
    f.Name:SetShadowColor(0, 0, 0, 1)
    f.Name:SetWordWrap(false)
    f.Name:SetNonSpaceWrap(false)
    f.Name:SetText(L.CFG_CM_PREVIEW_NAME)

    f.HealthText = f.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.HealthText:SetPoint("RIGHT", -textInset, 0)
    f.HealthText:SetJustifyH("RIGHT")
    f.HealthText:SetShadowOffset(shadowX, shadowY)
    f.HealthText:SetShadowColor(0, 0, 0, 1)
    f.HealthText:SetText("100%")

    AttachComponentDrag(f, f.Name, "Name")
    AttachComponentDrag(f, f.HealthText, "HealthText")

    Mixin(f, UnitButtonMixin)
    f:SetScript("OnEvent", f.OnEvent)
    f:OnLoad(skipEventRegistration)

    local function OrbitUnitFrame_UpdateTooltip(frame)
        local unit = frame.unit
        if not unit or unit == "" or not UnitExists(unit) then
            frame.UpdateTooltip = nil
            return
        end
        GameTooltip_SetDefaultAnchor(GameTooltip, frame)
        if GameTooltip:SetUnit(unit) then
            GameTooltip:Show()
            frame.UpdateTooltip = OrbitUnitFrame_UpdateTooltip
        else
            frame.UpdateTooltip = nil
        end
    end

    f:SetScript("OnEnter", function(self)
        self:SetMouseOver(true)
        OrbitUnitFrame_UpdateTooltip(self)
    end)
    f:SetScript("OnLeave", function(self)
        self:SetMouseOver(false)
        self.UpdateTooltip = nil
        GameTooltip:FadeOut()
    end)

    f:HookScript("OnSizeChanged", function(self)
        self:UpdateTextLayout()
        self:ApplyComponentPositions()
    end)

    local function DamageBarOnUpdate(self, elapsed)
        if not self.HealthDamageBar then
            self:SetScript("OnUpdate", nil)
            return
        end
        if (GetTime() - (self.lastHealthUpdate or 0)) < DAMAGE_BAR_DELAY then return end
        self.HealthDamageBar:SetValue(self.Health:GetValue(), SMOOTH_ANIM)
        self:SetScript("OnUpdate", nil)
    end

    f.DamageBarOnUpdate = DamageBarOnUpdate

    if ClickCastFrames then ClickCastFrames[f] = true end
    RegisterUnitWatch(f)
    f:SetScript("OnShow", function(self) self:UpdateAll() end)

    return f
end
