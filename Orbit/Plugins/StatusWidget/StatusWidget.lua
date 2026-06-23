---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_StatusWidget"
local FRAME_NAME = "OrbitStatusWidget"

-- Fixed base geometry; the user resizes via Scale (matches MinimapButton/TalkingHead/BagBar), not a pixel size.
local BASE_SIZE = 120
local DEFAULT_SCALE = 100
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 30, 100, 5
-- Default position: inset from the screen's top-left corner; RestorePosition overrides it from saved layout.
local DEFAULT_INSET = 24
-- Center hole as a fraction of diameter — matches the v5 asset's BAND_IN, leaves room for a level-up slot.
local CENTER_RATIO = 0.66

local RADIAL_DIR = "Interface\\AddOns\\Orbit\\Core\\assets\\Radial\\"
local TRACK_TEX = RADIAL_DIR .. "orbit-radial-track"
local FILL_TEX = RADIAL_DIR .. "orbit-radial-fill"
-- Static (angularly-uniform) twin of the fill: white luminance, no dark->light sweep, for the tintable backdrop.
local BACKDROP_TEX = RADIAL_DIR .. "orbit-radial-backdrop"
-- Radial vignette peaking at the inner-border radius, fading to clear at centre — the event mood backdrop.
local INNER_VIGNETTE_TEX = RADIAL_DIR .. "orbit-radial-innervignette"
local BORDER_TEX = RADIAL_DIR .. "orbit-radial-border"
local GLOW_TEX = RADIAL_DIR .. "orbit-radial-glow"
-- Metal shrapnel for the durability-break shatter flourish (white-luminance, additive, tinted red/amber).
local SHARDBURST_TEX = RADIAL_DIR .. "orbit-radial-shardburst"

-- Center-slot flourish (Great Vault unlock, future level-up FX). Glow underlay bursts past the orb.
local FLOURISH_COLOR = { r = 1.0, g = 0.82, b = 0.35 }
local SOCIAL_COLOR = { r = 0.20, g = 0.60, b = 1.0 }   -- battle.net blue glow for social toasts
local FLOURISH_SIZE = BASE_SIZE * 1.2
local IMPACT_DUR = 0.5   -- ring scale-punch + shake duration on a burst flourish
local SHATTER_FORM_DELAY = 0.30   -- the cracked inner circle forms this far into the shatter shrapnel burst
-- "Slam" tween phase end-times (s): the flash detonates ON the slam (_LevelImpact at LVLNUM_LAND), frame-perfect.
local LVLNUM_RISE = 0.30   -- windup: rise + fade-in toward the top
local LVLNUM_LAND = 0.50   -- slam to the lowest point — the flash/impact detonates HERE (frame-perfect)
local LVLNUM_GROW = 0.78   -- settle to centre + grow punch
local LVLNUM_FADE = 1.46   -- dissolve while drifting larger (grow + fade still run long)
local LVLNUM_RISE_UP = BASE_SIZE * 0.26       -- how far up it floats during the rise
local LVLNUM_OVERSHOOT = BASE_SIZE * 0.04     -- dip below centre on the solid landing
local LVLNUM_GROW_PEAK, LVLNUM_GROW_DRIFT = 1.70, 2.10
-- Renown's "grow-in" phase end-times (s); reuses LVLNUM_GROW_PEAK/DRIFT so its size matches the slam motion.
local LVLGROW_FROM = 0.40
local LVLGROW_IN, LVLGROW_HOLD, LVLGROW_FADE = 0.35, 0.95, 1.6
-- Old-number lead before the new renown number stomps in — grow has no rise to give the old one its moment.
local MILESTONE_GROW_LEAD = 0.35
-- Per-milestone sprites: each gets its own burst + rays (only level-up gets the up-arrow) so they read as distinct.
local MILESTONE_FX_LEVELUP = { burst = "aftlevelup-whitestarburst", rays = "aftlevelup-lines1",                 arrow = true }
local MILESTONE_FX_RENOWN  = { burst = "ArtifactsFX-StarBurst",     rays = "evergreen-toast-celebration-shine", arrow = false }
local MILESTONE_FX_HONOR   = { burst = "honorsystem-bar-rewardborder-prestige-flash", rays = "pvpqueue-rankglow", arrow = false }
-- Blizzard's authentic unlock FX: a 9x9 / 77-frame flipbook (greatVault-anim-unlocked-FX), 160x200 native.
local VAULT_FX_ATLAS = "greatVault-anim-unlocked-FX"
local VAULT_FX_ROWS, VAULT_FX_COLS, VAULT_FX_FRAMES = 9, 9, 77
local VAULT_FX_DURATION = 2.57
local VAULT_FX_W, VAULT_FX_H = BASE_SIZE * 0.704, BASE_SIZE * 0.88
-- The FX art sits slightly off-centre in its cell (Blizzard nudges it too) — recentre left 1 / down 2.
local VAULT_FX_OFFSET_X, VAULT_FX_OFFSET_Y = -1, -2
-- The vault UPGRADE beat uses a different flipbook (keyhole burst, 8x9 / 64 frames) on the same texture.
local VAULT_UP_FX_ATLAS = "greatVault-anim-upgrade-FX"
local VAULT_UP_ROWS, VAULT_UP_COLS, VAULT_UP_FRAMES = 8, 9, 64
local VAULT_UP_DURATION = 2.13
-- New-mail flipbook (Blizzard's minimap mail reminder): 3x4 / 12 frames, looped while the toast shows.
local MAIL_FX_ATLAS = "UI-HUD-Minimap-Mail-Reminder-Flipbook-2x"
local MAIL_FX_ROWS, MAIL_FX_COLS, MAIL_FX_FRAMES = 3, 4, 12
local MAIL_FX_DURATION = 0.4
local MAIL_FX_SIZE = BASE_SIZE * 0.605   -- 10% larger
local MAIL_COLOR = { r = 1.0, g = 0.9, b = 0.55 }
-- Event text ("You unlocked vault slot X" etc.) sits just right of the ring, in the global Orbit font.
local FLOURISH_TEXT_WIDTH = 220
local FLOURISH_TEXT_GAP = 10
local FLOURISH_TITLE_SIZE = 30
local FLOURISH_SUB_SIZE = 26
-- One size for every centre number so they always match (the milestone animation scales its number up from this base).
local CENTER_NUMBER_SIZE = 40
local FLOURISH_TITLE_COLOR = { r = 1.0, g = 0.82, b = 0.35 }
local SOCIAL_ICON_RATIO = 0.45   -- social toast's own icon (BN logo / game icon) shown in the centre
local LOOT_ICON_RATIO = CENTER_RATIO   -- loot icon fills the hollow centre, circular-masked to a disc
local LOOT_MASK_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- soft circular alpha mask (Blizzard portrait mask)
-- Inner-border vignette tint: the metal border's inner-edge hue (~RGB 40,37,44), kept dim so it reads as a backdrop.
local INNER_BACKDROP_COLOR = { r = 0.13, g = 0.12, b = 0.16 }
local INNER_BACKDROP_ALPHA = 0.55
local INNER_FADE_IN, INNER_FADE_OUT = 0.3, 0.5

-- Asset bakes a bottom-origin clockwise sweep; SetRotation(pi)+SetReverse(true) aligns the Cooldown reveal to it.
local FILL_ROTATION = math.pi
local FILL_REVERSE = true

local MODE_XP = "xp"
local MODE_REP = "rep"
local MODE_HONOR = "honor"
local MODE_CURRENCY = "currency"

local XP_COLOR = { r = 0.58, g = 0.0, b = 0.55, a = 1 }
local HONOR_COLOR = { r = 0.85, g = 0.20, b = 0.15, a = 1 }
local REP_COLOR = { r = 0.20, g = 0.62, b = 0.34, a = 1 }
local RESTED_COLOR = { r = 0.30, g = 0.45, b = 0.95, a = 1 }
local BACKDROP_COLOR = { r = 0.14, g = 0.14, b = 0.17, a = 1 }   -- dim groove by default; tints the white fill ring
-- Flourish glow palette shared with the milestone / toast modules via Plugin.FlourishColors.
local COLLECT_COLOR = { r = 0.45, g = 0.55, b = 1.0 }   -- collectibles (mount/pet/toy/cosmetic/warband/recipe)
local ARCANE_COLOR = { r = 0.55, g = 0.45, b = 1.0 }    -- spell / ability learned
local DEFEAT_COLOR = { r = 0.90, g = 0.25, b = 0.20 }   -- boss-kill banner
local DURA_DAMAGED_COLOR = { r = 1.0, g = 0.78, b = 0.20 }   -- 40% durability break (amber; mirrors FillModes DURA_WARN_COLOR)
local DURA_BROKEN_COLOR = { r = 1.0, g = 0.25, b = 0.18 }    -- 20% durability break (red; mirrors FillModes DURA_CRIT_COLOR)

local REACTION_LABEL = {
    [1] = L.PLU_REP_REACTION_1, [2] = L.PLU_REP_REACTION_2, [3] = L.PLU_REP_REACTION_3, [4] = L.PLU_REP_REACTION_4,
    [5] = L.PLU_REP_REACTION_5, [6] = L.PLU_REP_REACTION_6, [7] = L.PLU_REP_REACTION_7, [8] = L.PLU_REP_REACTION_8,
}

local WOW_EVENTS = {
    "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN",
    "HONOR_XP_UPDATE", "HONOR_LEVEL_UPDATE", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
}

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Status Widget", SYSTEM_ID, {
    displayName = L.PLG_NAME_STATUS_BAR_V2,
    liveToggle = true,
    defaults = {
        Scale = DEFAULT_SCALE,
        ReplaceVaultToast = true,
        ReplaceSocialToast = true,
        ShowMailToast = true,
        ReplaceLootToast = true,
        ReplaceLootRoll = true,
        ShowMilestones = true,
        ShowRewardToasts = true,
        PrimarySource = "auto",
        SecondarySource = "honor",
        PrimaryCurrencyID = 0,
        SecondaryCurrencyID = 0,
        ShowCenterNumber = false,
        Animation = 0,
        XPColor = { pins = { { position = 0, color = { r = XP_COLOR.r, g = XP_COLOR.g, b = XP_COLOR.b, a = 1 } } } },
        HonorColor = { pins = { { position = 0, color = { r = HONOR_COLOR.r, g = HONOR_COLOR.g, b = HONOR_COLOR.b, a = 1 } } } },
        RepColor = { pins = { { position = 0, color = { r = REP_COLOR.r, g = REP_COLOR.g, b = REP_COLOR.b, a = 1 } } } },
        RestedColor = { pins = { { position = 0, color = { r = RESTED_COLOR.r, g = RESTED_COLOR.g, b = RESTED_COLOR.b, a = 1 } } } },
        BackdropColor = { pins = { { position = 0, color = { r = BACKDROP_COLOR.r, g = BACKDROP_COLOR.g, b = BACKDROP_COLOR.b, a = 1 } } } },
    },
})

