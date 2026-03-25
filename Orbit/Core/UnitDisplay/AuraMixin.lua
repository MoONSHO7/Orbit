-- [ ORBIT AURA MIXIN ]------------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local pcall, type, ipairs = pcall, type, ipairs
local math_max = math.max
local tinsert = table.insert

---@class OrbitAuraMixin
Orbit.AuraMixin = {}
local Mixin = Orbit.AuraMixin

local DEFAULT_AURA_COUNT = 40
local TIMER_MIN_ICON_SIZE = 14
local AURA_MIN_DISPLAY_COUNT = 2
local AURA_MAX_DISPLAY_COUNT = 99
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT____.TTF"
local AURA_COUNT_SIZE = 8
local AURA_TIMER_SIZE = 8

-- [ CACHED FONT ]-----------------------------------------------------------------------------------
local cachedFontPath, cachedFontOutline
local function GetAuraFont()
    if cachedFontPath then return cachedFontPath, cachedFontOutline end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    cachedFontPath = (LSM and fontName and LSM:Fetch("font", fontName)) or DEFAULT_FONT_PATH
    cachedFontOutline = Orbit.Skin and Orbit.Skin.GetFontOutline and Orbit.Skin:GetFontOutline() or ""
    return cachedFontPath, cachedFontOutline
end
function Mixin:InvalidateFontCache() cachedFontPath = nil; cachedFontOutline = nil end

-- [ SKIN FACADE ]-----------------------------------------------------------------------------------
function Mixin:ApplyAuraSkin(icon, settings)
    if not icon or not Orbit.Skin or not Orbit.Skin.Icons then return end
    Orbit.Skin.Icons:ApplyCustom(icon, settings or Orbit.Constants.Aura.SkinWithTimer)
end

-- [ AURA POOL CREATION ]----------------------------------------------------------------------------
function Mixin:CreateAuraPool(frame, template, parent)
    if frame.auraPool then return frame.auraPool end
    frame.auraPool = CreateFramePool("Button", parent or frame, template or "BackdropTemplate")
    return frame.auraPool
end

function Mixin:BuildAuraSnapshot(unit)
    local harmful = C_UnitAuras.GetUnitAuras(unit, "HARMFUL") or {}
    local helpful = C_UnitAuras.GetUnitAuras(unit, "HELPFUL") or {}
    local helpfulBySpell = {}
    local helpfulPlayerBySpell = {}
    for _, aura in ipairs(helpful) do
        local sid = aura.spellId
        if not issecretvalue(sid) then
            helpfulBySpell[sid] = aura
            local fromPlayer = aura.isFromPlayerOrPlayerPet
            if not issecretvalue(fromPlayer) and fromPlayer then helpfulPlayerBySpell[sid] = aura end
        end
    end
    return { harmful = harmful, helpful = helpful, helpfulBySpell = helpfulBySpell, helpfulPlayerBySpell = helpfulPlayerBySpell }
end

-- [ INCREMENTAL AURA CACHE ]------------------------------------------------------------------------
-- Per-frame caches keyed by auraInstanceID. Patched incrementally on partial UNIT_AURA events.
-- addedAuras fields (isHarmful, isHelpful) are WoW 12.0 secret booleans — use IsAuraFilteredOutByInstanceID instead.
local GetAuraDataByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID
local IsFilteredOut = C_UnitAuras.IsAuraFilteredOutByInstanceID

function Mixin:PopulateCaches(frame, snapshot)
    local hc, bc = {}, {}
    for _, a in ipairs(snapshot.harmful) do hc[a.auraInstanceID] = a end
    for _, a in ipairs(snapshot.helpful) do bc[a.auraInstanceID] = a end
    frame._harmfulAuraCache = hc
    frame._helpfulAuraCache = bc
end

