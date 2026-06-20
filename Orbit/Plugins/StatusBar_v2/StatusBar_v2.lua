---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_StatusBar_v2"
local FRAME_NAME = "OrbitStatusBarV2"

-- Fixed base geometry; the user resizes via Scale (matches MinimapButton/TalkingHead/BagBar), not a pixel size.
local BASE_SIZE = 120
local DEFAULT_SCALE = 100
local DEFAULT_Y = -200
-- Center hole as a fraction of diameter — matches the v5 asset's BAND_IN, leaves room for a level-up slot.
local CENTER_RATIO = 0.66

local RADIAL_DIR = "Interface\\AddOns\\Orbit\\Core\\assets\\Radial\\"
local TRACK_TEX = RADIAL_DIR .. "orbit-radial-track"
local FILL_TEX = RADIAL_DIR .. "orbit-radial-fill"
local BORDER_TEX = RADIAL_DIR .. "orbit-radial-border"
local GLOW_TEX = RADIAL_DIR .. "orbit-radial-glow"

-- Center-slot flourish (Great Vault unlock, future level-up FX). Glow underlay bursts past the orb.
local FLOURISH_COLOR = { r = 1.0, g = 0.82, b = 0.35 }
local FLOURISH_SIZE = BASE_SIZE * 1.2
-- Blizzard's authentic unlock FX: a 9x9 / 77-frame flipbook (greatVault-anim-unlocked-FX), 160x200 native.
local VAULT_FX_ATLAS = "greatVault-anim-unlocked-FX"
local VAULT_FX_ROWS, VAULT_FX_COLS, VAULT_FX_FRAMES = 9, 9, 77
local VAULT_FX_DURATION = 2.57
local VAULT_FX_W, VAULT_FX_H = BASE_SIZE * 0.704, BASE_SIZE * 0.88
-- Event text ("You unlocked vault slot X" etc.) sits just right of the ring, in the global Orbit font.
local FLOURISH_TEXT_WIDTH = 220
local FLOURISH_TEXT_GAP = 5
local FLOURISH_TITLE_SIZE = 20
local FLOURISH_SUB_SIZE = 16
local FLOURISH_TITLE_COLOR = { r = 1.0, g = 0.82, b = 0.35 }
-- After the burst, linger on the final FX frame + text for this long before fading out.
local FLOURISH_HOLD = 5

-- Asset bakes a bottom-origin clockwise sweep; SetRotation(pi)+SetReverse(true) aligns the Cooldown reveal to it.
local FILL_ROTATION = math.pi
local FILL_REVERSE = true

local MODE_XP = "xp"
local MODE_REP = "rep"
local MODE_HONOR = "honor"

local XP_COLOR = { r = 0.58, g = 0.0, b = 0.55, a = 1 }
local HONOR_COLOR = { r = 0.85, g = 0.20, b = 0.15, a = 1 }

local REACTION_LABEL = {
    [1] = L.PLU_REP_REACTION_1, [2] = L.PLU_REP_REACTION_2, [3] = L.PLU_REP_REACTION_3, [4] = L.PLU_REP_REACTION_4,
    [5] = L.PLU_REP_REACTION_5, [6] = L.PLU_REP_REACTION_6, [7] = L.PLU_REP_REACTION_7, [8] = L.PLU_REP_REACTION_8,
}

