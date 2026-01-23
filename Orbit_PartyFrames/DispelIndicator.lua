---@type Orbit
local Orbit = Orbit
local LCG = LibStub("LibCustomGlow-1.0")

-- Dispel Indicator System for Party Frames
-- Shows animated pixel border when unit has dispellable debuff
-- Uses Blizzard's CompactUnitFrame hooks to detect dispellable debuffs (same as DandersFrames)

Orbit.PartyFrameDispelMixin = {}

-- ============================================================
-- BLIZZARD AURA CACHE
-- Hooks Blizzard's hidden raid frames to detect dispellable debuffs
-- ============================================================

local BlizzardDispelCache = {}
local HooksSetup = false

-- Capture dispellable debuffs from Blizzard's frame
local function CaptureDispellableFromBlizzardFrame(frame, triggerUpdate)
    if not frame or not frame.unit then return end
    
    local unit = frame.unit
    
    -- Initialize cache for this unit
    if not BlizzardDispelCache[unit] then
        BlizzardDispelCache[unit] = {}
    end
    
    -- Clear previous cache
    wipe(BlizzardDispelCache[unit])
    
    -- Capture dispellable debuffs from Blizzard's dispelDebuffFrames
    -- These frames only show debuffs that can be dispelled (based on CVar setting)
    if frame.dispelDebuffFrames then
        for i, debuffFrame in ipairs(frame.dispelDebuffFrames) do
            if debuffFrame:IsShown() and debuffFrame.auraInstanceID then
                BlizzardDispelCache[unit][debuffFrame.auraInstanceID] = true
            end
        end
    end
    
    -- Trigger update on Orbit frames if requested
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

-- Set up hooks on Blizzard's compact frames
local function SetupBlizzardHooks()
    if HooksSetup then return end
    
    -- Hook CompactUnitFrame_UpdateAuras if it exists
    if CompactUnitFrame_UpdateAuras then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            CaptureDispellableFromBlizzardFrame(frame, true)
        end)
        HooksSetup = true
    end
    
    -- Also hook UpdateDebuffs if separate
    if CompactUnitFrame_UpdateDebuffs then
        hooksecurefunc("CompactUnitFrame_UpdateDebuffs", function(frame)
            CaptureDispellableFromBlizzardFrame(frame, true)
        end)
    end
end

-- Check if aura is dispellable based on Blizzard's cache
local function IsDispellable(unit, auraInstanceID)
    local cache = BlizzardDispelCache[unit]
    if not cache then return false end
    return cache[auraInstanceID] == true
end

-- ============================================================
-- DISPEL COLORS
-- ============================================================

local DEFAULT_COLORS = {
    Magic = { r = 0.0, g = 0.4, b = 1.0, a = 1 },      -- Deep blue
    Curse = { r = 0.6, g = 0.0, b = 0.8, a = 1 },      -- Deep purple
    Disease = { r = 0.8, g = 0.4, b = 0.0, a = 1 },    -- Deep orange/brown
    Poison = { r = 0.0, g = 0.7, b = 0.2, a = 1 },     -- Deep emerald green
    Bleed = { r = 0.9, g = 0.0, b = 0.0, a = 1 },      -- Deep red
}

local DISPEL_TYPE_NAMES = {
    [1] = "Magic",
    [2] = "Curse",
    [3] = "Disease",
    [4] = "Poison",
    [9] = "Bleed",   -- Enrage
    [11] = "Bleed",  -- Bleed
}

-- Get color for a dispel type (uses settings or defaults)
local function GetDispelColor(plugin, dispelType)
    local typeName = DISPEL_TYPE_NAMES[dispelType]
    if not typeName then return nil end
    
    local colorKey = "DispelColor" .. typeName
    local color = plugin:GetSetting(1, colorKey) or DEFAULT_COLORS[typeName]
    
    if color then
        return { color.r, color.g, color.b, color.a or 1 }
    end
    return nil
end

-- ============================================================
-- UPDATE DISPEL INDICATOR
-- ============================================================