function Mixin:PatchCaches(frame, unit, updateInfo)
    local hc = frame._harmfulAuraCache
    local bc = frame._helpfulAuraCache
    if not hc or not bc then return false end
    local changed = false
    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            local id = aura.auraInstanceID
            if id then
                local fresh = GetAuraDataByAuraInstanceID(unit, id) or aura
                if not IsFilteredOut(unit, id, "HARMFUL") then hc[id] = fresh; changed = true end
                if not IsFilteredOut(unit, id, "HELPFUL") then bc[id] = fresh; changed = true end
            end
        end
    end
    if updateInfo.updatedAuraInstanceIDs then
        for _, id in ipairs(updateInfo.updatedAuraInstanceIDs) do
            local fresh = GetAuraDataByAuraInstanceID(unit, id)
            if hc[id] then hc[id] = fresh or nil; changed = true
            elseif bc[id] then bc[id] = fresh or nil; changed = true
            elseif fresh then
                if not IsFilteredOut(unit, id, "HARMFUL") then hc[id] = fresh; changed = true end
                if not IsFilteredOut(unit, id, "HELPFUL") then bc[id] = fresh; changed = true end
            end
        end
    end
    if updateInfo.removedAuraInstanceIDs then
        for _, id in ipairs(updateInfo.removedAuraInstanceIDs) do
            if hc[id] then hc[id] = nil; changed = true end
            if bc[id] then bc[id] = nil; changed = true end
        end
    end
    return changed
end

