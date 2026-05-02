---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_MinimapButton"

local Plugin = Orbit:RegisterPlugin("Minimap Button", SYSTEM_ID, {
    liveToggle = true,
    defaults = {
        Scale = 100,
    },
})

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local BUTTON_NAME = "OrbitMinimapButton"
local BUTTON_SIZE = 29
local DEFAULT_POSITION_X = -120
local DEFAULT_POSITION_Y = 120
local EDIT_MODE_FRAME_LEVEL = 50

local BACKDROP_SIZE = 28
local ORB_INSET = 1
local CIRCLE_GLOW_SIZE = 35
local DARK_GLOW_SIZE = 34
local SPARKLES_SIZE = 25

local MASK_ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local ORB_ROTATION_PERIOD = 24
local OUTER_FX_FADE_OUT = 0.25
local OUTER_FX_PULSE_PERIOD = 1.6
local OUTER_FX_PULSE_MIN = 0.55
local OUTER_FX_PULSE_MAX = 1.0

local SPARKLES_ROWS = 7
local SPARKLES_COLS = 5
local SPARKLES_FRAMES = SPARKLES_ROWS * SPARKLES_COLS
local SPARKLES_DURATION = 5.0
local SPARKLES_FRAME_TIME = SPARKLES_DURATION / SPARKLES_FRAMES
local SPARKLES_ROTATION_PERIOD = 14
local SPARKLES_ALPHA = 0.7

local VIGOR_SIZE = 50
local VIGOR_ROWS = 4
local VIGOR_COLS = 4
local VIGOR_FRAME_ROW = 1
local VIGOR_FRAME_COL = 2
local VIGOR_ROTATION_PERIOD = 30

local ATLAS_CIRCLE_GLOW = "ChallengeMode-Runes-CircleGlow"
local ATLAS_DARK_GLOW = "Darktrait-Glow"
local ATLAS_ORB = "UF-Arcane-Orb"
local ATLAS_OUTER_FX = "UF-Arcane-OuterFX"
local ATLAS_SPARKLES = "shop-toast-sparkles-flipbook"
local ATLAS_VIGOR = "dragonriding_sgvigor_burst_flipbook"

local TWO_PI = math.pi * 2
local sin, floor, mathmin = math.sin, math.floor, math.min

-- [ SPARKLES FLIPBOOK ]------------------------------------------------------------------------------
-- Packed atlas: cell stepping uses _aL/_aR/_aT/_aB cached at creation, not 0..1 of the texture file.
local function SparklesSetFrame(fx, idx)
    local c = idx % SPARKLES_COLS
    local r = floor(idx / SPARKLES_COLS)
    local cellW = (fx._aR - fx._aL) / SPARKLES_COLS
    local cellH = (fx._aB - fx._aT) / SPARKLES_ROWS
    fx:SetTexCoord(fx._aL + c * cellW, fx._aL + (c + 1) * cellW, fx._aT + r * cellH, fx._aT + (r + 1) * cellH)
end

-- [ VIGOR STATIC FRAME ]-----------------------------------------------------------------------------
-- 4x4 packed atlas; lock to a single cell (row VIGOR_FRAME_ROW, col VIGOR_FRAME_COL = frame 12).
local function VigorSetCell(fx)
    local cellW = (fx._aR - fx._aL) / VIGOR_COLS
    local cellH = (fx._aB - fx._aT) / VIGOR_ROWS
    fx:SetTexCoord(fx._aL + VIGOR_FRAME_COL * cellW, fx._aL + (VIGOR_FRAME_COL + 1) * cellW,
                   fx._aT + VIGOR_FRAME_ROW * cellH, fx._aT + (VIGOR_FRAME_ROW + 1) * cellH)
end