local WOW_EVENTS = {
    "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN",
    "HONOR_XP_UPDATE", "HONOR_LEVEL_UPDATE", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
}

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Status Bar v2", SYSTEM_ID, {
    displayName = L.PLG_NAME_STATUS_BAR_V2,
    liveToggle = true,
    defaults = {
        Scale = DEFAULT_SCALE,
        ReplaceVaultToast = true,
        XPColor = { pins = { { position = 0, color = { r = XP_COLOR.r, g = XP_COLOR.g, b = XP_COLOR.b, a = 1 } } } },
        HonorColor = { pins = { { position = 0, color = { r = HONOR_COLOR.r, g = HONOR_COLOR.g, b = HONOR_COLOR.b, a = 1 } } } },
    },
})

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    local frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    OrbitEngine.Pixel:Enforce(frame)
    frame:SetClampedToScreen(true)
    frame:SetSize(BASE_SIZE, BASE_SIZE)
    frame.systemIndex = SYSTEM_ID
    frame.editModeName = L.PLU_STATUS_BAR_V2_NAME
    frame.anchorOptions = { horizontal = true, vertical = true }
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)

    -- TRILINEAR enables mipmap filtering so the high-res art minifies cleanly at low Scale (no aliasing).
    local track = frame:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(TRACK_TEX, nil, nil, "TRILINEAR")
    track:SetAllPoints(frame)
    frame.Track = track

    -- Radial fill: a paused Cooldown swipe that reveals the tintable fill band. C++ handles the sweep.
    local fill = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    fill:SetAllPoints(frame)
    fill:SetFrameLevel(frame:GetFrameLevel() + 1)
    fill:SetHideCountdownNumbers(true)
    fill:SetDrawEdge(false)
    fill:SetDrawBling(false)
    fill:SetDrawSwipe(true)
    fill:SetReverse(FILL_REVERSE)
    fill:SetRotation(FILL_ROTATION)
    fill:SetSwipeTexture(FILL_TEX)
    CooldownFrame_SetDisplayAsPercentage(fill, 0)
    frame.Fill = fill

    -- Border drawn above the fill so the sweep stays inside the groove.
    local borderHost = CreateFrame("Frame", nil, frame)
    borderHost:SetAllPoints(frame)
    borderHost:SetFrameLevel(fill:GetFrameLevel() + 1)
    local border = borderHost:CreateTexture(nil, "ARTWORK")
    border:SetTexture(BORDER_TEX, nil, nil, "TRILINEAR")
    border:SetAllPoints(borderHost)
    frame.Border = border

    -- Hollow center slot, home for flourishes (Great Vault unlock now, more later).
    local center = CreateFrame("Frame", nil, frame)
    center:SetFrameLevel(borderHost:GetFrameLevel() + 1)
    center:SetPoint("CENTER")
    center:SetSize(BASE_SIZE * CENTER_RATIO, BASE_SIZE * CENTER_RATIO)
    frame.Center = center

    self.frame = frame
    self.Frame = frame

    self:SetupCenterFX(frame)
    OrbitEngine.Frame:AttachSettingsListener(frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)
    self:SetupInteraction()

    for _, event in ipairs(WOW_EVENTS) do
        Orbit.EventBus:On(event, function() self:OnEvent() end, self)
    end
    Orbit.EventBus:On("MODIFIER_STATE_CHANGED", function() self:OnModifierChanged() end, self)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    self:SetupGreatVault()
end