function Mixin:BuildSnapshotFromCaches(frame)
    local hc = frame._harmfulAuraCache
    local bc = frame._helpfulAuraCache
    if not hc or not bc then return nil end
    local harmful, helpful = {}, {}
    local helpfulBySpell, helpfulPlayerBySpell = {}, {}
    for _, a in next, hc do harmful[#harmful + 1] = a end
    for _, a in next, bc do
        helpful[#helpful + 1] = a
        local sid = a.spellId
        if not issecretvalue(sid) then
            helpfulBySpell[sid] = a
            local fromPlayer = a.isFromPlayerOrPlayerPet
            if not issecretvalue(fromPlayer) and fromPlayer then helpfulPlayerBySpell[sid] = a end
        end
    end
    return { harmful = harmful, helpful = helpful, helpfulBySpell = helpfulBySpell, helpfulPlayerBySpell = helpfulPlayerBySpell }
end

function Mixin:WipeCaches(frame)
    frame._harmfulAuraCache = nil
    frame._helpfulAuraCache = nil
end

function Mixin:FetchAuras(unit, filter, maxCount)
    local auras = {}
    if unit and UnitExists(unit) then
        local count = maxCount or DEFAULT_AURA_COUNT
        AuraUtil.ForEachAura(unit, filter, count, function(aura)
            aura.index = #auras + 1
            tinsert(auras, aura)
            if #auras >= count then return true end
        end, true)
    end
    return auras
end

-- [ ICON SETUP ]------------------------------------------------------------------------------------
function Mixin:SetupAuraIcon(icon, aura, size, unit, skinSettings, componentPositions)
    if not icon or not aura then return end
    icon:SetSize(size, size)
    if not icon.Icon then icon.Icon = icon:CreateTexture(nil, "ARTWORK") end
    icon.icon = icon.Icon
    icon.Icon:SetTexture(aura.icon)
    icon.Icon:ClearAllPoints()
    icon.Icon:SetAllPoints(icon)
    icon.Icon:Show()
    if not icon.Cooldown then
        icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.Cooldown:SetAllPoints()
        icon.Cooldown:SetHideCountdownNumbers(false)
        icon.Cooldown:EnableMouse(false)
        icon.cooldown = icon.Cooldown
    end
    if not icon.Overlay then
        icon.Overlay = CreateFrame("Frame", nil, icon)
        icon.Overlay:SetAllPoints(icon)
        icon.Overlay:SetFrameLevel(icon:GetFrameLevel() + Orbit.Constants.Levels.IconOverlay)
        icon.Overlay:EnableMouse(false)
    end
    if not icon.count then
        icon.count = icon.Overlay:CreateFontString(nil, "OVERLAY")
    end
    local fontPath, fontOutline = GetAuraFont()
    icon.count:SetFont(fontPath, AURA_COUNT_SIZE, fontOutline)
    icon.count:SetShadowColor(0, 0, 0, 1)
    icon.count:SetShadowOffset(1, -1)
    icon.count:ClearAllPoints()
    icon.count:SetPoint("BOTTOMRIGHT", icon.Overlay, "BOTTOMRIGHT", -1, 1)
    icon.count:SetJustifyH("RIGHT")
    self:ApplyAuraCount(icon, aura, unit)
    if icon.Cooldown then
        local timerText = icon.Cooldown.Text
        if not timerText then
            for _, region in pairs({ icon.Cooldown:GetRegions() }) do
                if region:IsObjectType("FontString") then timerText = region; break end
            end
            icon.Cooldown.Text = timerText
        end
        if timerText and timerText.SetFont then
            timerText:SetParent(icon.Overlay)
            timerText:SetFont(fontPath, AURA_TIMER_SIZE, fontOutline)
            timerText:ClearAllPoints()
            timerText:SetPoint("CENTER", icon, "CENTER", 0, 0)
            timerText:SetJustifyH("CENTER")
            timerText:SetDrawLayer("OVERLAY", 7)
        end
        icon.Cooldown:SetHideCountdownNumbers(size < TIMER_MIN_ICON_SIZE)
    end
    if skinSettings then self:ApplyAuraSkin(icon, skinSettings) end
    self:ApplyAuraCooldown(icon, aura, unit)
    if skinSettings and skinSettings.swipeColor and icon.Cooldown then
        icon.Cooldown:SetSwipeColor(skinSettings.swipeColor.r, skinSettings.swipeColor.g, skinSettings.swipeColor.b, skinSettings.swipeColor.a or 0.8)
    end
    if skinSettings and skinSettings.enablePandemic then
        Orbit.PandemicGlow:Apply(icon, aura, unit, skinSettings)
        if icon.PandemicIcon then icon.PandemicIcon:SetAlpha(0) end
    end
    -- Apply canvas mode component overrides (must be last to avoid skin/cooldown clobbering)
    if componentPositions then
        local OverrideUtils = Orbit.Engine.OverrideUtils
        local ApplyTextPosition = Orbit.Engine.PositionUtils and Orbit.Engine.PositionUtils.ApplyTextPosition
        if OverrideUtils then
            local stacksData = componentPositions.Stacks
            if stacksData then
                OverrideUtils.ApplyOverrides(icon.count, stacksData.overrides or {}, { fontSize = AURA_COUNT_SIZE, fontPath = fontPath })
                if ApplyTextPosition then ApplyTextPosition(icon.count, icon, stacksData) end
            end
            local timerData = componentPositions.Timer
            if timerData and icon.Cooldown and icon.Cooldown.Text then
                OverrideUtils.ApplyOverrides(icon.Cooldown.Text, timerData.overrides or {}, { fontSize = AURA_TIMER_SIZE, fontPath = fontPath })
                if ApplyTextPosition then ApplyTextPosition(icon.Cooldown.Text, icon, timerData) end
            end
        end
    end
    icon:Show()
    return icon
end

function Mixin:ApplyAuraCooldown(icon, aura, unit)
    if not icon or not icon.Cooldown then return end
    if aura.auraInstanceID and unit then
        local durObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
        if durObj then icon.Cooldown:SetCooldownFromDurationObject(durObj); return end
    end
    icon.Cooldown:Clear()
end

function Mixin:ApplyAuraCount(icon, aura, unit)
    if not icon or not icon.count then return end
    if aura.auraInstanceID and unit then
        local displayCount = C_UnitAuras.GetAuraApplicationDisplayCount(unit, aura.auraInstanceID, AURA_MIN_DISPLAY_COUNT, AURA_MAX_DISPLAY_COUNT)
        icon.count:SetText(displayCount)
        icon.count:Show()
        return
    end
    icon.count:SetText("")
    icon.count:Hide()
end

-- [ AURA TOOLTIP ]-----------------------------------------------------------------------------------
function Mixin:SetupAuraTooltip(icon, aura, unit, filter)
    icon:EnableMouse(true)
    if not icon._orbitPassThrough and not InCombatLockdown() then
        icon:SetPassThroughButtons("LeftButton", "RightButton")
        icon._orbitPassThrough = true
    end
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        if aura.auraInstanceID and unit and filter then
            if filter:find("HARMFUL") then
                GameTooltip:SetUnitDebuffByAuraInstanceID(unit, aura.auraInstanceID)
            else
                GameTooltip:SetUnitBuffByAuraInstanceID(unit, aura.auraInstanceID)
            end
        elseif aura.spellId then
            GameTooltip:SetSpellByID(aura.spellId)
        end
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- [ AURA FILTER ]-----------------------------------------------------------------------------------
function Mixin:IsAuraIncluded(unit, auraInstanceID, filter)
    return not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, filter)
end

-- [ AURA CONTAINER DISPLAY ]------------------------------------------------------------------------
local OrbitEngine = Orbit.Engine
local AL = Orbit.AuraLayout
local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint
local BuildComponentSelfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor

function Mixin:UpdateAuraContainer(frame, plugin, containerKey, poolKey, cfg)
    local container = frame[containerKey]
    if not container then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled(cfg.componentKey) then container:Hide(); return end
    local positions = plugin:GetSetting(1, "ComponentPositions") or {}
    local auraData = positions[cfg.componentKey] or {}
    local overrides = auraData.overrides or {}
    local frameW, frameH = frame:GetWidth(), frame:GetHeight()
    local maxIcons = overrides.MaxIcons or cfg.defaultMaxIcons or 3
    local unit = frame.unit
    if not unit or not UnitExists(unit) then container:Hide(); return end
    if not frame[poolKey] then frame[poolKey] = CreateFramePool("Button", container, "BackdropTemplate") end
    local fetchFilter = cfg.fetchFilter
    local density = overrides.FilterDensity or 1
    if density <= 1 then fetchFilter = fetchFilter .. "|RAID_IN_COMBAT"
    elseif density >= 3 then fetchFilter = fetchFilter:gsub("|PLAYER", "") end
    -- Force everything to use the secure snapshot architecture, building securely locally if the OnEvent missed it
    local snap = frame._auraSnapshot or self:BuildAuraSnapshot(unit)
    local rawAuras = fetchFilter:find("HARMFUL") and snap.harmful or snap.helpful
    local auras
    if cfg.postFilter then
        auras = cfg.postFilter(plugin, unit, rawAuras, maxIcons, fetchFilter)
    else
        auras = {}
        for _, a in ipairs(rawAuras) do
            if a.auraInstanceID and not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, a.auraInstanceID, fetchFilter) then
                auras[#auras + 1] = a
                if #auras >= maxIcons then break end
            end
        end
    end
    if #auras == 0 then container._auraFingerprint = nil; frame[poolKey]:ReleaseAll(); container:Hide(); return end
    -- Build fingerprint from instance IDs to skip rebuild when unchanged
    local fp = #auras
    for _, a in ipairs(auras) do fp = fp * 65599 + (a.auraInstanceID or 0) end
    if container._auraFingerprint == fp then return end
    container._auraFingerprint = fp
    frame[poolKey]:ReleaseAll()
    local helpers = type(cfg.helpers) == "function" and cfg.helpers() or cfg.helpers
    local position = helpers:AnchorToPosition(auraData.posX, auraData.posY, frameW / 2, frameH / 2)
    local scale = frame:GetEffectiveScale() or 1
    local iconSize, _, iconsPerRow, containerW, containerH, iconsPerCol = AL:CalculateSmartLayout(frameW, frameH, position, maxIcons, #auras, overrides, scale)
    container:ClearAllPoints()
    container:SetSize(containerW, containerH)
    local anchorX = auraData.anchorX or cfg.defaultAnchorX or "LEFT"
    local anchorY = auraData.anchorY or cfg.defaultAnchorY or "CENTER"
    local offsetX = auraData.offsetX or 0
    local offsetY = auraData.offsetY or 0
    local justifyH = auraData.justifyH or cfg.defaultJustifyH or "LEFT"
    local finalX = (anchorX == "RIGHT") and -offsetX or offsetX
    local finalY = (anchorY == "TOP") and -offsetY or offsetY
    local selfAnchorY = auraData.selfAnchorY or anchorY
    container:SetPoint(BuildComponentSelfAnchor(false, true, selfAnchorY, justifyH), frame, BuildAnchorPoint(anchorX, anchorY), finalX, finalY)
    local skinSettings = cfg.skinSettings
    if type(skinSettings) == "function" then skinSettings = skinSettings(plugin) end
    local col, row = 0, 0
    for _, aura in ipairs(auras) do
        local icon = frame[poolKey]:Acquire()
        icon:EnableMouse(false)
        plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
        plugin:SetupAuraTooltip(icon, aura, unit, cfg.tooltipFilter)
        col, row = AL:PositionIcon(icon, container, justifyH, selfAnchorY, col, row, iconSize, iconsPerRow, #auras, iconsPerCol)
    end
    container:Show()
end

-- [ SINGLE AURA ICON DISPLAY ]----------------------------------------------------------------------
function Mixin:UpdateSingleAuraIcon(frame, plugin, iconKey, filter, iconSize)
    local icon = frame[iconKey]
    if not icon then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled(iconKey) then icon:Hide(); return end
    local unit = frame.unit
    if not unit or not UnitExists(unit) or not UnitIsConnected(unit) then icon:Hide(); return end
    -- Use snapshot when available, fall back to FetchAuras
    local aura
    local snap = frame._auraSnapshot
    local snapAuras = snap and (filter:find("HARMFUL") and snap.harmful or snap.helpful)
    if snapAuras then
        for _, a in ipairs(snapAuras) do
            if a.auraInstanceID and not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, a.auraInstanceID, filter) then
                aura = a; break
            end
        end
    else
        local fetched = plugin:FetchAuras(unit, filter, 1)
        aura = fetched[1]
        if aura and (not aura.auraInstanceID or not plugin:IsAuraIncluded(unit, aura.auraInstanceID, filter)) then aura = nil end
    end
    if not aura then icon:Hide(); return end
    local skinSettings = Orbit.Constants.Aura.SkinNoTimer
    plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
    plugin:SetupAuraTooltip(icon, aura, unit, filter:find("HARMFUL") and "HARMFUL" or "HELPFUL")
    icon:Show()
end

-- [ DEFENSIVE & CC ICON DISPLAY ]-------------------------------------------------------------------
function Mixin:UpdateDefensiveIcon(frame, plugin, iconSize)
    self:UpdateSingleAuraIcon(frame, plugin, "DefensiveIcon", "HELPFUL|BIG_DEFENSIVE", iconSize)
    if frame.DefensiveIcon and not frame.DefensiveIcon:IsShown() then
        self:UpdateSingleAuraIcon(frame, plugin, "DefensiveIcon", "HELPFUL|EXTERNAL_DEFENSIVE", iconSize)
    end
end

function Mixin:UpdateCrowdControlIcon(frame, plugin, iconSize)
    self:UpdateSingleAuraIcon(frame, plugin, "CrowdControlIcon", "HARMFUL|CROWD_CONTROL", iconSize)
end

-- [ LAZY ICON CREATION ]----------------------------------------------------------------------------
local HEALER_ICON_FRAME_LEVEL_OFFSET = Orbit.Constants.Levels.Overlay
local DEFAULT_HEALER_SKIN = Orbit.Constants.Aura.SkinNoTimer

function Mixin:EnsureAuraIcon(frame, iconKey, iconSize)
    if frame[iconKey] then return frame[iconKey] end
    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    btn:SetSize(iconSize, iconSize)
    btn.orbitOriginalWidth, btn.orbitOriginalHeight = iconSize, iconSize
    btn:SetPoint("CENTER", frame, "CENTER", 0, 0)
    btn:SetFrameLevel(frame:GetFrameLevel() + HEALER_ICON_FRAME_LEVEL_OFFSET)
    btn.Icon = btn:CreateTexture(nil, "ARTWORK")
    btn.Icon:SetAllPoints()
    btn.icon = btn.Icon
    btn:EnableMouse(false)
    btn:Hide()
    frame[iconKey] = btn
    return btn
end

-- Read saved overrides for a component key from plugin settings.
local function GetComponentOverrides(plugin, iconKey)
    if not plugin or not plugin.GetSetting then return nil end
    local positions = plugin:GetSetting(1, "ComponentPositions")
    if not positions or not positions[iconKey] then return nil end
    return positions[iconKey].overrides
end

local function BuildSkinSettings(overrides, remainingPercent)
    if not overrides then return DEFAULT_HEALER_SKIN end
    local showTimer = overrides.ShowTimer == true
    local needsCopy = overrides.SwipeColorCurve or overrides.PandemicGlowType or overrides.PandemicGlowColorCurve
    if not needsCopy then return showTimer and Orbit.Constants.Aura.SkinWithTimer or Orbit.Constants.Aura.SkinNoTimer end
    local skin = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = showTimer }
    if overrides.SwipeColorCurve then
        local color = OrbitEngine.ColorCurve and OrbitEngine.ColorCurve:SampleColorCurve(overrides.SwipeColorCurve, remainingPercent or 1)
        if color then skin.swipeColor = color end
    end
    if overrides.PandemicGlowType then skin.pandemicGlowType = overrides.PandemicGlowType end
    if overrides.PandemicGlowColorCurve then
        local color = OrbitEngine.ColorCurve and OrbitEngine.ColorCurve:GetFirstColorFromCurve(overrides.PandemicGlowColorCurve)
        if color then skin.pandemicColor = color end
    end
    return skin
end

-- [ SPELL-ID AURA ICON DISPLAY ]-------------------------------------------------------------------
local SPELL_AURA_SCAN_MAX = 40
local IsSecret = issecretvalue

-- OnUpdate handler for continuous curve sampling on healer aura icons
local function HealerCurveOnUpdate(icon)
    if not icon:IsShown() then return end
    local d = icon._orbitCurveData
    if not d then return end
    local remainingPercent = 1
    if d.duration > 0 and d.expirationTime then
        remainingPercent = math_max(0, (d.expirationTime - GetTime()) / d.duration)
    end
    local CCE = OrbitEngine.ColorCurve
    if d.swipeCurve and icon.Cooldown then
        local c = CCE:SampleColorCurve(d.swipeCurve, remainingPercent)
        if c then
            local cd = icon.Cooldown
            local swipeTex = Orbit.Constants.Assets.SwipeCustom
            cd.orbitUpdating = true
            cd:SetSwipeTexture(swipeTex)
            cd:SetSwipeColor(c.r, c.g, c.b, c.a or 0.8)
            cd.orbitUpdating = false
            cd.orbitDesiredSwipe = cd.orbitDesiredSwipe or {}
            cd.orbitDesiredSwipe.texture = swipeTex
            cd.orbitDesiredSwipe.r = c.r
            cd.orbitDesiredSwipe.g = c.g
            cd.orbitDesiredSwipe.b = c.b
            cd.orbitDesiredSwipe.a = c.a or 0.8
        end
    end
    if d.timerCurve and icon.Cooldown then
        local text = icon.Cooldown.Text
        if text and text.SetTextColor then
            local c = CCE:SampleColorCurve(d.timerCurve, remainingPercent)
            if c then text:SetTextColor(c.r or 1, c.g or 1, c.b or 1) end
        end
    end
end

function Mixin:UpdateSpellAuraIcon(frame, plugin, iconKey, spellId, iconSize, altSpellId)
    if frame.preview or (OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame) then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled(iconKey) then
        if frame[iconKey] then frame[iconKey]:Hide() end
        return
    end
    local unit = frame.unit
    if not unit or not UnitExists(unit) or not UnitIsConnected(unit) then
        if frame[iconKey] then frame[iconKey]:Hide() end
        return
    end
    local overrides = GetComponentOverrides(plugin, iconKey)
    local snap = frame._auraSnapshot or self:BuildAuraSnapshot(unit)
    local aura = snap.helpfulPlayerBySpell[spellId] or (altSpellId and snap.helpfulPlayerBySpell[altSpellId])
    if aura then
        local icon = self:EnsureAuraIcon(frame, iconKey, iconSize)
        local remainingPercent = 1
        if aura.duration and aura.duration > 0 and aura.expirationTime then
            remainingPercent = math_max(0, (aura.expirationTime - GetTime()) / aura.duration)
        end
        local skinSettings = BuildSkinSettings(overrides, remainingPercent)
        self:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
        self:SetupAuraTooltip(icon, aura, unit, "HELPFUL")
        if skinSettings.pandemicGlowType and skinSettings.pandemicGlowType > 0 then
            Orbit.PandemicGlow:Apply(icon, aura, unit, skinSettings)
            if icon.PandemicIcon then icon.PandemicIcon:SetAlpha(0) end
        elseif icon.orbitPandemicGlowActive then
            Orbit.PandemicGlow:Stop(icon)
        end
        local hasCurves = overrides and (overrides.SwipeColorCurve or overrides.TimerTextColorCurve)
        if hasCurves then
            icon._orbitCurveData = {
                duration = aura.duration or 0,
                expirationTime = aura.expirationTime,
                swipeCurve = overrides.SwipeColorCurve,
                timerCurve = overrides.TimerTextColorCurve,
            }
            if not icon._orbitCurveHooked then
                icon._orbitCurveHooked = true
                icon:HookScript("OnUpdate", function(self) HealerCurveOnUpdate(self) end)
            end
            HealerCurveOnUpdate(icon)
        else
            icon._orbitCurveData = nil
        end
        icon:Show()
        return
    end
    if frame[iconKey] then
        frame[iconKey]._orbitCurveData = nil
        if frame[iconKey].orbitPandemicGlowActive then Orbit.PandemicGlow:Stop(frame[iconKey]) end
        frame[iconKey]:Hide()
    end
end

-- [ MISSING BUFF ICON DISPLAY ]--------------------------------------------------------------------
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local MISSING_GLOW_KEY = "orbitMissing"
local GlowType = { Pixel = 1, Proc = 2, AutoCast = 3, Button = 4 }

local function ApplyMissingGlow(icon, overrides)
    if not LCG or not overrides then return end
    local glowType = overrides.ProcGlowType
    if not glowType or glowType == 0 then return end
    local color = { 1, 0.2, 0.2, 1 }
    if overrides.ProcGlowColorCurve and OrbitEngine.ColorCurve then
        local c = OrbitEngine.ColorCurve:SampleColorCurve(overrides.ProcGlowColorCurve, 1)
        if c then color = { c.r, c.g, c.b, c.a or 1 } end
    end
    if glowType == GlowType.Pixel then
        LCG.PixelGlow_Start(icon, color, 8, 0.25, 4, 2, 0, 0, false, MISSING_GLOW_KEY)
    elseif glowType == GlowType.Proc then
        LCG.ProcGlow_Start(icon, { color = color, startAnim = false, key = MISSING_GLOW_KEY })
    elseif glowType == GlowType.AutoCast then
        LCG.AutoCastGlow_Start(icon, color, 4, 0.12, 2, 2, MISSING_GLOW_KEY)
    elseif glowType == GlowType.Button then
        LCG.ButtonGlow_Start(icon, color, 0.3)
    end
    icon.orbitMissingGlowActive = glowType
end

local function StopMissingGlow(icon)
    if not LCG then return end
    local active = icon.orbitMissingGlowActive
    if active == GlowType.Pixel then LCG.PixelGlow_Stop(icon, MISSING_GLOW_KEY)
    elseif active == GlowType.Proc then LCG.ProcGlow_Stop(icon, MISSING_GLOW_KEY)
    elseif active == GlowType.AutoCast then LCG.AutoCastGlow_Stop(icon, MISSING_GLOW_KEY)
    elseif active == GlowType.Button then LCG.ButtonGlow_Stop(icon) end
    icon.orbitMissingGlowActive = nil
end

-- [ MISSING RAID BUFF CONTAINER ]------------------------------------------------------------------
local RAID_BUFF_ICON_SPACING = 1
function Mixin:UpdateMissingRaidBuffs(frame, plugin, containerKey, raidBuffs, iconSize)
    if frame.preview or (OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame) then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled(containerKey) then
        if frame[containerKey] then frame[containerKey]:Hide() end
        return
    end
    local unit = frame.unit
    if not unit or not UnitExists(unit) or not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
        if frame[containerKey] then frame[containerKey]:Hide() end
        return
    end

    local snap = frame._auraSnapshot or self:BuildAuraSnapshot(unit)
    local present = snap.helpfulBySpell
    -- Collect missing buffs (only YOUR class's raid buff, from any caster)
    local missing = {}
    for _, buff in ipairs(raidBuffs) do
        if not present[buff.spellId] then missing[#missing + 1] = buff end
    end
    if #missing == 0 then
        if frame[containerKey] then
            local container = frame[containerKey]
            if container._raidIcons then
                for _, icon in ipairs(container._raidIcons) do
                    StopMissingGlow(icon); icon.orbitMissingGlowActive = nil; icon:Hide()
                end
            end
            container:Hide()
        end
        return
    end
    -- Ensure container (replace stale Button from old code if missing _raidIcons)
    local container = frame[containerKey]
    if not container or not container._raidIcons then
        if container then container:Hide() end
        container = CreateFrame("Frame", nil, frame)
        container:SetPoint("CENTER", frame, "CENTER", 0, 0)
        container:SetFrameLevel(frame:GetFrameLevel() + HEALER_ICON_FRAME_LEVEL_OFFSET)
        container._raidIcons = {}
        container:Hide()
        frame[containerKey] = container
    end
    -- Ensure enough sub-icons
    for idx = 1, #missing do
        if not container._raidIcons[idx] then
            local icon = CreateFrame("Frame", nil, container, "BackdropTemplate")
            icon.Icon = icon:CreateTexture(nil, "ARTWORK")
            icon.Icon:SetAllPoints()
            icon.icon = icon.Icon
            icon:EnableMouse(true)
            icon:SetMouseClickEnabled(false)
            icon:Hide()
            container._raidIcons[idx] = icon
        end
    end
    -- Hide excess icons
    for idx = #missing + 1, #container._raidIcons do
        StopMissingGlow(container._raidIcons[idx])
        container._raidIcons[idx].orbitMissingGlowActive = nil
        container._raidIcons[idx]:Hide()
    end
    -- Layout missing icons
    local overrides = GetComponentOverrides(plugin, containerKey)
    for idx, buff in ipairs(missing) do
        local icon = container._raidIcons[idx]
        local tex = C_Spell.GetSpellTexture(buff.spellId)
        if tex then icon.Icon:SetTexture(tex); icon.Icon:SetAllPoints(icon); icon.Icon:Show() end
        icon:SetSize(iconSize, iconSize)
        self:ApplyAuraSkin(icon, DEFAULT_HEALER_SKIN)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", container, "LEFT", (idx - 1) * (iconSize + RAID_BUFF_ICON_SPACING), 0)
        local sid = buff.spellId
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:SetSpellByID(sid)
            GameTooltip:AddLine("|cffff4444Missing|r", 1, 0, 0)
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        if not icon.orbitMissingGlowActive then ApplyMissingGlow(icon, overrides) end
        icon:Show()
    end
    local totalW = #missing * iconSize + (#missing - 1) * RAID_BUFF_ICON_SPACING
    container:SetSize(totalW, iconSize)
    container.orbitOriginalWidth, container.orbitOriginalHeight = totalW, iconSize
    container:Show()
    container:SetAlphaFromBoolean(UnitInRange(unit), 1, 0)
end

-- [ RAID BUFF CONTAINER FACTORY ]------------------------------------------------------------------
function Mixin:EnsureRaidBuffContainer(frame, containerKey, raidBuffs, iconSize)
    local container = frame[containerKey]
    if not container or not container._raidIcons then
        if container then container:Hide() end
        container = CreateFrame("Frame", nil, frame)
        container:SetPoint("CENTER", frame, "CENTER", 0, 0)
        container:SetFrameLevel(frame:GetFrameLevel() + HEALER_ICON_FRAME_LEVEL_OFFSET)
        container._raidIcons = {}
        frame[containerKey] = container
    end
    for idx, buff in ipairs(raidBuffs) do
        if not container._raidIcons[idx] then
            local icon = CreateFrame("Frame", nil, container, "BackdropTemplate")
            icon.Icon = icon:CreateTexture(nil, "ARTWORK")
            icon.Icon:SetAllPoints()
            icon.icon = icon.Icon
            icon:EnableMouse(true)
            icon:SetMouseClickEnabled(false)
            container._raidIcons[idx] = icon
        end
        local icon = container._raidIcons[idx]
        local tex = C_Spell.GetSpellTexture(buff.spellId)
        if tex then icon.Icon:SetTexture(tex); icon.Icon:Show() end
        icon:SetSize(iconSize, iconSize)
        self:ApplyAuraSkin(icon, DEFAULT_HEALER_SKIN)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", container, "LEFT", (idx - 1) * (iconSize + RAID_BUFF_ICON_SPACING), 0)
        icon:Show()
    end
    local totalW = #raidBuffs * iconSize + (#raidBuffs - 1) * RAID_BUFF_ICON_SPACING
    container:SetSize(totalW, iconSize)
    container.orbitOriginalWidth, container.orbitOriginalHeight = totalW, iconSize
    -- Expose first sub-icon's texture as container.Icon for Canvas Mode detection
    if container._raidIcons[1] then container.Icon = container._raidIcons[1].Icon end
    return container
end
