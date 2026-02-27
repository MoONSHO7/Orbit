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

-- [ SKIN FACADE ]-----------------------------------------------------------------------------------
function Mixin:ApplyAuraSkin(icon, settings)
    if not icon or not Orbit.Skin or not Orbit.Skin.Icons then return end
    Orbit.Skin.Icons:ApplyCustom(icon, settings or { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = true })
end

-- [ AURA POOL CREATION ]----------------------------------------------------------------------------
function Mixin:CreateAuraPool(frame, template, parent)
    if frame.auraPool then return frame.auraPool end
    frame.auraPool = CreateFramePool("Button", parent or frame, template or "BackdropTemplate")
    return frame.auraPool
end

function Mixin:FetchAuras(unit, filter, maxCount)
    local auras = {}
    if unit and UnitExists(unit) then
        local count = maxCount or DEFAULT_AURA_COUNT
        for i = 1, count do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
            if not aura then break end
            aura.index = i
            tinsert(auras, aura)
        end
    end
    return auras
end

-- [ ICON SETUP ]------------------------------------------------------------------------------------
function Mixin:SetupAuraIcon(icon, aura, size, unit, skinSettings)
    if not icon or not aura then return end
    icon:SetSize(size, size)
    if not icon.Icon then icon.Icon = icon:CreateTexture(nil, "ARTWORK") end
    icon.icon = icon.Icon
    icon.Icon:SetTexture(aura.icon)
    icon.Icon:ClearAllPoints()
    icon.Icon:SetAllPoints(icon)
    icon.Icon:Show()
    if not icon.Overlay then
        icon.Overlay = CreateFrame("Frame", nil, icon)
        icon.Overlay:SetAllPoints(icon)
        icon.Overlay:SetFrameLevel(icon:GetFrameLevel() + 2)
    end
    if not icon.count then
        icon.count = icon.Overlay:CreateFontString(nil, "OVERLAY")
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    local fontPath = (LSM and fontName and LSM:Fetch("font", fontName)) or "Fonts\\FRIZQT__.TTF"
    local fontOutline = Orbit.Skin and Orbit.Skin.GetFontOutline and Orbit.Skin:GetFontOutline() or ""
    local countSize = Orbit.Skin:GetAdaptiveTextSize(size, 8, nil, 0.4)
    icon.count:SetFont(fontPath, countSize, fontOutline)
    icon.count:SetShadowColor(0, 0, 0, 1)
    icon.count:SetShadowOffset(1, -1)
    icon.count:ClearAllPoints()
    icon.count:SetPoint("BOTTOMRIGHT", icon.Overlay, "BOTTOMRIGHT", -1, 1)
    icon.count:SetJustifyH("RIGHT")
    self:ApplyAuraCooldown(icon, aura, unit)
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
            timerText:SetFont(fontPath, Orbit.Skin:GetAdaptiveTextSize(size, 8, nil, 0.45), fontOutline)
        end
        icon.Cooldown:SetHideCountdownNumbers(size < TIMER_MIN_ICON_SIZE)
    end
    if skinSettings and skinSettings.enablePandemic then Orbit.PandemicGlow:Apply(icon, aura, unit, skinSettings) end
    icon:Show()
    return icon
end

function Mixin:ApplyAuraCooldown(icon, aura, unit)
    if not icon or not icon.Cooldown then return end
    local applied = false
    if aura.duration and aura.expirationTime and aura.duration > 0 then
        local startTime = aura.expirationTime - aura.duration
        if startTime > 0 then
            icon.Cooldown:SetCooldown(startTime, aura.duration)
            applied = true
        end
    end
    if not applied then icon.Cooldown:Clear() end
end

function Mixin:ApplyAuraCount(icon, aura, unit)
    if not icon or not icon.count then return end
    if aura.applications and aura.applications > 1 then
        local displayCount = aura.applications
        if displayCount > 99 then displayCount = 99 end
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
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        if aura.auraInstanceID and unit then
            GameTooltip:SetUnitAura(unit, aura.auraInstanceID, filter)
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
    frame[poolKey]:ReleaseAll()
    local auras
    if cfg.postFilter then
        local rawAuras = plugin:FetchAuras(unit, cfg.fetchFilter, cfg.fetchMax or 40)
        auras = cfg.postFilter(plugin, unit, rawAuras, maxIcons)
    else
        auras = plugin:FetchAuras(unit, cfg.fetchFilter, maxIcons)
    end
    if #auras == 0 then container:Hide(); return end
    local helpers = type(cfg.helpers) == "function" and cfg.helpers() or cfg.helpers
    local position = helpers:AnchorToPosition(auraData.posX, auraData.posY, frameW / 2, frameH / 2)
    local iconSize, _, iconsPerRow, containerW, containerH = AL:CalculateSmartLayout(frameW, frameH, position, maxIcons, #auras, overrides)
    container:ClearAllPoints()
    container:SetSize(containerW, containerH)
    local anchorX = auraData.anchorX or cfg.defaultAnchorX or "LEFT"
    local anchorY = auraData.anchorY or cfg.defaultAnchorY or "CENTER"
    local offsetX = auraData.offsetX or 0
    local offsetY = auraData.offsetY or 0
    local justifyH = auraData.justifyH or cfg.defaultJustifyH or "LEFT"
    local finalX = (anchorX == "RIGHT") and -offsetX or offsetX
    local finalY = (anchorY == "TOP") and -offsetY or offsetY
    container:SetPoint(BuildComponentSelfAnchor(false, true, anchorY, justifyH), frame, BuildAnchorPoint(anchorX, anchorY), finalX, finalY)
    local skinSettings = cfg.skinSettings
    if type(skinSettings) == "function" then skinSettings = skinSettings(plugin) end
    local col, row = 0, 0
    for _, aura in ipairs(auras) do
        local icon = frame[poolKey]:Acquire()
        icon:EnableMouse(false)
        plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
        plugin:SetupAuraTooltip(icon, aura, unit, cfg.tooltipFilter)
        col, row = AL:PositionIcon(icon, container, justifyH, anchorY, col, row, iconSize, iconsPerRow)
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
    local auras = plugin:FetchAuras(unit, filter, 1)
    local aura = auras[1]
    if not aura or not aura.auraInstanceID or not plugin:IsAuraIncluded(unit, aura.auraInstanceID, filter) then icon:Hide(); return end
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = false }
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