-- Glow palette the milestone / toast modules read (e.g. Plugin.FlourishColors.collect), so the colour constants stay in one place.
Plugin.FlourishColors = {
    gold = FLOURISH_COLOR, social = SOCIAL_COLOR, mail = MAIL_COLOR,
    collect = COLLECT_COLOR, arcane = ARCANE_COLOR, defeat = DEFEAT_COLOR,
    honor = HONOR_COLOR, rep = REP_COLOR,
}

-- [ BLIZZARD STATUS BAR ]----------------------------------------------------------------------------
-- SecureHide (state driver) is the documented contract for hiding status tracking bars (Core/EditMode/README.md).
local function HideBlizzardStatusBar()
    if not StatusTrackingBarManager then return end
    if InCombatLockdown() then
        if Orbit.CombatManager then Orbit.CombatManager:QueueUpdate(HideBlizzardStatusBar) end
        return
    end
    OrbitEngine.NativeFrame:SecureHide(StatusTrackingBarManager)
end

-- A profile switch can live-disable the orb (liveToggle) with no /reload, so OnDisable hands Blizzard's bar back here.
local function RestoreBlizzardStatusBar()
    if not StatusTrackingBarManager then return end
    if InCombatLockdown() then
        if Orbit.CombatManager then Orbit.CombatManager:QueueUpdate(RestoreBlizzardStatusBar) end
        return
    end
    UnregisterStateDriver(StatusTrackingBarManager, "visibility")
    StatusTrackingBarManager:Show()
    if StatusTrackingBarManager.UpdateBarsShown then StatusTrackingBarManager:UpdateBarsShown() end
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self._disabled = false   -- cleared on (re-)enable; OnDisable sets it to quiesce the centre while off
    local frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    OrbitEngine.Pixel:Enforce(frame)
    frame:SetClampedToScreen(true)
    frame:SetSize(BASE_SIZE, BASE_SIZE)
    frame.systemIndex = SYSTEM_ID
    frame.editModeName = L.PLU_STATUS_BAR_V2_NAME
    frame.anchorOptions = { horizontal = true, vertical = true }
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DEFAULT_INSET, -DEFAULT_INSET)

    -- Content wrapper holds every visual so the Animation module can slide/rotate/fade the orb without touching the frame's EditMode-owned anchor.
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    frame.Content = content

    -- TRILINEAR enables mipmap filtering so the high-res art minifies cleanly at low Scale (no aliasing).
    local track = content:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(TRACK_TEX, nil, nil, "TRILINEAR")
    track:SetAllPoints(content)
    frame.Track = track

    -- Tintable groove backdrop: a STATIC white-luminance ring tinted by BackdropColor (the track art is baked near-black so SetVertexColor's multiply can't recolour it).
    local backdropRing = content:CreateTexture(nil, "BACKGROUND", nil, 1)
    backdropRing:SetTexture(BACKDROP_TEX, nil, nil, "TRILINEAR")
    backdropRing:SetAllPoints(content)
    frame.BackdropRing = backdropRing

    -- Rested-XP layer: a second swipe behind the main fill revealing current+rested; the main fill draws over its current portion so only the rested band shows.
    local restedFill = CreateFrame("Cooldown", nil, content, "CooldownFrameTemplate")
    restedFill:SetAllPoints(content)
    restedFill:SetFrameLevel(content:GetFrameLevel() + 1)
    restedFill:SetHideCountdownNumbers(true)
    restedFill:SetDrawEdge(false)
    restedFill:SetDrawBling(false)
    restedFill:SetDrawSwipe(true)
    restedFill:SetReverse(FILL_REVERSE)
    restedFill:SetRotation(FILL_ROTATION)
    restedFill:SetSwipeTexture(FILL_TEX)
    CooldownFrame_SetDisplayAsPercentage(restedFill, 0)
    restedFill:Hide()
    frame.RestedFill = restedFill

    -- Radial fill: a paused Cooldown swipe that reveals the tintable fill band. C++ handles the sweep.
    local fill = CreateFrame("Cooldown", nil, content, "CooldownFrameTemplate")
    fill:SetAllPoints(content)
    fill:SetFrameLevel(content:GetFrameLevel() + 2)
    fill:SetHideCountdownNumbers(true)
    fill:SetDrawEdge(false)
    fill:SetDrawBling(false)
    fill:SetDrawSwipe(true)
    fill:SetReverse(FILL_REVERSE)
    fill:SetRotation(FILL_ROTATION)
    fill:SetSwipeTexture(FILL_TEX)
    CooldownFrame_SetDisplayAsPercentage(fill, 0)
    frame.Fill = fill
    frame._fillRotation = FILL_ROTATION   -- base rotation the Animation module restores after a rotate-slide

    -- Border drawn above the fill so the sweep stays inside the groove.
    local borderHost = CreateFrame("Frame", nil, content)
    borderHost:SetAllPoints(content)
    borderHost:SetFrameLevel(fill:GetFrameLevel() + 1)
    local border = borderHost:CreateTexture(nil, "ARTWORK")
    border:SetTexture(BORDER_TEX, nil, nil, "TRILINEAR")
    border:SetAllPoints(borderHost)
    frame.Border = border

    -- Crack overlay above the ring, shown only when durability is low (FillModes._SetRingCrack swaps the light/heavy texture); textureless + hidden until then.
    local rcrack = borderHost:CreateTexture(nil, "ARTWORK", nil, 1)
    rcrack:SetAllPoints(borderHost)
    rcrack:Hide()
    frame.RingCrack = rcrack

    -- Hollow center slot, home for flourishes (Great Vault unlock now, more later).
    local center = CreateFrame("Frame", nil, content)
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
    self:SetupSocialToast()
    self:SetupMail()
    self:SetupLoot()
    self:SetupLootRoll()
    self:SetupMilestones()
    self:SetupAlertToasts()
    self:SetupFillModes()
    HideBlizzardStatusBar()
end

-- liveToggle teardown: the framework only hides the orb frame, so quiesce the centre machine ourselves; _disabled then no-ops Enqueue + the still-installed suppression hooks, and the drivers are nil'd so they rebind to the frame OnLoad rebuilds on re-enable.
function Plugin:OnDisable()
    self._disabled = true
    if not Orbit:IsBlizzardHidden("Status Widget") then RestoreBlizzardStatusBar() end
    if not self.frame then return end
    self:_FqCancelTimer()
    self._fqQueue, self._fqActive, self._fqPhase = nil, nil, nil
    self:_CancelLootReel("")                       -- cancels the reel timer + wipes the loot queue
    self:_ClearCenterFX()                          -- cancels the mail timer, stops every centre anim
    self._event, self._innerShown = nil, false
    if self._impactDriver then self._impactDriver:Hide(); self._impactDriver = nil end
    if self._lvlNumDriver then self._lvlNumDriver:Hide(); self._lvlNumDriver = nil end
    if self._animDriver then self._animDriver:Hide(); self._animDriver = nil end
end