-- [ CENTER FX ]--------------------------------------------------------------------------------------
-- Animation hub for the hollow center + side text. Add new flourish types here as they arrive.
function Plugin:SetupCenterFX(frame)
    -- Warm glow underlay — a quick halo accent at the start of the burst.
    local glow = frame.Center:CreateTexture(nil, "OVERLAY", nil, 1)
    glow:SetTexture(GLOW_TEX, nil, nil, "TRILINEAR")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER")
    glow:SetSize(FLOURISH_SIZE, FLOURISH_SIZE)
    glow:SetVertexColor(FLOURISH_COLOR.r, FLOURISH_COLOR.g, FLOURISH_COLOR.b)
    glow:SetAlpha(0)
    glow:Hide()
    local glowAnim = glow:CreateAnimationGroup()
    local scale = glowAnim:CreateAnimation("Scale")
    scale:SetScaleFrom(0.35, 0.35); scale:SetScaleTo(1.6, 1.6); scale:SetOrigin("CENTER", 0, 0)
    scale:SetDuration(0.7); scale:SetSmoothing("OUT")
    local gIn = glowAnim:CreateAnimation("Alpha")
    gIn:SetFromAlpha(0); gIn:SetToAlpha(1); gIn:SetDuration(0.16)
    local gOut = glowAnim:CreateAnimation("Alpha")
    gOut:SetStartDelay(0.16); gOut:SetFromAlpha(1); gOut:SetToAlpha(0); gOut:SetDuration(0.54)
    glowAnim:SetScript("OnPlay", function() glow:Show() end)
    glowAnim:SetScript("OnFinished", function() glow:Hide() end)
    frame.Flourish = glow
    frame.FlourishAnim = glowAnim

    -- Blizzard's authentic unlock FX flipbook on top of the glow.
    local fx = frame.Center:CreateTexture(nil, "OVERLAY", nil, 2)
    fx:SetAtlas(VAULT_FX_ATLAS)
    fx:SetSize(VAULT_FX_W, VAULT_FX_H)
    fx:SetPoint("CENTER")
    fx:Hide()
    local fxAnim = fx:CreateAnimationGroup()
    local flip = fxAnim:CreateAnimation("FlipBook")
    flip:SetDuration(VAULT_FX_DURATION)
    flip:SetFlipBookRows(VAULT_FX_ROWS)
    flip:SetFlipBookColumns(VAULT_FX_COLS)
    flip:SetFlipBookFrames(VAULT_FX_FRAMES)
    flip:SetFlipBookFrameWidth(0)
    flip:SetFlipBookFrameHeight(0)
    fxAnim:SetScript("OnPlay", function() fx:Show() end)
    fxAnim:SetScript("OnFinished", function() self:HoldVaultFX() end)
    frame.FlourishFX = fx
    frame.FlourishFXAnim = fxAnim

    -- A separate static texture holds the final frame during the linger. The FlipBook reverts the
    -- flipbook texture's texcoords after OnFinished, so pinning it there gets overwritten — pin a
    -- texture nothing animates instead.
    local fxFinal = frame.Center:CreateTexture(nil, "OVERLAY", nil, 2)
    fxFinal:SetAtlas(VAULT_FX_ATLAS)
    fxFinal:SetSize(VAULT_FX_W, VAULT_FX_H)
    fxFinal:SetPoint("CENTER")
    fxFinal:Hide()
    frame.FlourishFXFinal = fxFinal
    local fxHold = fxFinal:CreateAnimationGroup()
    local hold = fxHold:CreateAnimation("Alpha")
    hold:SetStartDelay(FLOURISH_HOLD); hold:SetFromAlpha(1); hold:SetToAlpha(0); hold:SetDuration(0.5)
    fxHold:SetScript("OnFinished", function() fxFinal:Hide() end)
    frame.FlourishFXHold = fxHold

    -- Event text to the right of the orb.
    local text = CreateFrame("Frame", nil, frame)
    text:SetFrameLevel(frame.Center:GetFrameLevel() + 1)
    text:SetSize(FLOURISH_TEXT_WIDTH, BASE_SIZE)
    text:SetPoint("LEFT", frame, "RIGHT", FLOURISH_TEXT_GAP, 0)
    text:SetAlpha(0)
    text:Hide()
    -- No fixed width + word wrap off → always a single line, auto-sized to its text.
    local title = text:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", text, "LEFT", 0, 0)
    title:SetJustifyH("LEFT"); title:SetWordWrap(false)
    local sub = text:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetJustifyH("LEFT"); sub:SetWordWrap(false)
    local textAnim = text:CreateAnimationGroup()
    local tIn = textAnim:CreateAnimation("Alpha")
    tIn:SetFromAlpha(0); tIn:SetToAlpha(1); tIn:SetDuration(0.3)
    local tOut = textAnim:CreateAnimation("Alpha")
    tOut:SetStartDelay(VAULT_FX_DURATION + FLOURISH_HOLD); tOut:SetFromAlpha(1); tOut:SetToAlpha(0); tOut:SetDuration(0.6)
    textAnim:SetScript("OnPlay", function() text:Show() end)
    textAnim:SetScript("OnFinished", function() text:Hide() end)
    text.Title = title
    text.SubTitle = sub
    frame.FlourishText = text
    frame.FlourishTextAnim = textAnim
    self:ApplyFlourishFont()
end

-- Flourish text follows the global Orbit font; re-skinned on theme change via ApplySettings.
function Plugin:ApplyFlourishFont()
    local text = self.frame and self.frame.FlourishText
    if not text then return end
    local gs = Orbit.db.GlobalSettings
    Orbit.Skin:SkinText(text.Title, { font = gs.Font, textSize = FLOURISH_TITLE_SIZE })
    text.Title:SetTextColor(FLOURISH_TITLE_COLOR.r, FLOURISH_TITLE_COLOR.g, FLOURISH_TITLE_COLOR.b)
    text.Title:SetWordWrap(false)
    Orbit.Skin:SkinText(text.SubTitle, { font = gs.Font, textSize = FLOURISH_SUB_SIZE })
    text.SubTitle:SetWordWrap(false)
end