function Orbit.PartyFrameDispelMixin:UpdateDispelIndicator(frame, plugin)
    if not frame or not frame.unit then
        return
    end
    
    -- Ensure hooks are set up
    SetupBlizzardHooks()
    
    local unit = frame.unit
    
    -- Check if dispel indicators are enabled
    local enabled = plugin:GetSetting(1, "DispelIndicatorEnabled")
    if not enabled then
        LCG.PixelGlow_Stop(frame)
        return
    end
    
    -- Check if unit exists
    if not UnitExists(unit) then
        LCG.PixelGlow_Stop(frame)
        return
    end
    
    -- Check API availability
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuras then
        return
    end
    
    -- Get debuffs
    local auras = C_UnitAuras.GetUnitAuras(unit, "HARMFUL")
    
    if not auras or #auras == 0 then
        LCG.PixelGlow_Stop(frame)
        return
    end
    
    -- Find first dispellable debuff using Blizzard's cache
    -- Also check for bleeds/enrages which aren't in the cache
    local foundDispellable = false
    local dispelType = nil
    local lastAuraInstanceID = nil
    
    for i, aura in ipairs(auras) do
        local shouldShow = false
        local auraDispelType = nil
        
        -- Try to get dispelType (may be secret, use pcall)
        pcall(function()
            auraDispelType = aura.dispelType
        end)
        
        -- Check for bleeds (11) and enrages (9) first - these aren't in Blizzard's cache
        if auraDispelType == 11 or auraDispelType == 9 then
            shouldShow = true
            dispelType = auraDispelType
        else
            -- Check if this aura is in Blizzard's dispellable cache
            local isInCache = IsDispellable(unit, aura.auraInstanceID)
            if isInCache then
                shouldShow = true
                dispelType = auraDispelType
            end
        end
        
        if shouldShow then
            foundDispellable = true
            lastAuraInstanceID = aura.auraInstanceID
            break
        end
    end
    
    if foundDispellable and lastAuraInstanceID then
        -- Build color curve with custom colors
        local curve = nil
        if C_CurveUtil and C_CurveUtil.CreateColorCurve then
            curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            
            -- Add color points for each dispel type
            for typeNum, typeName in pairs(DISPEL_TYPE_NAMES) do
                local colorKey = "DispelColor" .. typeName
                local c = plugin:GetSetting(1, colorKey) or DEFAULT_COLORS[typeName]
                if c then
                    curve:AddPoint(typeNum, CreateColor(c.r, c.g, c.b, c.a or 1))
                end
            end
        end
        
        -- Get color for this aura using the curve (handles secret dispelType)
        local color = nil
        if curve and C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor then
            color = C_UnitAuras.GetAuraDispelTypeColor(unit, lastAuraInstanceID, curve)
        end
        
        -- Only show glow if we got a valid color from the curve
        if color then
            -- Get settings
            local thickness = plugin:GetSetting(1, "DispelThickness") or 2
            local frequency = plugin:GetSetting(1, "DispelFrequency") or 0.25
            local numLines = plugin:GetSetting(1, "DispelNumLines") or 8
            
            -- Start pixel glow (frameLevel 30 = high enough to be above selection border)
            LCG.PixelGlow_Start(
                frame,
                color,       -- Color object from curve API
                numLines,
                frequency,
                nil,         -- length (auto)
                thickness,
                0,           -- xOffset
                0,           -- yOffset
                true,        -- border (dark background behind glow)
                nil,         -- key
                30           -- frameLevel (high enough to be above selection border)
            )
        end
    else
        LCG.PixelGlow_Stop(frame)
    end
end

-- ============================================================
-- UPDATE ALL FRAMES
-- ============================================================

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

-- ============================================================
-- EVENT FRAME FOR INITIAL SCAN
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event)
    -- Set up hooks on first event
    SetupBlizzardHooks()
    
    -- Scan Blizzard frames after a delay
    C_Timer.After(0.5, function()
        -- Scan party frames
        for i = 1, 5 do
            local frame = _G["CompactPartyFrameMember" .. i]
            if frame then
                CaptureDispellableFromBlizzardFrame(frame, true)
            end
        end
        
        -- Scan raid frames  
        for i = 1, 40 do
            local frame = _G["CompactRaidFrame" .. i]
            if frame then
                CaptureDispellableFromBlizzardFrame(frame, true)
            end
        end
    end)
end)
