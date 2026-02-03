---@type Orbit
local Orbit = Orbit
local LCG = LibStub("LibCustomGlow-1.0")

Orbit.PartyFrameDispelMixin = {}

-- [ BLIZZARD AURA CACHE ]--------------------------------------------------------------------------
local BlizzardDispelCache = {}
local HooksSetup = false

local function CaptureDispellableFromBlizzardFrame(frame, triggerUpdate)
    if not frame or not frame.unit then
        return
    end
    local unit = frame.unit
    if not BlizzardDispelCache[unit] then
        BlizzardDispelCache[unit] = {}
    end
    wipe(BlizzardDispelCache[unit])
    wipe(BlizzardDispelCache[unit])

    if frame.dispelDebuffFrames then
        for i, debuffFrame in ipairs(frame.dispelDebuffFrames) do
            if debuffFrame:IsShown() and debuffFrame.auraInstanceID then
                BlizzardDispelCache[unit][debuffFrame.auraInstanceID] = true
            end
        end
    end
    if triggerUpdate then
        local plugin = Orbit:GetPlugin("Orbit_PartyFrames")
        if plugin and plugin.frames then
            for _, orbitFrame in ipairs(plugin.frames) do
                if orbitFrame and orbitFrame.unit == unit and orbitFrame:IsShown() then
                    if plugin.UpdateDispelIndicator then
                        plugin:UpdateDispelIndicator(orbitFrame, plugin)
                    end
                end
            end
        end
    end
end

local function SetupBlizzardHooks()
    if HooksSetup then
        return
    end
    if CompactUnitFrame_UpdateAuras then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            CaptureDispellableFromBlizzardFrame(frame, true)
        end)
        HooksSetup = true
    end
    if CompactUnitFrame_UpdateDebuffs then
        hooksecurefunc("CompactUnitFrame_UpdateDebuffs", function(frame)
            CaptureDispellableFromBlizzardFrame(frame, true)
        end)
    end
end

local function IsDispellable(unit, auraInstanceID)
    local cache = BlizzardDispelCache[unit]
    return cache and cache[auraInstanceID] == true
end

-- [ DISPEL COLORS ]--------------------------------------------------------------------------------
local DEFAULT_COLORS = {
    Magic = { r = 0.0, g = 0.4, b = 1.0, a = 1 },
    Curse = { r = 0.6, g = 0.0, b = 0.8, a = 1 },
    Disease = { r = 0.8, g = 0.4, b = 0.0, a = 1 },
    Poison = { r = 0.0, g = 0.7, b = 0.2, a = 1 },
    Bleed = { r = 0.9, g = 0.0, b = 0.0, a = 1 },
}

local DISPEL_TYPE_NAMES = { [1] = "Magic", [2] = "Curse", [3] = "Disease", [4] = "Poison", [9] = "Bleed", [11] = "Bleed" }

local function GetDispelColor(plugin, dispelType)
    local typeName = DISPEL_TYPE_NAMES[dispelType]
    if not typeName then
        return nil
    end
    local color = plugin:GetSetting(1, "DispelColor" .. typeName) or DEFAULT_COLORS[typeName]
    return color and { color.r, color.g, color.b, color.a or 1 } or nil
end

-- [ UPDATE DISPEL INDICATOR ]----------------------------------------------------------------------
function Orbit.PartyFrameDispelMixin:UpdateDispelIndicator(frame, plugin)
    if not frame or not frame.unit then
        return
    end
    SetupBlizzardHooks()
    local unit = frame.unit
    local enabled = plugin:GetSetting(1, "DispelIndicatorEnabled")
    if not enabled then
        LCG.PixelGlow_Stop(frame)
        return
    end
    if not UnitExists(unit) then
        LCG.PixelGlow_Stop(frame)
        return
    end
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuras then
        return
    end
    local auras = C_UnitAuras.GetUnitAuras(unit, "HARMFUL")
    if not auras or #auras == 0 then
        LCG.PixelGlow_Stop(frame)
        return
    end

    local bestAuraInstanceID = nil
    for _, aura in ipairs(auras) do
        if IsDispellable(unit, aura.auraInstanceID) then
            bestAuraInstanceID = aura.auraInstanceID
            break
        end
    end

    if bestAuraInstanceID then
        local curve = nil
        if C_CurveUtil and C_CurveUtil.CreateColorCurve then
            curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            for typeNum, typeName in pairs(DISPEL_TYPE_NAMES) do
                local c = plugin:GetSetting(1, "DispelColor" .. typeName) or DEFAULT_COLORS[typeName]
                if c then
                    curve:AddPoint(typeNum, CreateColor(c.r, c.g, c.b, c.a or 1))
                end
            end
        end
        local color = curve and C_UnitAuras.GetAuraDispelTypeColor and C_UnitAuras.GetAuraDispelTypeColor(unit, bestAuraInstanceID, curve)
        if color then
            local thickness = plugin:GetSetting(1, "DispelThickness") or 2
            local frequency = plugin:GetSetting(1, "DispelFrequency") or 0.25
            local numLines = plugin:GetSetting(1, "DispelNumLines") or 8
            LCG.PixelGlow_Start(frame, color, numLines, frequency, nil, thickness, 0, 0, true, nil, Orbit.Constants.Levels.Glow)
        else
            LCG.PixelGlow_Stop(frame)
        end
    else
        LCG.PixelGlow_Stop(frame)
    end
end

-- [ UPDATE ALL FRAMES ]----------------------------------------------------------------------------
function Orbit.PartyFrameDispelMixin:UpdateAllDispelIndicators(plugin)
    if not plugin or not plugin.frames then
        return
    end
    for _, frame in ipairs(plugin.frames) do
        if frame and frame.unit then
            self:UpdateDispelIndicator(frame, plugin)
        end
    end
end

-- [ EVENT FRAME FOR INITIAL SCAN ]-----------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event)
    SetupBlizzardHooks()
    C_Timer.After(0.5, function()
        for i = 1, 5 do
            local frame = _G["CompactPartyFrameMember" .. i]
            if frame then
                CaptureDispellableFromBlizzardFrame(frame, true)
            end
        end
        for i = 1, 40 do
            local frame = _G["CompactRaidFrame" .. i]
            if frame then
                CaptureDispellableFromBlizzardFrame(frame, true)
            end
        end
    end)
end)