-- Public entry point GreatVault.lua calls on a vault event. title/subtitle are the event strings.
function Plugin:PlayVaultFlourish(title, subtitle)
    local frame = self.frame
    if not frame or not frame.FlourishFXAnim then return end
    frame.FlourishAnim:Stop();   frame.FlourishAnim:Play()

    -- Restart clean: cancel any lingering hold, hide the held frame, reset the sheet, replay the burst.
    frame.FlourishFXHold:Stop()
    frame.FlourishFXAnim:Stop()
    frame.FlourishFXFinal:Hide()
    frame.FlourishFX:SetAtlas(VAULT_FX_ATLAS)
    frame.FlourishFX:SetAlpha(1)
    frame.FlourishFXAnim:Play()

    local text = frame.FlourishText
    text.Title:SetText(title or "")
    text.SubTitle:SetText(subtitle or "")
    -- Vertically center: one line sits on the orb's middle; two lines straddle it.
    local hasSub = subtitle and subtitle ~= ""
    text.Title:ClearAllPoints()
    text.Title:SetPoint(hasSub and "BOTTOMLEFT" or "LEFT", text, "LEFT", 0, hasSub and 2 or 0)
    text.SubTitle:SetShown(hasSub)
    frame.FlourishTextAnim:Stop()
    if (title and title ~= "") or hasSub then
        frame.FlourishTextAnim:Play()
    end
end

-- Hand off from the burst to the held final frame, then start its linger fade. Copy the flipbook's
-- exact texcoords (read here, before the FlipBook reverts them) so the held frame matches it — no jump.
function Plugin:HoldVaultFX()
    local frame = self.frame
    if not frame then return end
    frame.FlourishFXFinal:SetTexCoord(frame.FlourishFX:GetTexCoord())
    frame.FlourishFX:Hide()
    frame.FlourishFXFinal:SetAlpha(1)
    frame.FlourishFXFinal:Show()
    frame.FlourishFXHold:Play()
end

-- [ INTERACTION ]------------------------------------------------------------------------------------
function Plugin:SetupInteraction()
    local frame = self.frame
    frame:EnableMouse(true)
    frame:HookScript("OnEnter", function()
        self._hovered = true
        self:UpdateBar()
        self:RefreshTooltip()
    end)
    frame:HookScript("OnLeave", function()
        self._hovered = false
        self:UpdateBar()
        GameTooltip:Hide()
    end)
end

-- Shift swaps to honor only while the cursor is over the bar; re-resolve on any modifier transition.
function Plugin:OnModifierChanged()
    if not self._hovered then return end
    self:UpdateBar()
    self:RefreshTooltip()
end

-- [ EVENTS ]-----------------------------------------------------------------------------------------
-- Defer one tick so secret-adjacent reads don't run inside Blizzard's synchronous event chain.
function Plugin:OnEvent()
    if self._updatePending then return end
    self._updatePending = true
    C_Timer.After(0, function()
        self._updatePending = false
        if self.frame then self:UpdateBar() end
    end)
end

-- [ MODE RESOLUTION ]--------------------------------------------------------------------------------
-- Honor only while hovered AND shift is held; otherwise xp while leveling, reputation at max level.
function Plugin:ResolveMode()
    if self._hovered and IsShiftKeyDown() then return MODE_HONOR end
    local level = UnitLevel("player")
    local xpDisabled = IsXPUserDisabled and IsXPUserDisabled() or false
    if level and level < GetMaxPlayerLevel() and not xpDisabled then return MODE_XP end
    return MODE_REP
end

function Plugin:BuildRecord()
    local mode = self:ResolveMode()
    if mode == MODE_HONOR then
        return { mode = mode, name = L.PLU_HONOR_NAME, level = UnitHonorLevel("player") or 0,
                 current = UnitHonor("player"), max = UnitHonorMax("player"),
                 color = self:GetColor("HonorColor", HONOR_COLOR) }
    elseif mode == MODE_XP then
        return { mode = mode, name = L.PLU_XP_NAME, level = UnitLevel("player") or 0,
                 current = UnitXP("player"), max = UnitXPMax("player"),
                 color = self:GetColor("XPColor", XP_COLOR) }
    end
    return self:BuildRepRecord()
end

