-- [ CANVAS MODE - CYCLING ATLAS CREATOR ]------------------------------------------------------------
-- Crossfading atlas preview for grouped/cycling icon components in Canvas Mode.

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local CC = CanvasMode.CreatorConstants

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local HOLD_DURATION = 2.0
local FADE_DURATION = 0.5
local MISSIONS_DEFAULT_ATLAS = "midnight-landingbutton-up"

-- Preview-only cycling sets (no live-mixin equivalent). Role/Leader atlases are NOT here — they come from Orbit.StatusIconMixin (the domain owner) so the strings live in one place.
local CYCLING_ATLASES = {
    StatusIcons = {
        { atlas = "RaidFrame-Icon-Phasing" },
        { atlas = "UI-LFG-ReadyMark-Raid" },
        { atlas = "RaidFrame-Icon-Rez" },
        { atlas = "RaidFrame-Icon-SummonPending" },
    },
    PvpIcon = {
        { atlas = "AllianceAssaultsMapBanner" },
        { atlas = "HordeAssaultsMapBanner" },
    },
    DispelIcon = {
        { atlas = "icons_64x64_magic" },
        { atlas = "icons_64x64_curse" },
        { atlas = "icons_64x64_disease" },
        { atlas = "icons_64x64_poison" },
        { atlas = "icons_64x64_bleed" },
    },
}

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function ResolveMissionsAtlas()
    local elp = ExpansionLandingPage
    local info = elp and elp.GetOverlayMinimapDisplayInfo and elp:GetOverlayMinimapDisplayInfo()
    local atlas = info and info.normalAtlas
    if not atlas then
        local btn = ExpansionLandingPageMinimapButton
        local normal = btn and btn.GetNormalTexture and btn:GetNormalTexture()
        atlas = normal and normal:GetAtlas()
    end
    return atlas or MISSIONS_DEFAULT_ATLAS
end

local function CreateFadeGroup(tex, fromAlpha, toAlpha)
    local group = tex:CreateAnimationGroup()
    local anim = group:CreateAnimation("Alpha")
    anim:SetFromAlpha(fromAlpha)
    anim:SetToAlpha(toAlpha)
    anim:SetDuration(FADE_DURATION)
    group:SetScript("OnFinished", function() tex:SetAlpha(toAlpha) end)
    return group
end

-- [ CREATOR ]----------------------------------------------------------------------------------------
local function Create(container, preview, key, source, data)
    local atlases = CYCLING_ATLASES[key]
    local overrides = data and data.overrides

    -- Role/Leader atlas+style resolution lives in the domain owner; this creator is a generic crossfader.
    if key == "RoleIcon" then
        atlases = Orbit.StatusIconMixin:GetRoleCanvasAtlases(overrides)
    elseif key == "LeaderIcon" then
        atlases = Orbit.StatusIconMixin:GetLeaderCanvasAtlases(overrides)
    elseif key == "Missions" then
        atlases = { { atlas = ResolveMissionsAtlas() } }
    end

    if not atlases or #atlases == 0 then return nil end

    container._cyclingAtlases = atlases

    local texA = container:CreateTexture(nil, "OVERLAY", nil, 1)
    texA:SetAllPoints(container)
    local texB = container:CreateTexture(nil, "OVERLAY", nil, 2)
    texB:SetAllPoints(container)
    texB:SetAlpha(0)
    container._cyclingTexA = texA
    container._cyclingTexB = texB

    local fadeOutA = CreateFadeGroup(texA, 1, 0)
    local fadeInA = CreateFadeGroup(texA, 0, 1)
    local fadeOutB = CreateFadeGroup(texB, 1, 0)
    local fadeInB = CreateFadeGroup(texB, 0, 1)

    local cycleIndex = 1
    local active, incoming = texA, texB
    local activeOut, incomingIn = fadeOutA, fadeInB
    active:SetAtlas(atlases[1].atlas, false)

    local function Crossfade()
        if not container:IsShown() then return end
        local a = container._cyclingAtlases
        cycleIndex = (cycleIndex % #a) + 1
        incoming:SetAtlas(a[cycleIndex].atlas, false)
        activeOut:Play()
        incomingIn:Play()
        active, incoming = incoming, active
        if active == texA then activeOut, incomingIn = fadeOutA, fadeInB
        else activeOut, incomingIn = fadeOutB, fadeInA end
    end

    local ticker = C_Timer.NewTicker(HOLD_DURATION + FADE_DURATION, Crossfade)
    container._cyclingTicker = ticker

    -- Size: IconSize override > Scale override on source size > source size > default
    local savedSize = overrides and overrides.IconSize
    local scale = overrides and overrides.Scale or 1
    local size
    if savedSize and savedSize > 0 then
        size = savedSize
    else
        size = CanvasMode.GetSourceSize(source, CC.DEFAULT_ICON_SIZE, CC.DEFAULT_ICON_SIZE)
        size = size * scale
    end
    local cScale = container:GetEffectiveScale()
    local snappedSize = OrbitEngine.Pixel:Snap(size, cScale)
    container:SetSize(snappedSize, snappedSize)
    container.skipSourceSizeRestore = true

    return texA
end

CanvasMode:RegisterCreator("CyclingAtlas", Create)