-- [ CENTER FX ]--------------------------------------------------------------------------------------
-- Animation hub for the hollow center + side text. Add new flourish types here as they arrive.
function Plugin:SetupCenterFX(frame)
    local inner = frame.Center:CreateTexture(nil, "BACKGROUND")
    inner:SetTexture(INNER_VIGNETTE_TEX, nil, nil, "TRILINEAR")
    inner:SetSize(BASE_SIZE, BASE_SIZE)
    inner:SetPoint("CENTER")
    inner:SetVertexColor(INNER_BACKDROP_COLOR.r, INNER_BACKDROP_COLOR.g, INNER_BACKDROP_COLOR.b)
    inner:SetAlpha(0)
    inner:Hide()
    frame.InnerBackdrop = inner
    local innerIn = inner:CreateAnimationGroup()
    frame.InnerBackdropInA = innerIn:CreateAnimation("Alpha")
    frame.InnerBackdropInA:SetToAlpha(INNER_BACKDROP_ALPHA); frame.InnerBackdropInA:SetDuration(INNER_FADE_IN); frame.InnerBackdropInA:SetSmoothing("OUT")
    innerIn:SetToFinalAlpha(true)
    innerIn:SetScript("OnPlay", function() inner:Show() end)
    frame.InnerBackdropIn = innerIn
    local innerOut = inner:CreateAnimationGroup()
    frame.InnerBackdropOutA = innerOut:CreateAnimation("Alpha")
    frame.InnerBackdropOutA:SetToAlpha(0); frame.InnerBackdropOutA:SetDuration(INNER_FADE_OUT); frame.InnerBackdropOutA:SetSmoothing("IN")
    innerOut:SetToFinalAlpha(true)
    innerOut:SetScript("OnFinished", function() inner:Hide() end)
    frame.InnerBackdropOut = innerOut

    -- Unified end-fade: fades the WHOLE centre as one group in lockstep with FlourishTextOut so the parts never fade at different times (the social-toast bug); SetToFinalAlpha holds it at 0 until _ExitEvent resets it.
    local cfo = frame.Center:CreateAnimationGroup()
    local cfoA = cfo:CreateAnimation("Alpha")
    cfoA:SetFromAlpha(1); cfoA:SetToAlpha(0); cfoA:SetDuration(0.5)   -- == FlourishTextOut + queue FADE
    cfo:SetToFinalAlpha(true)
    frame.CenterFadeOut = cfo

    -- Social toast's own icon (BN logo / game / invite), captured from the suppressed toast and shown here.
    local social = frame.Center:CreateTexture(nil, "ARTWORK")
    social:SetPoint("CENTER")
    social:SetSize(BASE_SIZE * SOCIAL_ICON_RATIO, BASE_SIZE * SOCIAL_ICON_RATIO)
    social:Hide()
    frame.SocialIcon = social

    -- Loot reel: the dropped item's icon, circular-masked to fill the centre, on OVERLAY above the glow so it stays crisp through the per-item quality burst.
    local loot = frame.Center:CreateTexture(nil, "OVERLAY", nil, 3)
    loot:SetPoint("CENTER")
    loot:SetSize(BASE_SIZE * LOOT_ICON_RATIO, BASE_SIZE * LOOT_ICON_RATIO)
    loot:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- trim the default icon border before the circular crop
    loot:Hide()
    frame.LootIcon = loot
    -- Circular alpha mask crops the icon to a disc; it binds to the texture object so it survives the per-item SetTexture swaps.
    local lootMask = frame.Center:CreateMaskTexture()
    lootMask:SetAllPoints(loot)
    lootMask:SetTexture(LOOT_MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    loot:AddMaskTexture(lootMask)
    frame.LootMask = lootMask
    -- Count tucked inside the disc (the square's corner is masked away, so it can't sit there).
    local lootCount = frame.Center:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    lootCount:SetDrawLayer("OVERLAY", 7)
    lootCount:SetPoint("BOTTOMRIGHT", loot, "BOTTOMRIGHT", -BASE_SIZE * 0.13, BASE_SIZE * 0.10)
    lootCount:Hide()
    frame.LootCount = lootCount

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

    -- Generic celebration burst (level-up / renown / etc.): a tinted atlas that pops in and fades.
    local burst = frame.Center:CreateTexture(nil, "OVERLAY", nil, 2)
    burst:SetBlendMode("ADD")
    burst:SetPoint("CENTER")
    burst:SetSize(BASE_SIZE, BASE_SIZE)
    burst:Hide()
    local burstAnim = burst:CreateAnimationGroup()
    local bScale = burstAnim:CreateAnimation("Scale")
    bScale:SetScaleFrom(0.25, 0.25); bScale:SetScaleTo(1.7, 1.7); bScale:SetOrigin("CENTER", 0, 0)
    bScale:SetDuration(0.9); bScale:SetSmoothing("OUT")
    local bRot = burstAnim:CreateAnimation("Rotation")
    bRot:SetDegrees(40); bRot:SetOrigin("CENTER", 0, 0); bRot:SetDuration(0.9); bRot:SetSmoothing("OUT")
    local bIn = burstAnim:CreateAnimation("Alpha"); bIn:SetFromAlpha(0); bIn:SetToAlpha(1); bIn:SetDuration(0.13)
    local bOut = burstAnim:CreateAnimation("Alpha"); bOut:SetStartDelay(0.30); bOut:SetFromAlpha(1); bOut:SetToAlpha(0); bOut:SetDuration(0.6)
    burstAnim:SetScript("OnPlay", function() burst:Show() end)
    burstAnim:SetScript("OnFinished", function() burst:Hide() end)
    frame.BurstFX = burst
    frame.BurstFXAnim = burstAnim

    -- Blizzard's authentic unlock FX flipbook on top of the glow.
    local fx = frame.Center:CreateTexture(nil, "OVERLAY", nil, 2)
    fx:SetAtlas(VAULT_FX_ATLAS)
    fx:SetSize(VAULT_FX_W, VAULT_FX_H)
    fx:SetPoint("CENTER", VAULT_FX_OFFSET_X, VAULT_FX_OFFSET_Y)
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
    frame.FlourishFlip = flip   -- re-pointed to the unlock / upgrade sheet per flourish

    -- A separate static texture holds the final frame during the linger: the FlipBook reverts the flipbook texture's texcoords after OnFinished, so pinning it there gets overwritten.
    local fxFinal = frame.Center:CreateTexture(nil, "OVERLAY", nil, 2)
    fxFinal:SetAtlas(VAULT_FX_ATLAS)
    fxFinal:SetSize(VAULT_FX_W, VAULT_FX_H)
    fxFinal:SetPoint("CENTER", VAULT_FX_OFFSET_X, VAULT_FX_OFFSET_Y)
    fxFinal:Hide()
    frame.FlourishFXFinal = fxFinal

    -- New-mail flipbook (looped while the toast shows, stopped by a timer in PlayMailFlourish).
    local mail = frame.Center:CreateTexture(nil, "OVERLAY", nil, 2)
    mail:SetAtlas(MAIL_FX_ATLAS)
    mail:SetSize(MAIL_FX_SIZE, MAIL_FX_SIZE)
    mail:SetPoint("CENTER")
    mail:Hide()
    local mailAnim = mail:CreateAnimationGroup()
    mailAnim:SetLooping("REPEAT")
    local mailFlip = mailAnim:CreateAnimation("FlipBook")
    mailFlip:SetDuration(MAIL_FX_DURATION)
    mailFlip:SetFlipBookRows(MAIL_FX_ROWS)
    mailFlip:SetFlipBookColumns(MAIL_FX_COLS)
    mailFlip:SetFlipBookFrames(MAIL_FX_FRAMES)
    mailFlip:SetFlipBookFrameWidth(0)
    mailFlip:SetFlipBookFrameHeight(0)
    frame.MailFX = mail
    frame.MailFXAnim = mailAnim

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
    -- Fade-in holds at full alpha; the queue owns when the text leaves (FlourishTextOut, played only when the run idles out).
    local textIn = text:CreateAnimationGroup()
    local tIn = textIn:CreateAnimation("Alpha")
    tIn:SetFromAlpha(0); tIn:SetToAlpha(1); tIn:SetDuration(0.3)
    textIn:SetToFinalAlpha(true)
    textIn:SetScript("OnPlay", function() text:Show() end)
    local textOut = text:CreateAnimationGroup()
    local tOut = textOut:CreateAnimation("Alpha")
    tOut:SetFromAlpha(1); tOut:SetToAlpha(0); tOut:SetDuration(0.5)
    textOut:SetToFinalAlpha(true)
    textOut:SetScript("OnFinished", function() text:Hide() end)
    text.Title = title
    text.SubTitle = sub
    frame.FlourishText = text
    frame.FlourishTextAnim = textIn
    frame.FlourishTextOut = textOut

    local num = frame.Center:CreateFontString(nil, "ARTWORK")
    num:SetPoint("CENTER")
    num:SetJustifyH("CENTER")
    num:Hide()
    frame.CenterNumber = num

    self:_BuildLevelUpFX(frame)
    self:_BuildShatterFX(frame)
    self:ApplyFlourishFont()
end

function Plugin:_BuildShatterFX(frame)
    local shards = frame.Center:CreateTexture(nil, "OVERLAY", nil, 4)
    shards:SetTexture(SHARDBURST_TEX, nil, nil, "TRILINEAR"); shards:SetBlendMode("ADD")
    shards:SetSize(BASE_SIZE * 1.7, BASE_SIZE * 1.7); shards:SetPoint("CENTER"); shards:Hide()
    local sa = shards:CreateAnimationGroup()
    local s1 = sa:CreateAnimation("Scale"); s1:SetScaleFrom(0.30, 0.30); s1:SetScaleTo(1.85, 1.85); s1:SetOrigin("CENTER", 0, 0); s1:SetDuration(0.7); s1:SetSmoothing("OUT")
    local s2 = sa:CreateAnimation("Alpha"); s2:SetFromAlpha(0); s2:SetToAlpha(1); s2:SetDuration(0.07)
    local s3 = sa:CreateAnimation("Alpha"); s3:SetStartDelay(0.10); s3:SetFromAlpha(1); s3:SetToAlpha(0); s3:SetDuration(0.55)
    sa:SetScript("OnPlay", function() shards:Show() end); sa:SetScript("OnFinished", function() shards:Hide() end)
    frame.Shards, frame.ShardsAnim = shards, sa
end

function Plugin:_BuildLevelUpFX(frame)
    local center, content = frame.Center, frame.Content

    -- radiating rays (the authentic level-up sheet), additive gold, expand + slow counter-spin + fade
    local rays = center:CreateTexture(nil, "OVERLAY", nil, 1)
    rays:SetAtlas("aftlevelup-lines1", true); rays:SetBlendMode("ADD")
    rays:SetSize(BASE_SIZE * 1.85, BASE_SIZE * 1.85); rays:SetPoint("CENTER"); rays:Hide()
    local ra = rays:CreateAnimationGroup()
    local r1 = ra:CreateAnimation("Scale"); r1:SetScaleFrom(0.45, 0.45); r1:SetScaleTo(1.5, 1.5); r1:SetOrigin("CENTER", 0, 0); r1:SetDuration(0.95); r1:SetSmoothing("OUT")
    local r2 = ra:CreateAnimation("Rotation"); r2:SetDegrees(-22); r2:SetOrigin("CENTER", 0, 0); r2:SetDuration(0.95)
    local r3 = ra:CreateAnimation("Alpha"); r3:SetFromAlpha(0); r3:SetToAlpha(0.85); r3:SetDuration(0.16)
    local r4 = ra:CreateAnimation("Alpha"); r4:SetStartDelay(0.32); r4:SetFromAlpha(0.85); r4:SetToAlpha(0); r4:SetDuration(0.55)
    ra:SetScript("OnPlay", function() rays:Show() end); ra:SetScript("OnFinished", function() rays:Hide() end)
    frame.LevelRays, frame.LevelRaysAnim = rays, ra

    -- the OLD level / renown number, stomped out when the new one lands; created before LevelNumber so the new number draws on top of it.
    local oldNum = center:CreateFontString(nil, "OVERLAY")
    oldNum:SetPoint("CENTER"); oldNum:SetJustifyH("CENTER"); oldNum:Hide()
    frame.OldNumber = oldNum
    local oldIn = oldNum:CreateAnimationGroup()
    local oldInA = oldIn:CreateAnimation("Alpha"); oldInA:SetFromAlpha(0); oldInA:SetToAlpha(1); oldInA:SetDuration(0.18)
    oldIn:SetToFinalAlpha(true)
    oldIn:SetScript("OnPlay", function() oldNum:Show() end)
    frame.OldNumberInAnim = oldIn
    local oldOut = oldNum:CreateAnimationGroup()
    local oo1 = oldOut:CreateAnimation("Scale"); oo1:SetScaleFrom(1, 1); oo1:SetScaleTo(0.35, 0.35); oo1:SetOrigin("CENTER", 0, 0); oo1:SetDuration(0.22); oo1:SetSmoothing("IN")
    local oo2 = oldOut:CreateAnimation("Translation"); oo2:SetOffset(0, -BASE_SIZE * 0.10); oo2:SetDuration(0.22); oo2:SetSmoothing("IN")
    local oo3 = oldOut:CreateAnimation("Alpha"); oo3:SetFromAlpha(1); oo3:SetToAlpha(0); oo3:SetDuration(0.22)
    oldOut:SetScript("OnFinished", function() oldNum:Hide(); oldNum:SetScale(1) end)
    frame.OldNumberOutAnim = oldOut

    -- the big milestone number, anchored dead-centre; _PlayMilestoneNumber's manual tween offsets and scales it from there.
    local lvl = center:CreateFontString(nil, "OVERLAY")
    lvl:SetPoint("CENTER"); lvl:SetJustifyH("CENTER"); lvl:Hide()
    frame.LevelNumber = lvl

    -- up-arrow rising above the number, fading as it climbs
    local arrow = center:CreateTexture(nil, "OVERLAY", nil, 5)
    arrow:SetAtlas("npe_arrowupglow", true); arrow:SetBlendMode("ADD")
    arrow:SetSize(BASE_SIZE * 0.40, BASE_SIZE * 0.52); arrow:SetPoint("CENTER", 0, -BASE_SIZE * 0.06); arrow:Hide()
    local aa = arrow:CreateAnimationGroup()
    local a1 = aa:CreateAnimation("Translation"); a1:SetOffset(0, BASE_SIZE * 0.40); a1:SetDuration(0.9); a1:SetSmoothing("OUT")
    local a2 = aa:CreateAnimation("Alpha"); a2:SetFromAlpha(0); a2:SetToAlpha(1); a2:SetDuration(0.16)
    local a3 = aa:CreateAnimation("Alpha"); a3:SetStartDelay(0.42); a3:SetFromAlpha(1); a3:SetToAlpha(0); a3:SetDuration(0.46)
    aa:SetScript("OnPlay", function() arrow:Show() end); aa:SetScript("OnFinished", function() arrow:Hide() end)
    frame.LevelArrow, frame.LevelArrowAnim = arrow, aa

    -- gold ring flash over the ring (reuses the white fill ring; the metal border art can't tint gold)
    local bflash = center:CreateTexture(nil, "BACKGROUND", nil, 4)
    bflash:SetTexture(BACKDROP_TEX, nil, nil, "TRILINEAR"); bflash:SetBlendMode("ADD")
    bflash:SetSize(BASE_SIZE, BASE_SIZE); bflash:SetPoint("CENTER"); bflash:SetVertexColor(1.0, 0.84, 0.35); bflash:Hide()
    local bf = bflash:CreateAnimationGroup()
    local bf1 = bf:CreateAnimation("Alpha"); bf1:SetFromAlpha(0); bf1:SetToAlpha(1); bf1:SetDuration(0.08)
    local bf2 = bf:CreateAnimation("Alpha"); bf2:SetStartDelay(0.08); bf2:SetFromAlpha(1); bf2:SetToAlpha(0); bf2:SetDuration(0.55)
    bf:SetScript("OnPlay", function() bflash:Show() end); bf:SetScript("OnFinished", function() bflash:Hide() end)
    frame.BorderFlash, frame.BorderFlashAnim = bflash, bf

    -- whole-orb shake: a Translation oscillation on the content wrapper whose deltas sum to ~0 so it returns to rest.
    local shake = content:CreateAnimationGroup()
    local deltas = { {8, 5}, {-15, -9}, {12, 7}, {-9, -5}, {5, 3}, {-1, -1} }
    for i, dxy in ipairs(deltas) do
        local seg = shake:CreateAnimation("Translation")
        seg:SetOffset(dxy[1], dxy[2]); seg:SetDuration(0.045); seg:SetOrder(i)
    end
    frame.WidgetShake = shake
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
    if self.frame.CenterNumber then
        Orbit.Skin:SkinText(self.frame.CenterNumber, { font = gs.Font, textSize = CENTER_NUMBER_SIZE })
        self.frame.CenterNumber:SetTextColor(0.95, 0.95, 0.95)
    end
    if self.frame.LevelNumber then
        Orbit.Skin:SkinText(self.frame.LevelNumber, { font = gs.Font, textSize = CENTER_NUMBER_SIZE })
        self.frame.LevelNumber:SetTextColor(1.0, 0.87, 0.42)
    end
    if self.frame.OldNumber then
        Orbit.Skin:SkinText(self.frame.OldNumber, { font = gs.Font, textSize = CENTER_NUMBER_SIZE })
        self.frame.OldNumber:SetTextColor(0.7, 0.7, 0.7)
    end
end

-- Optional idle centre numeral: record.numeral (the bare renown number, not "Renown 11") falling back to record.level.
function Plugin:_UpdateNumeral(record)
    local num = self.frame.CenterNumber
    if not num or self._durabilityWarn then return end   -- the durability % owns the centre when low
    local on = self:GetSetting(SYSTEM_ID, "ShowCenterNumber") and self._event == nil
    local val = record.numeral or record.level
    if on and val and val ~= "" and val ~= 0 then
        num:SetText(tostring(val))
        num:SetTextColor(0.95, 0.95, 0.95)
        num:Show()
    else
        num:Hide()
    end
end

-- Shared: retint + replay the glow underlay.
function Plugin:_PlayGlow(color)
    local glow = self.frame.Flourish
    color = color or FLOURISH_COLOR
    glow:SetVertexColor(color.r, color.g, color.b)
    self.frame.FlourishAnim:Stop()
    self.frame.FlourishAnim:Play()
end

function Plugin:_ShowFlourishText(title, subtitle, titleColor)
    local text = self.frame.FlourishText
    text.Title:SetText(title or "")
    local tc = titleColor or FLOURISH_TITLE_COLOR
    text.Title:SetTextColor(tc.r, tc.g, tc.b)
    text.SubTitle:SetText(subtitle or "")
    local hasSub = subtitle and subtitle ~= ""

    local cx = self.frame:GetCenter()
    local growRight = not cx or (cx * self.frame:GetEffectiveScale()) <= (UIParent:GetWidth() * UIParent:GetEffectiveScale() / 2)
    local edge = growRight and "LEFT" or "RIGHT"

    text:ClearAllPoints()
    if growRight then text:SetPoint("LEFT", self.frame, "RIGHT", FLOURISH_TEXT_GAP, 0)
    else text:SetPoint("RIGHT", self.frame, "LEFT", -FLOURISH_TEXT_GAP, 0) end

    text.Title:ClearAllPoints()
    text.Title:SetPoint((hasSub and "BOTTOM" or "") .. edge, text, edge, 0, hasSub and 2 or 0)
    text.Title:SetJustifyH(edge)
    text.SubTitle:ClearAllPoints()
    text.SubTitle:SetPoint("TOP" .. edge, text.Title, "BOTTOM" .. edge, 0, -4)
    text.SubTitle:SetJustifyH(edge)
    text.SubTitle:SetShown(hasSub)

    self.frame.FlourishTextOut:Stop()
    self.frame.FlourishTextAnim:Stop()
    if (title and title ~= "") or hasSub then
        self.frame.FlourishTextAnim:Play()
    end
end

-- [ STATE: TRANSIENT EVENTS ]------------------------------------------------------------------------
function Plugin:_ClearCenterFX()
    local frame = self.frame
    if self._mailTimer then self._mailTimer:Cancel(); self._mailTimer = nil end
    frame.MailFXAnim:Stop(); frame.MailFX:Hide()
    frame.FlourishFXAnim:Stop(); frame.FlourishFX:Hide()
    frame.FlourishFXFinal:Hide()
    frame.BurstFXAnim:Stop(); frame.BurstFX:Hide()
    if frame.Shards then frame.ShardsAnim:Stop(); frame.Shards:Hide() end
    frame.SocialIcon:Hide()
    frame.LootIcon:Hide()
    frame.LootCount:Hide()
    if frame.LevelNumber then
        frame.LevelRaysAnim:Stop(); frame.LevelRays:Hide()
        frame.LevelArrowAnim:Stop(); frame.LevelArrow:Hide()
        if self._lvlNumDriver then self._lvlNumDriver:Hide() end
        frame.LevelNumber:SetScale(1); frame.LevelNumber:Hide()
        frame.BorderFlashAnim:Stop(); frame.BorderFlash:Hide()
        frame.WidgetShake:Stop()
        frame.OldNumberInAnim:Stop(); frame.OldNumberOutAnim:Stop()
        frame.OldNumber:SetScale(1); frame.OldNumber:Hide()
        self._hasOldNumber = false
    end
    -- Idle-centre layers yield to a flourish.
    if frame.CrackedMetal then frame.CrackedMetalPulse:Stop(); frame.CrackedMetal:Hide() end
    if frame.CenterNumber then frame.CenterNumber:Hide() end
    -- Side text is parented to the orb (not Center) so CenterFadeOut never touches it — reset it here so a following flourish without side text doesn't keep the prior one's.
    frame.FlourishTextAnim:Stop(); frame.FlourishTextOut:Stop()
    frame.FlourishText:Hide(); frame.FlourishText:SetAlpha(0)
end

function Plugin:_EnterEvent(name)
    self._event = name
    self.frame.CenterFadeOut:Stop(); self.frame.Center:SetAlpha(1)   -- clear any prior end-fade
    self:_CancelLootReel(name)   -- a non-loot flourish interrupting the reel drops it; a loot one keeps its queue
    self:_ClearCenterFX()
    self:_RefreshInner()
    self:RevealOrb()
end

function Plugin:_ExitEvent()
    self._event = nil
    local frame = self.frame
    -- CenterFadeOut already faded the vignette out; snap it clean so the alpha reset below doesn't pop it back, and mark it hidden so _RefreshInner (via UpdateBar) no-ops.
    frame.CenterFadeOut:Stop()
    frame.InnerBackdropIn:Stop(); frame.InnerBackdropOut:Stop()
    frame.InnerBackdrop:Hide(); frame.InnerBackdrop:SetAlpha(0)
    self._innerShown = false
    self:_ClearCenterFX()
    frame.Center:SetAlpha(1)     -- reset after the group fade; children are hidden so no flash
    self:UpdateBar()             -- re-show the durability cracked-metal if it was suppressed during the flourish
    self:ConcealOrb()
end

-- Show the vignette while a flourish owns the centre; only re-fade on a state change so frequent UpdateBar calls don't restart the animation.
function Plugin:_RefreshInner()
    local want = (self._event ~= nil) and true or false
    if want == self._innerShown then return end
    self._innerShown = want
    self:_FadeInner(want)
end

-- Fade the inner-border vignette in/out, from its current alpha so it cross-fades smoothly rather than snapping.
function Plugin:_FadeInner(show)
    local frame = self.frame
    local cur = frame.InnerBackdrop:GetAlpha()
    if show then
        frame.InnerBackdropOut:Stop()
        frame.InnerBackdropInA:SetFromAlpha(cur)
        frame.InnerBackdropIn:Play()
    else
        frame.InnerBackdropIn:Stop()
        frame.InnerBackdropOutA:SetFromAlpha(cur)
        frame.InnerBackdropOut:Play()
    end
end

-- Public Play* entry points enqueue a request; the queue calls the matching _Render* after _EnterEvent clears the centre, and owns the hold/linger timing.
function Plugin:PlayVaultFlourish(title, subtitle, upgrade)
    self:Enqueue({ kind = "vault", render = function(p) p:_RenderVault(title, subtitle, upgrade) end })
end
function Plugin:_RenderVault(title, subtitle, upgrade)
    local frame = self.frame
    self:_PlayGlow(FLOURISH_COLOR)
    local atlas = upgrade and VAULT_UP_FX_ATLAS or VAULT_FX_ATLAS
    frame.FlourishFX:SetAtlas(atlas)
    frame.FlourishFXFinal:SetAtlas(atlas)
    frame.FlourishFlip:SetFlipBookRows(upgrade and VAULT_UP_ROWS or VAULT_FX_ROWS)
    frame.FlourishFlip:SetFlipBookColumns(upgrade and VAULT_UP_COLS or VAULT_FX_COLS)
    frame.FlourishFlip:SetFlipBookFrames(upgrade and VAULT_UP_FRAMES or VAULT_FX_FRAMES)
    frame.FlourishFlip:SetDuration(upgrade and VAULT_UP_DURATION or VAULT_FX_DURATION)
    frame.FlourishFX:SetAlpha(1)
    frame.FlourishFXAnim:Play()
    frame.BorderFlash:SetVertexColor(FLOURISH_COLOR.r, FLOURISH_COLOR.g, FLOURISH_COLOR.b)
    frame.BorderFlashAnim:Stop(); frame.BorderFlashAnim:Play()
    self:_RingImpact()
    frame.WidgetShake:Stop(); frame.WidgetShake:Play()
    self:_ShowFlourishText(title, subtitle)
end

-- SocialToast.lua calls this on a suppressed social toast: glow + the toast's own icon in the centre + text.
function Plugin:PlaySocialFlourish(title, subtitle, iconTex, coords)
    self:Enqueue({ kind = "social", render = function(p) p:_RenderSocial(title, subtitle, iconTex, coords) end })
end
function Plugin:_RenderSocial(title, subtitle, iconTex, coords)
    local frame = self.frame
    self:_PlayGlow(SOCIAL_COLOR)
    if iconTex then
        frame.SocialIcon:SetTexture(iconTex)
        if coords then frame.SocialIcon:SetTexCoord(unpack(coords)) else frame.SocialIcon:SetTexCoord(0, 1, 0, 1) end
        frame.SocialIcon:Show()
    end
    self:_ShowFlourishText(title, subtitle)
end

-- Mail.lua calls this on new mail: glow + looping mail flipbook + text ("New Mail" / "From ...").
function Plugin:PlayMailFlourish(title, subtitle)
    self:Enqueue({ kind = "mail", render = function(p) p:_RenderMail(title, subtitle) end })
end
function Plugin:_RenderMail(title, subtitle)
    local frame = self.frame
    self:_PlayGlow(MAIL_COLOR)
    frame.MailFX:Show()
    frame.MailFXAnim:Restart()   -- loops until the queue clears the centre (_ClearCenterFX stops it)
    self:_ShowFlourishText(title, subtitle)
end

-- [ GENERIC FLOURISHES ]-----------------------------------------------------------------------------

-- A disc-masked icon (reuses the loot icon disc) + glow + text — collectibles, recipes, spell, etc.
function Plugin:PlayIconFlourish(icon, color, title, subtitle, coords)
    self:Enqueue({ kind = "icon", render = function(p) p:_RenderIcon(icon, color, title, subtitle, coords) end })
end
function Plugin:_RenderIcon(icon, color, title, subtitle, coords)
    local frame = self.frame
    self:_PlayGlow(color)
    if icon then
        frame.LootIcon:SetTexture(icon)
        if coords then frame.LootIcon:SetTexCoord(unpack(coords)) end   -- else keep the default item-icon trim
        frame.LootIcon:Show()
    end
    self:_ShowFlourishText(title, subtitle, color)
end

-- A tinted celebration burst atlas + glow + text — level-up, renown, etc.
function Plugin:PlayBurst(atlas, color, title, subtitle)
    self:Enqueue({ kind = "burst", render = function(p) p:_RenderBurst(atlas, color, title, subtitle) end })
end
function Plugin:_RenderBurst(atlas, color, title, subtitle)
    local frame = self.frame
    self:_PlayGlow(color)
    if atlas then
        frame.BurstFX:SetAtlas(atlas, true)
        frame.BurstFX:SetSize(BASE_SIZE * 1.3, BASE_SIZE * 1.3)
        frame.BurstFX:SetVertexColor(color.r, color.g, color.b)
        frame.BurstFXAnim:Stop(); frame.BurstFXAnim:Play()
    end
    frame.BorderFlash:SetVertexColor(color.r, color.g, color.b)
    frame.BorderFlashAnim:Stop(); frame.BorderFlashAnim:Play()
    self:_RingImpact()
    frame.WidgetShake:Stop(); frame.WidgetShake:Play()
    self:_ShowFlourishText(title, subtitle, color)
end

function Plugin:PlayLevelUpFlourish(level)
    self:Enqueue({ kind = "levelup", render = function(p) p:_RenderLevelUp(level) end })
end
function Plugin:PlayRenownFlourish(level, faction, oldLevel)
    self:Enqueue({ kind = "renown", render = function(p) p:_RenderRenown(level, faction, oldLevel) end })
end
function Plugin:PlayHonorFlourish(level, oldLevel)
    self:Enqueue({ kind = "honor", render = function(p) p:_RenderHonor(level, oldLevel) end })
end

-- value is the big centre number; color tints the impact set + number; motion is "slam" (level-up) or "grow" (renown); oldValue is the previous number, stomped out when the new one lands.
function Plugin:_RenderMilestone(value, color, motion, sideTitle, oldValue, fx)
    local frame = self.frame
    self._lvlImpactColor = color
    self._lvlShowArrow = fx.arrow   -- the up-arrow is a level-up cue; renown skips it
    -- Prep the impact FX (per-milestone sprites); the slam motion fires them at the number's landing.
    frame.BurstFX:SetAtlas(fx.burst, true)
    frame.BurstFX:SetSize(BASE_SIZE * 1.5, BASE_SIZE * 1.5)
    frame.BurstFX:SetVertexColor(color.r, color.g, color.b)
    frame.LevelRays:SetAtlas(fx.rays, false)   -- keep the size set in _BuildLevelUpFX
    frame.BorderFlash:SetVertexColor(color.r, color.g, color.b)
    frame.LevelNumber:SetTextColor(color.r, color.g, color.b)
    -- The old number fades in, then the new number stomps it out when it lands (_LevelImpact).
    self._hasOldNumber = oldValue ~= nil
    if self._hasOldNumber then
        frame.OldNumber:SetText(tostring(oldValue))
        frame.OldNumber:SetScale(1); frame.OldNumber:SetAlpha(0)
        frame.OldNumberOutAnim:Stop()
        frame.OldNumberInAnim:Stop(); frame.OldNumberInAnim:Play()
    end
    if sideTitle and sideTitle ~= "" then self:_ShowFlourishText(sideTitle, nil, color) end
    self:_PlayMilestoneNumber(value, motion)
end

function Plugin:_RenderLevelUp(level)
    self:_RenderMilestone(level, self.FlourishColors.gold, "slam", nil, level and level - 1, MILESTONE_FX_LEVELUP)
end

function Plugin:_RenderRenown(level, faction, oldLevel)
    self:_RenderMilestone(level, self:GetColor("RepColor", self.FlourishColors.rep), "grow", faction, oldLevel, MILESTONE_FX_RENOWN)
end

-- Honor (PvP) level-up: honor red, the slam motion, the honor level as the big number (no side label), prestige flash + rank glow.
function Plugin:_RenderHonor(level, oldLevel)
    self:_RenderMilestone(level, self:GetColor("HonorColor", HONOR_COLOR), "slam", nil, oldLevel, MILESTONE_FX_HONOR)
end

-- The impact set, fired by the number tween when the new number "lands" (the slam frame for level-up, after the old-number lead for renown), so the old number is stomped out here.
function Plugin:_LevelImpact()
    local frame = self.frame
    if self._hasOldNumber then
        self._hasOldNumber = false
        frame.OldNumberInAnim:Stop()
        frame.OldNumberOutAnim:Stop(); frame.OldNumberOutAnim:Play()
    end
    self:_PlayGlow(self._lvlImpactColor)
    frame.BurstFXAnim:Stop(); frame.BurstFXAnim:Play()
    frame.LevelRaysAnim:Stop(); frame.LevelRaysAnim:Play()
    if self._lvlShowArrow then frame.LevelArrowAnim:Stop(); frame.LevelArrowAnim:Play() end
    frame.BorderFlashAnim:Stop(); frame.BorderFlashAnim:Play()
    self:_RingImpact()
    frame.WidgetShake:Stop(); frame.WidgetShake:Play()
end

-- Durability break, fired once on each downward crossing of 40% / 20% (FillModes._UpdateCrackedMetal): shrapnel + the shared impact set, with the inner cracked circle forming mid-blast.
function Plugin:PlayShatterFlourish(broken)
    self:Enqueue({ kind = "shatter", render = function(p) p:_RenderShatter(broken) end })
end
function Plugin:_RenderShatter(broken)
    local frame = self.frame
    local color = broken and DURA_BROKEN_COLOR or DURA_DAMAGED_COLOR
    self:_PlayGlow(color)
    frame.Shards:SetVertexColor(color.r, color.g, color.b)
    frame.ShardsAnim:Stop(); frame.ShardsAnim:Play()
    frame.BorderFlash:SetVertexColor(color.r, color.g, color.b)
    frame.BorderFlashAnim:Stop(); frame.BorderFlashAnim:Play()
    self:_RingImpact()
    frame.WidgetShake:Stop(); frame.WidgetShake:Play()
    -- The inner cracked circle forms mid-explosion: reveal the persistent warning partway through the burst, as if the blast leaves it behind.
    C_Timer.After(SHATTER_FORM_DELAY, function()
        if self._event ~= "shatter" then return end   -- a later flourish took over the centre
        self:_RandomizeCrackedMetal()
        self:_ShowCrackedWarning(broken, self:_DurabilityPct())
        self:_SetRingCrack(broken and 2 or 1)   -- also crack the ring (so /orbitshatter previews it)
    end)
end

-- Burst weight: a scale punch-bounce on Content + a decaying rotational shake on the ring art, hand-tweened so it overshoots and settles rather than easing flatly.
function Plugin:_RingImpact()
    local frame = self.frame
    self._impactT = 0
    if not self._impactDriver then
        local d = CreateFrame("Frame", nil, UIParent)
        d:Hide()
        d:SetScript("OnUpdate", function(driver, elapsed)
            self._impactT = self._impactT + elapsed
            local t = self._impactT / IMPACT_DUR
            -- The Rotate-Slide reveal owns the ring textures' rotation, so in that mode punch only the Content scale and the two drivers never fight.
            local skipRot = self:_RotateRevealOwnsRing()
            if t >= 1 then
                frame.Content:SetScale(1)
                if not skipRot then
                    frame.Track:SetRotation(0); frame.BackdropRing:SetRotation(0); frame.Border:SetRotation(0)
                    frame.Fill:SetRotation(frame._fillRotation); frame.RestedFill:SetRotation(frame._fillRotation)
                end
                driver:Hide()
                return
            end
            local decay = math.exp(-3.0 * t)
            frame.Content:SetScale(1 + 0.21 * math.sin(t * math.pi * 3) * decay)   -- punch, bounce, settle
            if not skipRot then
                local sh = math.rad(13) * math.sin(t * 38) * decay                 -- decaying rotational shake
                frame.Track:SetRotation(sh); frame.BackdropRing:SetRotation(sh); frame.Border:SetRotation(sh)
                frame.Fill:SetRotation(frame._fillRotation + sh); frame.RestedFill:SetRotation(frame._fillRotation + sh)
            end
        end)
        self._impactDriver = d
    end
    self._impactDriver:Show()
end

-- The milestone number's choreography (manual tween): "slam" (level-up) detonates _LevelImpact at the landing (LVLNUM_LAND); "grow" (renown) scales up from small with the impact firing immediately.
local function EaseOut(p) return 1 - (1 - p) * (1 - p) end
local function EaseIn(p) return p * p end

function Plugin:_PlayMilestoneNumber(value, motion)
    local frame = self.frame
    local lvl = frame.LevelNumber
    lvl:SetText(tostring(value))
    lvl:SetPoint("CENTER"); lvl:SetScale(1); lvl:SetAlpha(0); lvl:Show()
    self._lvlNumT = 0
    self._lvlNumMotion = motion
    self._lvlImpactFired = false   -- slam fires at the landing; grow fires after the old-number lead (below)
    -- Snapshot the grow lead ONCE: _LevelImpact clears _hasOldNumber, so re-reading it per-frame would collapse the lead to 0 and skip the grow-in.
    self._lvlLead = (motion == "grow" and self._hasOldNumber) and MILESTONE_GROW_LEAD or 0
    if not self._lvlNumDriver then
        local d = CreateFrame("Frame", nil, UIParent)
        d:Hide()
        d:SetScript("OnUpdate", function(driver, elapsed)
            self._lvlNumT = self._lvlNumT + elapsed
            local t = self._lvlNumT
            if self._lvlNumMotion == "grow" then                      -- hold (old number shows), burst, grow in
                local lead = self._lvlLead
                if t < lead then lvl:SetAlpha(0); return end          -- the old number holds before the new bursts in
                if not self._lvlImpactFired then                      -- the new number lands now: burst + stomp the old
                    self._lvlImpactFired = true
                    self:_LevelImpact()
                end
                local g = t - lead
                local scale, alpha = LVLNUM_GROW_PEAK, 1
                if g < LVLGROW_IN then
                    local p = g / LVLGROW_IN
                    scale = LVLGROW_FROM + (LVLNUM_GROW_PEAK - LVLGROW_FROM) * EaseOut(p)
                    alpha = math.min(1, g / 0.18)
                elseif g < LVLGROW_HOLD then
                    scale = LVLNUM_GROW_PEAK
                elseif g < LVLGROW_FADE then
                    local p = (g - LVLGROW_HOLD) / (LVLGROW_FADE - LVLGROW_HOLD)
                    scale = LVLNUM_GROW_PEAK + (LVLNUM_GROW_DRIFT - LVLNUM_GROW_PEAK) * p
                    alpha = 1 - p
                else
                    lvl:SetScale(1); lvl:SetAlpha(0); lvl:Hide(); driver:Hide(); return
                end
                lvl:SetPoint("CENTER", 0, 0)
                lvl:SetScale(scale); lvl:SetAlpha(alpha)
                return
            end
            if not self._lvlImpactFired and t >= LVLNUM_LAND then     -- slam frame: detonate the flash + impact
                self._lvlImpactFired = true
                self:_LevelImpact()
            end
            local yOff, scale, alpha = 0, 1, 1
            if t < LVLNUM_RISE then                                   -- rise + fade in toward the top
                local p = t / LVLNUM_RISE
                yOff = LVLNUM_RISE_UP * EaseOut(p)
                alpha = math.min(1, t / 0.16)
            elseif t < LVLNUM_LAND then                              -- solid drop, dipping just below centre
                local p = (t - LVLNUM_RISE) / (LVLNUM_LAND - LVLNUM_RISE)
                yOff = LVLNUM_RISE_UP + (-LVLNUM_OVERSHOOT - LVLNUM_RISE_UP) * EaseIn(p)
            elseif t < LVLNUM_GROW then                              -- settle to centre + grow punch
                local p = (t - LVLNUM_LAND) / (LVLNUM_GROW - LVLNUM_LAND)
                yOff = -LVLNUM_OVERSHOOT * (1 - EaseOut(p))
                scale = 1 + (LVLNUM_GROW_PEAK - 1) * EaseOut(p)
            elseif t < LVLNUM_FADE then                              -- dissolve while drifting larger
                local p = (t - LVLNUM_GROW) / (LVLNUM_FADE - LVLNUM_GROW)
                scale = LVLNUM_GROW_PEAK + (LVLNUM_GROW_DRIFT - LVLNUM_GROW_PEAK) * p
                alpha = 1 - p
            else
                lvl:SetScale(1); lvl:SetAlpha(0); lvl:Hide()
                driver:Hide()
                return
            end
            lvl:SetPoint("CENTER", 0, yOff)
            lvl:SetScale(scale)
            lvl:SetAlpha(alpha)
        end)
        self._lvlNumDriver = d
    end
    self._lvlNumDriver:Show()
end

-- Hand off to the held final frame: copy the flipbook's texcoords here, before the FlipBook reverts them, so the held frame matches it with no jump.
function Plugin:HoldVaultFX()
    local frame = self.frame
    if not frame then return end
    frame.FlourishFXFinal:SetTexCoord(frame.FlourishFX:GetTexCoord())
    frame.FlourishFX:Hide()
    frame.FlourishFXFinal:SetAlpha(1)
    frame.FlourishFXFinal:Show()
end

-- [ INTERACTION ]------------------------------------------------------------------------------------
function Plugin:SetupInteraction()
    local frame = self.frame
    frame:EnableMouse(true)
    frame:HookScript("OnEnter", function()
        self._hovered = true
        self:UpdateBar()
        self:RefreshTooltip()
        self:RevealOrb()
    end)
    frame:HookScript("OnLeave", function()
        self._hovered = false
        self:UpdateBar()
        GameTooltip:Hide()
        self:ConcealOrb()
    end)
    -- Left-click opens the panel the orb shows (or the Great Vault during a vault flourish); right-click opens the source menu.
    frame:HookScript("OnMouseUp", function(_, button)
        if Orbit:IsEditMode() then return end
        if button == "RightButton" then self:OpenSourceMenu(); return end
        if button ~= "LeftButton" then return end
        if self._event == "vault" then self:OpenGreatVault()
        elseif not self._event then self:OpenForMode() end   -- no flourish: open the panel the orb shows
    end)
end

function Plugin:OpenGreatVault()
    if WeeklyRewards_ShowUI then WeeklyRewards_ShowUI() end
end

function Plugin:OpenForMode()
    local mode = self.record and self.record.mode
    if mode == MODE_HONOR then
        if TogglePVPUI then TogglePVPUI() end
    elseif mode == MODE_CURRENCY then
        if ToggleCharacter then ToggleCharacter("TokenFrame") end
    elseif ToggleCharacter then
        ToggleCharacter("PaperDollFrame")
    end
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
-- A source key maps to a concrete mode; "auto" is xp while leveling, reputation once capped (xp disabled / max level).
function Plugin:_ResolveSource(source)
    if source == "xp" then return MODE_XP
    elseif source == "rep" then return MODE_REP
    elseif source == "honor" then return MODE_HONOR
    elseif source == "currency" then return MODE_CURRENCY end
    local level = UnitLevel("player")
    local xpDisabled = IsXPUserDisabled and IsXPUserDisabled() or false
    if level and level < GetMaxPlayerLevel() and not xpDisabled then return MODE_XP end
    return MODE_REP
end

-- Primary source at rest; hover+Shift swaps to the secondary (re-resolved on hover and MODIFIER_STATE_CHANGED so Shift flips it live), stashing the active slot's currency id for CurrencyRecord.
function Plugin:ResolveMode()
    local source, currencyKey
    local secondary = self:GetSetting(SYSTEM_ID, "SecondarySource")
    if self._hovered and IsShiftKeyDown() and secondary and secondary ~= "none" then
        source, currencyKey = secondary, "SecondaryCurrencyID"
    else
        source, currencyKey = self:GetSetting(SYSTEM_ID, "PrimarySource") or "auto", "PrimaryCurrencyID"
    end
    self._activeCurrencyID = source == "currency" and self:GetSetting(SYSTEM_ID, currencyKey) or nil
    return self:_ResolveSource(source)
end

-- Each mode returns the same record shape {mode,name,level,current,max,color[,rested]}.
function Plugin:BuildRecord()
    local mode = self:ResolveMode()
    if mode == MODE_HONOR then return self:HonorRecord()
    elseif mode == MODE_XP then return self:XPRecord()
    elseif mode == MODE_CURRENCY then return self:CurrencyRecord() end
    return self:BuildRepRecord()
end

function Plugin:HonorRecord()
    return { mode = MODE_HONOR, name = L.PLU_HONOR_NAME, level = UnitHonorLevel("player") or 0,
             current = UnitHonor("player"), max = UnitHonorMax("player"),
             color = self:GetColor("HonorColor", HONOR_COLOR) }
end

function Plugin:XPRecord()
    local rested = GetXPExhaustion()
    if issecretvalue(rested) then rested = nil end   -- xp goes secret in encounters; drop rested then
    return { mode = MODE_XP, name = L.PLU_XP_NAME, level = UnitLevel("player") or 0,
             current = UnitXP("player"), max = UnitXPMax("player"), rested = rested,
             color = self:GetColor("XPColor", XP_COLOR) }
end

-- The "auto" primary, and CurrencyRecord's fallback when nothing's tracked: xp while leveling, else rep.
function Plugin:_AutoRecord()
    if self:_ResolveSource("auto") == MODE_XP then return self:XPRecord() end
    return self:BuildRepRecord()
end

-- Reputation spans come from plain (non-secret) C_Reputation data, reduced to a 0-based current/max; renown / paragon / standing all share one configurable RepColor.
function Plugin:BuildRepRecord()
    local repColor = self:GetColor("RepColor", REP_COLOR)
    local watched = C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
    if not watched or not watched.factionID or watched.factionID == 0 then
        return { mode = MODE_REP, name = L.PLU_SB_REP_NONE, level = "", current = 0, max = 1, color = repColor }
    end

    local factionID = watched.factionID
    local majorData = C_MajorFactions and C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(factionID)
    if majorData and majorData.renownLevelThreshold and majorData.renownLevelThreshold > 0 then
        return { mode = MODE_REP, name = majorData.name or watched.name,
                 level = L.PLU_REP_RENOWN_F:format(majorData.renownLevel or 0),
                 numeral = majorData.renownLevel or 0,
                 current = majorData.renownReputationEarned or 0, max = majorData.renownLevelThreshold,
                 color = repColor }
    end

    if C_Reputation.IsFactionParagon and C_Reputation.IsFactionParagon(factionID) then
        local value, threshold, _, hasReward = C_Reputation.GetFactionParagonInfo(factionID)
        if value and threshold and threshold > 0 then
            return { mode = MODE_REP, name = watched.name,
                     level = hasReward and L.PLU_REP_PARAGON_READY or L.PLU_REP_PARAGON,
                     current = value % threshold, max = threshold, color = repColor }
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
             color = repColor }
end

-- [ UPDATE ]-----------------------------------------------------------------------------------------
function Plugin:UpdateBar()
    if not self.frame then return end
    local record = self:BuildRecord()
    self.record = record
    self:RenderFill(record)
    self:_UpdateCrackedMetal(record)   -- durability warning (FillModes)
    self:_UpdateNumeral(record)       -- optional idle centre numeral
end

-- Guard the Lua division so a secret current/max holds the last displayed sweep instead of throwing (mirrors StatusBarBase:SetFill).
function Plugin:RenderFill(record)
    local fill, restedFill = self.frame.Fill, self.frame.RestedFill
    local color = record.color
    fill:SetSwipeColor(color.r, color.g, color.b, color.a or 1)
    local current, max = record.current, record.max
    if issecretvalue(current) or issecretvalue(max) or not max or max <= 0 then
        restedFill:Hide()
        return
    end
    CooldownFrame_SetDisplayAsPercentage(fill, current / max)
    -- Rested band sits ahead of the current XP, in its own colour (record.rested is already non-secret).
    if record.rested and record.rested > 0 then
        local rc = self:GetColor("RestedColor", RESTED_COLOR)
        restedFill:SetSwipeColor(rc.r, rc.g, rc.b, rc.a or 1)
        CooldownFrame_SetDisplayAsPercentage(restedFill, math.min(current + record.rested, max) / max)
        restedFill:Show()
    else
        restedFill:Hide()
    end
end

function Plugin:GetColor(key, fallback)
    local curve = self:GetSetting(SYSTEM_ID, key)
    local c = curve and OrbitEngine.ColorCurve and OrbitEngine.ColorCurve:GetFirstColorFromCurve(curve)
    return c or fallback
end

-- [ TOOLTIP ]----------------------------------------------------------------------------------------
-- Durable equipment slots → their localized WoW global-string names (HEADSLOT = "Head", …).
local DURA_TT_SLOTS = {
    { 1, "HEADSLOT" }, { 3, "SHOULDERSLOT" }, { 5, "CHESTSLOT" }, { 6, "WAISTSLOT" },
    { 7, "LEGSSLOT" }, { 8, "FEETSLOT" }, { 9, "WRISTSLOT" }, { 10, "HANDSSLOT" },
    { 16, "MAINHANDSLOT" }, { 17, "SECONDARYHANDSLOT" },
}
local DURA_TT_OK = { r = 0.55, g = 0.82, b = 0.40 }

function Plugin:RefreshTooltip()
    if not self._hovered or Orbit:IsEditMode() then return end
    self:ShowTooltip()
end

-- A durability breakdown (per damaged slot + repair cost), shown only when gear is actually damaged; mirrors the Durability datatext.
function Plugin:_AppendDurabilityTooltip(tt)
    local rows
    for _, s in ipairs(DURA_TT_SLOTS) do
        local du, mx = GetInventoryItemDurability(s[1])
        if du and mx and mx > 0 and du < mx then
            rows = rows or {}
            rows[#rows + 1] = { name = _G[s[2]] or s[2], pct = du / mx }
        end
    end
    if not rows then return end
    tt:AddLine(" ")
    tt:AddLine(L.PLU_DT_DURABILITY_TITLE, 1, 0.82, 0.25)
    for _, row in ipairs(rows) do
        local c = (row.pct <= 0.20 and DURA_BROKEN_COLOR) or (row.pct <= 0.40 and DURA_DAMAGED_COLOR) or DURA_TT_OK
        tt:AddDoubleLine(row.name, ("%d%%"):format(row.pct * 100 + 0.5), 0.9, 0.9, 0.9, c.r, c.g, c.b)
    end
    local cost = GetRepairAllCost and GetRepairAllCost() or 0
    if cost > 0 then
        tt:AddDoubleLine(L.PLU_DT_DURABILITY_REPAIR_COST, GetCoinTextureString(cost), 0.9, 0.9, 0.9, 1, 1, 1)
    end
end

function Plugin:ShowTooltip()
    local record = self.record
    if not record then return end
    GameTooltip:SetOwner(self.frame, "ANCHOR_RIGHT")
    if record.name and record.name ~= "" then GameTooltip:AddLine(record.name, nil, nil, nil, true) end
    if record.level ~= "" then GameTooltip:AddLine(tostring(record.level), 1, 1, 1) end
    local cur, max = record.current, record.max
    if not issecretvalue(cur) and not issecretvalue(max) and max and max > 0 then
        GameTooltip:AddLine(("%d / %d  (%.0f%%)"):format(cur, max, (cur / max) * 100), 1, 1, 1)
    end
    self:_AppendDurabilityTooltip(GameTooltip)
    GameTooltip:Show()
end

-- [ APPLY SETTINGS ]---------------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then return end

    frame:SetScale((self:GetSetting(SYSTEM_ID, "Scale") or DEFAULT_SCALE) / 100)
    self:ApplyFlourishFont()

    -- Backdrop tint rides the white-luminance fill ring (not the un-tintable near-black track art); fill colours apply per-mode in RenderFill.
    local bg = self:GetColor("BackdropColor", BACKDROP_COLOR)
    frame.BackdropRing:SetVertexColor(bg.r, bg.g, bg.b, bg.a or 1)

    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, SYSTEM_ID) end

    -- Snap the orb to its resting reveal state (concealed when an animation is active, shown when Off).
    self:ApplyAnimationState()
    -- Keep Blizzard's BN toast window enabled so there's something to intercept + replay in the orb.
    self:EnforceToastCVar()

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
        SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, { default = DEFAULT_SCALE, min = SCALE_MIN, max = SCALE_MAX, step = SCALE_STEP })
    elseif currentTab == L.PLU_SB_TAB_COLOR then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, { key = "XPColor",       label = L.PLU_SB_XP_COLOR,         singleColor = true })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, { key = "RestedColor",   label = L.PLU_SB_V2_RESTED_COLOR,  singleColor = true })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, { key = "HonorColor",    label = L.PLU_SB_V2_HONOR_COLOR,   singleColor = true })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, { key = "RepColor",      label = L.PLU_SB_V2_REP_COLOR,     singleColor = true })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, { key = "BackdropColor", label = L.PLU_SB_V2_BACKDROP_COLOR, singleColor = true })
    elseif currentTab == L.PLU_SB_TAB_BEHAVIOUR then
        table.insert(schema.controls, {
            type = "checkbox", key = "ReplaceVaultToast", label = L.PLU_SB_V2_VAULT_TOAST, default = true,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "ReplaceSocialToast", label = L.PLU_SB_V2_SOCIAL_TOAST, default = true,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "ShowMailToast", label = L.PLU_SB_V2_MAIL, default = true,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "ReplaceLootToast", label = L.PLU_SB_V2_LOOT_TOAST, default = true,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "ReplaceLootRoll", label = L.PLU_SB_V2_LOOT_ROLL, default = true,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "ShowMilestones", label = L.PLU_SB_V2_MILESTONES, default = true,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "ShowRewardToasts", label = L.PLU_SB_V2_REWARD_TOASTS, default = true,
        })
        -- Show-at-rest / Shift-shows sources live on the right-click menu (SourceMenu.lua), not here.
        table.insert(schema.controls, {
            type = "checkbox", key = "ShowCenterNumber", label = L.PLU_SB_V2_SHOW_NUMBER, default = false,
        })
        table.insert(schema.controls, {
            type = "dropdown", key = "Animation", label = L.PLU_SB_V2_ANIMATION, default = 0,
            options = {
                { label = L.PLU_SB_V2_ANIM_NONE,   value = 0 },
                { label = L.PLU_SB_V2_ANIM_SLIDE,  value = 1 },
                { label = L.PLU_SB_V2_ANIM_ROTATE, value = 2 },
                { label = L.PLU_SB_V2_ANIM_FADE,   value = 3 },
            },
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ BLIZZARD HIDER ]---------------------------------------------------------------------------------
-- PluginManager "Both disabled" tri-state: plugin off, but the user still wants Blizzard's bar gone.
Orbit:RegisterBlizzardHider("Status Widget", HideBlizzardStatusBar)