-- Reputation spans come from plain (non-secret) C_Reputation data, reduced to a 0-based current/max.
function Plugin:BuildRepRecord()
    local RC = OrbitEngine.ReactionColor
    local watched = C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
    if not watched or not watched.factionID or watched.factionID == 0 then
        return { mode = MODE_REP, name = L.PLU_SB_REP_NONE, level = "", current = 0, max = 1,
                 color = self:GetColor("XPColor", XP_COLOR) }
    end

    local factionID = watched.factionID
    local majorData = C_MajorFactions and C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(factionID)
    if majorData and majorData.renownLevelThreshold and majorData.renownLevelThreshold > 0 then
        return { mode = MODE_REP, name = majorData.name or watched.name,
                 level = L.PLU_REP_RENOWN_F:format(majorData.renownLevel or 0),
                 current = majorData.renownReputationEarned or 0, max = majorData.renownLevelThreshold,
                 color = RC:GetOverride("RENOWN") }
    end

    if C_Reputation.IsFactionParagon and C_Reputation.IsFactionParagon(factionID) then
        local value, threshold, _, hasReward = C_Reputation.GetFactionParagonInfo(factionID)
        if value and threshold and threshold > 0 then
            return { mode = MODE_REP, name = watched.name,
                     level = hasReward and L.PLU_REP_PARAGON_READY or L.PLU_REP_PARAGON,
                     current = value % threshold, max = threshold,
                     color = RC:GetOverride(hasReward and "PARAGON_REWARD" or "PARAGON") }
        end
    end

    local reaction = watched.reaction or 4
    local reactionMin = watched.currentReactionThreshold or 0
    local reactionMax = watched.nextReactionThreshold or (reactionMin + 1)
    if reactionMax <= reactionMin then reactionMax = reactionMin + 1 end
    return { mode = MODE_REP, name = watched.name or L.PLU_REP_UNKNOWN_FACTION,
             level = REACTION_LABEL[reaction] or "",
             current = (watched.currentStanding or reactionMin) - reactionMin,
             max = reactionMax - reactionMin,
             color = RC:GetReactionColor(reaction) }
end

-- [ UPDATE ]-----------------------------------------------------------------------------------------
function Plugin:UpdateBar()
    if not self.frame then return end
    local record = self:BuildRecord()
    self.record = record
    self:RenderFill(record.current, record.max, record.color)
end

-- Pass the secret value through only as a non-secret ratio; guard the Lua division so a secret read
-- holds the last displayed sweep instead of throwing (mirrors StatusBarBase:SetFill).
function Plugin:RenderFill(current, max, color)
    local fill = self.frame.Fill
    fill:SetSwipeColor(color.r, color.g, color.b, color.a or 1)
    if issecretvalue(current) or issecretvalue(max) or not max or max <= 0 then return end
    CooldownFrame_SetDisplayAsPercentage(fill, current / max)
end

function Plugin:GetColor(key, fallback)
    local curve = self:GetSetting(SYSTEM_ID, key)
    local c = curve and OrbitEngine.ColorCurve and OrbitEngine.ColorCurve:GetFirstColorFromCurve(curve)
    return c or fallback
end

-- [ TOOLTIP ]----------------------------------------------------------------------------------------
function Plugin:RefreshTooltip()
    if not self._hovered or Orbit:IsEditMode() then return end
    self:ShowTooltip()
end

function Plugin:ShowTooltip()
    local record = self.record
    if not record then return end
    GameTooltip:SetOwner(self.frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine(record.name)
    if record.level ~= "" then GameTooltip:AddLine(tostring(record.level), 1, 1, 1) end
    local cur, max = record.current, record.max
    if not issecretvalue(cur) and not issecretvalue(max) and max and max > 0 then
        GameTooltip:AddLine(("%d / %d  (%.0f%%)"):format(cur, max, (cur / max) * 100), 1, 1, 1)
    end
    GameTooltip:Show()
end

-- [ APPLY SETTINGS ]---------------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then return end

    frame:SetScale((self:GetSetting(SYSTEM_ID, "Scale") or DEFAULT_SCALE) / 100)
    self:ApplyFlourishFont()

    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, SYSTEM_ID) end

    C_Timer.After(0, function()
        if self.frame then self:UpdateBar() end
    end)
end

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog,
        { L.PLU_SB_TAB_LAYOUT, L.PLU_SB_TAB_COLOR, L.PLU_SB_TAB_BEHAVIOUR },
        L.PLU_SB_TAB_LAYOUT)

    if currentTab == L.PLU_SB_TAB_LAYOUT then
        SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, { default = DEFAULT_SCALE })
    elseif currentTab == L.PLU_SB_TAB_COLOR then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, { key = "XPColor",    label = L.PLU_SB_XP_COLOR,  singleColor = true })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, { key = "HonorColor", label = L.PLU_SB_BAR_COLOR, singleColor = true })
    elseif currentTab == L.PLU_SB_TAB_BEHAVIOUR then
        table.insert(schema.controls, {
            type = "checkbox", key = "ReplaceVaultToast", label = L.PLU_SB_V2_VAULT_TOAST, default = true,
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