-- [ ON UPDATE ]--------------------------------------------------------------------------------------
local function ButtonOnUpdate(button, elapsed)
    button._orbAngle = ((button._orbAngle or 0) + elapsed * (TWO_PI / ORB_ROTATION_PERIOD)) % TWO_PI
    button.orb:SetRotation(button._orbAngle)
    button.darkGlow:SetRotation(button._orbAngle)

    local fx = button.outerFX
    if button._hover then
        button._hoverTime = (button._hoverTime or 0) + elapsed
        local t = (button._hoverTime % OUTER_FX_PULSE_PERIOD) / OUTER_FX_PULSE_PERIOD
        local mid = (OUTER_FX_PULSE_MIN + OUTER_FX_PULSE_MAX) * 0.5
        local amp = (OUTER_FX_PULSE_MAX - OUTER_FX_PULSE_MIN) * 0.5
        fx:SetAlpha(mid + amp * sin(t * TWO_PI))
    elseif button._fadeOut then
        button._fadeOutTime = button._fadeOutTime + elapsed
        local k = mathmin(1, button._fadeOutTime / OUTER_FX_FADE_OUT)
        fx:SetAlpha(button._fadeStart * (1 - k))
        if k >= 1 then button._fadeOut = false; fx:Hide() end
    end

    button._sparklesElapsed = (button._sparklesElapsed or 0) + elapsed
    while button._sparklesElapsed >= SPARKLES_FRAME_TIME do
        button._sparklesElapsed = button._sparklesElapsed - SPARKLES_FRAME_TIME
        button._sparklesFrame = ((button._sparklesFrame or 0) + 1) % SPARKLES_FRAMES
        SparklesSetFrame(button.sparkles, button._sparklesFrame)
    end
    button._sparklesAngle = ((button._sparklesAngle or 0) + elapsed * (TWO_PI / SPARKLES_ROTATION_PERIOD)) % TWO_PI
    button.sparkles:SetRotation(button._sparklesAngle)

    if button.vigor._aL then
        button._vigorAngle = ((button._vigorAngle or 0) + elapsed * (TWO_PI / VIGOR_ROTATION_PERIOD)) % TWO_PI
        button.vigor:SetRotation(button._vigorAngle)
    end
end

-- [ EVENT HANDLERS ]---------------------------------------------------------------------------------
local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Orbit", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.CMD_MINIMAP_LEFT_CLICK, 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L.CMD_MINIMAP_RIGHT_CLICK, 0.8, 0.8, 0.8)
    GameTooltip:Show()
    self.outerFX:Show()
    self._hover = true
    self._hoverTime = 0
    self._fadeOut = false
end

local function OnLeave(self)
    GameTooltip:Hide()
    self._hover = false
    self._fadeOut = true
    self._fadeOutTime = 0
    self._fadeStart = self.outerFX:GetAlpha()
end

local function OnClick(self, button)
    if InCombatLockdown() then return end
    if button == "LeftButton" then
        if EditModeManagerFrame:IsShown() then
            securecall("HideUIPanel", EditModeManagerFrame)
            if Orbit.OptionsPanel then Orbit.OptionsPanel:Hide() end
        else
            securecall("ShowUIPanel", EditModeManagerFrame)
            if Orbit.OptionsPanel then Orbit.OptionsPanel:Open("Global") end
        end
    elseif button == "RightButton" then
        if Orbit._pluginSettingsCategoryID then
            Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
        end
    end
end

