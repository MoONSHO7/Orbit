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

local CYCLING_ATLASES = {
    StatusIcons = {
        { atlas = "RaidFrame-Icon-Phasing" },
        { atlas = "UI-LFG-ReadyMark-Raid" },
        { atlas = "RaidFrame-Icon-Rez" },
        { atlas = "RaidFrame-Icon-SummonPending" },
    },
    RoleIcon = {
        { atlas = "UI-LFG-RoleIcon-Tank" },
        { atlas = "UI-LFG-RoleIcon-Healer" },
        { atlas = "UI-LFG-RoleIcon-DPS" },
    },
    LeaderIcon = {
        { atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon" },
    },
    PvpIcon = {
        { atlas = "AllianceAssaultsMapBanner" },
        { atlas = "HordeAssaultsMapBanner" },
    },
    -- Expansion landing page button — cycles through all known expansion icons
    Missions = {
        { atlas = "GarrLanding-MinimapIcon-Horde-Up" },           -- WoD (Horde)
        { atlas = "GarrLanding-MinimapIcon-Alliance-Up" },        -- WoD (Alliance)
        { atlas = "legionmission-landingbutton-warrior-up" },     -- Legion
        { atlas = "BFAMission-LandingButton-Horde-Up" },          -- BfA
        { atlas = "Shadowlands-landingbutton-venthyr-up" },       -- Shadowlands
        { atlas = "dragonflight-landingbutton-up" },              -- Dragonflight
        { atlas = "TWWLandingPage-ButtonIcon-Earthen" },          -- The War Within
    },
}

local ROUND_ROLE_ATLASES = {
    { atlas = "icons_64x64_tank" },
    { atlas = "icons_64x64_heal" },
    { atlas = "icons_64x64_damage" },
}

local HEADER_ROLE_ATLASES = {
    { atlas = "GO-icon-role-Header-Tank" },
    { atlas = "GO-icon-role-Header-Healer" },
    { atlas = "GO-icon-role-Header-DPS" },
    { atlas = "GO-icon-role-Header-DPS-Ranged" },
}

local HEADER_LEADER_ATLASES = {
    { atlas = "GO-icon-Header-Assist-Applied" },
    { atlas = "GO-icon-Header-Assist-Available" },
}

-- [ HELPERS ]----------------------------------------------------------------------------------------
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

    -- Resolve atlas set from overrides for keys not in CYCLING_ATLASES or with style variants
    if key == "RoleIcon" then
        if overrides and overrides.RoleIconStyle == "round" then atlases = ROUND_ROLE_ATLASES
        elseif overrides and overrides.RoleIconStyle == "header" then atlases = HEADER_ROLE_ATLASES end
        if overrides and overrides.HideDPS then
            local dpsAtlas = (atlases == ROUND_ROLE_ATLASES) and "icons_64x64_damage" or (atlases == HEADER_ROLE_ATLASES) and "GO-icon-role-Header-DPS" or "UI-LFG-RoleIcon-DPS"
            local rangedAtlas = (atlases == HEADER_ROLE_ATLASES) and "GO-icon-role-Header-DPS-Ranged" or nil
            local filtered = {}
            for _, entry in ipairs(atlases or {}) do
                if entry.atlas ~= dpsAtlas and entry.atlas ~= rangedAtlas then filtered[#filtered + 1] = entry end
            end
            atlases = filtered
        end
    elseif key == "LeaderIcon" then
        if overrides and overrides.LeaderIconStyle == "header" then atlases = HEADER_LEADER_ATLASES end
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