-- [ FACTORY ]----------------------------------------------------------------------------------------
local function CreateButton(parent)
    local btn = CreateFrame("Button", BUTTON_NAME, parent)
    btn:SetAllPoints(parent)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetColorTexture(0, 0, 0, 1)
    btn.bg:SetSize(BACKDROP_SIZE, BACKDROP_SIZE)
    btn.bg:SetPoint("CENTER", btn, "CENTER", 0, 0)
    local bgMask = btn:CreateMaskTexture(nil, "BACKGROUND")
    bgMask:SetTexture(MASK_ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bgMask:SetAllPoints(btn.bg)
    btn.bg:AddMaskTexture(bgMask)

    btn.circleGlow = btn:CreateTexture(nil, "BORDER", nil, 0)
    btn.circleGlow:SetAtlas(ATLAS_CIRCLE_GLOW)
    btn.circleGlow:SetSize(CIRCLE_GLOW_SIZE, CIRCLE_GLOW_SIZE)
    btn.circleGlow:SetPoint("CENTER", btn, "CENTER", 0, 0)

    btn.darkGlow = btn:CreateTexture(nil, "BORDER", nil, 1)
    btn.darkGlow:SetAtlas(ATLAS_DARK_GLOW)
    btn.darkGlow:SetSize(DARK_GLOW_SIZE, DARK_GLOW_SIZE)
    btn.darkGlow:SetPoint("CENTER", btn, "CENTER", 0, 0)
    local darkGlowMask = btn:CreateMaskTexture(nil, "BORDER")
    darkGlowMask:SetTexture(MASK_ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    darkGlowMask:SetAllPoints(btn.darkGlow)
    btn.darkGlow:AddMaskTexture(darkGlowMask)

    local insetPx = Orbit.Engine.Pixel:Multiple(ORB_INSET, btn:GetEffectiveScale())
    btn.orb = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    btn.orb:SetAtlas(ATLAS_ORB)
    btn.orb:SetPoint("TOPLEFT", insetPx, -insetPx)
    btn.orb:SetPoint("BOTTOMRIGHT", -insetPx, insetPx)

    btn.outerFX = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    btn.outerFX:SetAtlas(ATLAS_OUTER_FX)
    btn.outerFX:SetPoint("TOPLEFT", insetPx, -insetPx)
    btn.outerFX:SetPoint("BOTTOMRIGHT", -insetPx, insetPx)
    btn.outerFX:SetBlendMode("ADD")
    btn.outerFX:SetAlpha(0)
    btn.outerFX:Hide()

    btn.sparkles = btn:CreateTexture(nil, "OVERLAY", nil, 2)
    local sparklesInfo = C_Texture.GetAtlasInfo(ATLAS_SPARKLES)
    btn.sparkles:SetTexture(sparklesInfo.file)
    btn.sparkles._aL, btn.sparkles._aR = sparklesInfo.leftTexCoord, sparklesInfo.rightTexCoord
    btn.sparkles._aT, btn.sparkles._aB = sparklesInfo.topTexCoord, sparklesInfo.bottomTexCoord
    btn.sparkles:SetSize(SPARKLES_SIZE, SPARKLES_SIZE)
    btn.sparkles:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.sparkles:SetBlendMode("ADD")
    btn.sparkles:SetAlpha(SPARKLES_ALPHA)
    SparklesSetFrame(btn.sparkles, 0)
    local sparklesMask = btn:CreateMaskTexture(nil, "OVERLAY")
    sparklesMask:SetTexture(MASK_ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    sparklesMask:SetAllPoints(btn.sparkles)
    btn.sparkles:AddMaskTexture(sparklesMask)

    btn.vigor = btn:CreateTexture(nil, "OVERLAY", nil, 3)
    btn.vigor:SetSize(VIGOR_SIZE, VIGOR_SIZE)
    btn.vigor:SetPoint("CENTER", btn, "CENTER", 0, 0)
    local vigorInfo = C_Texture.GetAtlasInfo(ATLAS_VIGOR)
    if vigorInfo then
        btn.vigor:SetTexture(vigorInfo.file)
        btn.vigor._aL, btn.vigor._aR = vigorInfo.leftTexCoord, vigorInfo.rightTexCoord
        btn.vigor._aT, btn.vigor._aB = vigorInfo.topTexCoord, vigorInfo.bottomTexCoord
        VigorSetCell(btn.vigor)
    end

    btn:SetScript("OnEnter", OnEnter)
    btn:SetScript("OnLeave", OnLeave)
    btn:SetScript("OnClick", OnClick)
    btn:SetScript("OnUpdate", ButtonOnUpdate)

    return btn
end

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "Scale",
        label = L.PLU_MMB_SCALE,
        default = 100,
        min = 50,
        max = 150,
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self.frame = CreateFrame("Frame", "OrbitMinimapButtonContainer", UIParent)
    self.frame:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    self.frame:SetFrameStrata(Orbit.Constants.Strata.HUD)
    self.frame:SetFrameLevel(EDIT_MODE_FRAME_LEVEL)
    self.frame:SetClampedToScreen(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Minimap Button"
    self.frame.anchorOptions = { horizontal = true, vertical = true }
    self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", DEFAULT_POSITION_X, DEFAULT_POSITION_Y)

    self.button = CreateButton(self.frame)

    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)
end

function Plugin:ApplySettings()
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:ApplySettings() end)
        return
    end
    local scale = self:GetSetting(SYSTEM_ID, "Scale") or 100
    self.frame:SetScale(scale / 100)
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(self.frame, self, SYSTEM_ID) end
end
