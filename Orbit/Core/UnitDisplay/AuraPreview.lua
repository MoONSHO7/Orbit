-- [ ORBIT AURA PREVIEW ]-----------------------------------------------------------------------------
local _, Orbit = ...
Orbit.AuraPreview = {}
local AP = Orbit.AuraPreview

local OrbitEngine = Orbit.Engine
local AL = Orbit.AuraLayout
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local PREVIEW_SKIN = Orbit.Constants.Aura.SkinWithTimer
local PREVIEW_TIMER_MIN_SIZE = 14
local PREVIEW_COOLDOWN_MIN = 1
local PREVIEW_COOLDOWN_MAX = 5
local PREVIEW_PAA_SPACING = 1
local PREVIEW_PAA_COUNT = 3

-- [ CACHED PREVIEW ICONS ]---------------------------------------------------------------------------
local PREVIEW_BUFF_ICONS = { 135932, 136085, 135987, 132292, 135753, 136075, 135884, 136205, 135963, 136033, 135964, 136101 }
local PREVIEW_DEBUFF_ICONS = { 136016, 136188, 136140, 136133, 132099, 136066, 135952, 132104, 136160, 136118, 136130, 135903 }
local BUFF_COUNT, DEBUFF_COUNT = #PREVIEW_BUFF_ICONS, #PREVIEW_DEBUFF_ICONS
local function GetSpellbookIcon(auraType)
    if auraType == "debuff" then return PREVIEW_DEBUFF_ICONS[math.random(1, DEBUFF_COUNT)] end
    return PREVIEW_BUFF_ICONS[math.random(1, BUFF_COUNT)]
end

function AP:ShowIcons(frame, auraType, posData, numIcons, overrides, cfg)
    local containerKey = auraType .. "Container"
    local poolKey = "preview" .. auraType:gsub("^%l", string.upper) .. "s"
    if numIcons == 0 then if frame[containerKey] then frame[containerKey]:Hide() end; return end
    if not frame[containerKey] then frame[containerKey] = CreateFrame("Frame", nil, frame) end
    local container = frame[containerKey]
    container:SetParent(frame)
    container:SetFrameStrata(Orbit.Constants.Strata.HUD)
    container:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Border)
    container:Show()
    local helpers = cfg.helpers()
    local frameW, frameH = frame:GetWidth(), frame:GetHeight()
    local position = helpers:AnchorToPosition(posData.posX, posData.posY, frameW / 2, frameH / 2)
    local scale = frame:GetEffectiveScale() or 1
    local iconSize, _, iconsPerRow, containerW, containerH, iconsPerCol = AL:CalculateSmartLayout(frameW, frameH, position, numIcons, numIcons, overrides, scale)
    container:SetSize(containerW, containerH)
    container:ClearAllPoints()
    local anchorX = posData.anchorX or (cfg.defaultAnchorX or "RIGHT")
    local anchorY = posData.anchorY or "CENTER"
    local justifyH = posData.justifyH or (cfg.defaultJustifyH or "LEFT")
    local offsetX, offsetY = posData.offsetX or 0, posData.offsetY or 0
    local selfAnchorY = posData.selfAnchorY or anchorY
    local anchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)
    local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(false, true, selfAnchorY, justifyH)
    local finalX, finalY = offsetX, offsetY
    if anchorX == "RIGHT" then finalX = -offsetX end
    if anchorY == "TOP" then finalY = -offsetY end
    finalX, finalY = OrbitEngine.Pixel:SnapPosition(finalX, finalY, selfAnchor, containerW, containerH, scale)
    container:SetPoint(selfAnchor, frame, anchorPoint, finalX, finalY)
    if not frame[poolKey] then frame[poolKey] = {} end
    for _, icon in ipairs(frame[poolKey]) do icon:Hide() end
    local col, row = 0, 0
    for idx = 1, numIcons do
        local icon = frame[poolKey][idx]
        if not icon then
            icon = CreateFrame("Button", nil, container, "BackdropTemplate")
            icon.Icon = icon:CreateTexture(nil, "ARTWORK")
            icon.Icon:SetAllPoints()
            icon.icon = icon.Icon
            icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
            icon.Cooldown:SetAllPoints()
            icon.Cooldown:SetHideCountdownNumbers(false)
            icon.cooldown = icon.Cooldown
            frame[poolKey][idx] = icon
        end
        icon:SetParent(container)
        icon:SetSize(iconSize, iconSize)
        if not icon.Icon:GetTexture() then icon.Icon:SetTexture(GetSpellbookIcon(auraType)) end
        if Orbit.Skin and Orbit.Skin.Icons then Orbit.Skin.Icons:ApplyCustom(icon, PREVIEW_SKIN) end
        local fontPath = (LSM and LSM:Fetch("font", Orbit.db.GlobalSettings.Font)) or "Fonts\\FRIZQT__.TTF"
        local fontOutline = Orbit.Skin:GetFontOutline()
        local timerText = icon.Cooldown.Text
        if not timerText then
            for _, region in pairs({ icon.Cooldown:GetRegions() }) do
                if region:IsObjectType("FontString") then timerText = region; break end
            end
            icon.Cooldown.Text = timerText
        end
        if timerText and timerText.SetFont then
            timerText:SetFont(fontPath, 8, fontOutline)
            Orbit.Skin:ApplyFontShadow(timerText)
        end
        icon.Cooldown:SetHideCountdownNumbers(iconSize < PREVIEW_TIMER_MIN_SIZE)
        if Orbit.PreviewAnimator:IsRunning() then
            icon.Cooldown:SetCooldown(GetTime(), math.random(PREVIEW_COOLDOWN_MIN, PREVIEW_COOLDOWN_MAX))
            icon.Cooldown:Show()
        else
            icon.Cooldown:Clear()
            icon.Cooldown:Hide()
        end
        col, row = AL:PositionIcon(icon, container, justifyH, selfAnchorY, col, row, iconSize, iconsPerRow, numIcons, iconsPerCol)
        icon:Show()
    end
    container._justifyH = justifyH
    container._anchorY = selfAnchorY
    container._iconSize = iconSize
    container._iconsPerRow = iconsPerRow
end

function AP:ShowFrameAuras(plugin, frame, debuffCfg, buffCfg)
    local positions = plugin:GetComponentPositions(1)
    local debuffData = positions.Debuffs or {}
    local buffData = positions.Buffs or {}
    local debuffOff = plugin.IsComponentDisabled and plugin:IsComponentDisabled("Debuffs")
    local buffOff = plugin.IsComponentDisabled and plugin:IsComponentDisabled("Buffs")
    local maxDebuffs = (debuffData.overrides or {}).MaxIcons or debuffCfg.defaultMax or 3
    local maxBuffs = (buffData.overrides or {}).MaxIcons or buffCfg.defaultMax or 3
    AP:ShowIcons(frame, "debuff", debuffData, debuffOff and 0 or maxDebuffs, debuffData.overrides, debuffCfg)
    AP:ShowIcons(frame, "buff", buffData, buffOff and 0 or maxBuffs, buffData.overrides, buffCfg)
end

function AP:HideFrameAuras(frame)
    for _, key in ipairs({ "previewDebuffs", "previewBuffs" }) do
        if frame[key] then
            for _, icon in ipairs(frame[key]) do icon:Hide() end
        end
    end
    if frame.debuffContainer then frame.debuffContainer:Hide() end
    if frame.buffContainer then frame.buffContainer:Hide() end
end

function AP:InitAnimatedAuras(plugin, frame, helpers)
    local dCfg = { helpers = helpers, defaultAnchorX = "RIGHT", defaultJustifyH = "LEFT" }
    local bCfg = { helpers = helpers, defaultAnchorX = "LEFT", defaultJustifyH = "RIGHT" }
    AP:ShowFrameAuras(plugin, frame, dCfg, bCfg)
    local groups = {}
    for _, info in ipairs({
        { pool = "previewBuffs", cont = "buffContainer" },
        { pool = "previewDebuffs", cont = "debuffContainer" },
    }) do
        local container = frame[info.cont]
        local pool = frame[info.pool]
        if container and pool then
            local icons = {}
            for _, icon in ipairs(pool) do icons[#icons + 1] = icon; icon:Hide() end
            if #icons > 0 then
                groups[#groups + 1] = { container = container, icons = icons }
            end
        end
    end
    return groups
end

AP.GetSpellbookIcon = GetSpellbookIcon
function AP:ReleaseIconProvider() end

function AP:ShowPrivateAuras(frame, posData, baseIconSize)
    local paa = frame.PrivateAuraAnchor
    if not paa then return end
    local overrides = posData and posData.overrides
    local iconSize = (overrides and overrides.IconSize) or baseIconSize
    local totalWidth = (PREVIEW_PAA_COUNT * iconSize) + ((PREVIEW_PAA_COUNT - 1) * PREVIEW_PAA_SPACING)
    local anchorX = (posData and posData.anchorX) or "CENTER"
    local growDir = (posData and posData.justifyH) or anchorX
    local paaTexture = Orbit.StatusIconMixin:GetPrivateAuraTexture()
    paa.Icon:SetTexture(nil)
    local paaScale = paa:GetEffectiveScale() or 1
    local snappedIconSize = OrbitEngine.Pixel:Snap(iconSize, paaScale)
    local snappedTotalWidth = OrbitEngine.Pixel:Snap(totalWidth, paaScale)
    paa:SetSize(snappedTotalWidth, snappedIconSize)
    if not posData or not posData.anchorX then
        paa:ClearAllPoints()
        paa:SetPoint("CENTER", frame, "BOTTOM", 0, OrbitEngine.Pixel:Snap(iconSize * 0.5 + 2, frame:GetEffectiveScale() or 1))
    end
    paa._previewIcons = paa._previewIcons or {}
    for pi = 1, PREVIEW_PAA_COUNT do
        local sub = paa._previewIcons[pi]
        if not sub then
            sub = CreateFrame("Frame", nil, paa)
            sub.Icon = sub:CreateTexture(nil, "ARTWORK")
            sub.Icon:SetAllPoints()
            sub.icon = sub.Icon
            sub:EnableMouse(false)
            paa._previewIcons[pi] = sub
        end
        sub:SetParent(paa)
        sub:SetSize(snappedIconSize, snappedIconSize)
        sub.Icon:SetTexture(paaTexture)
        sub:ClearAllPoints()
        local stride = OrbitEngine.Pixel:Snap((pi - 1) * (snappedIconSize + PREVIEW_PAA_SPACING), paaScale)
        if growDir == "RIGHT" then sub:SetPoint("TOPRIGHT", paa, "TOPRIGHT", -stride, 0)
        elseif growDir == "LEFT" then sub:SetPoint("TOPLEFT", paa, "TOPLEFT", stride, 0)
        else
            local centeredStart = -(snappedTotalWidth - snappedIconSize) / 2
            sub:SetPoint("CENTER", paa, "CENTER", OrbitEngine.Pixel:Snap(centeredStart + stride, paaScale), 0)
        end
        sub:Show()
    end
    for pi = PREVIEW_PAA_COUNT + 1, #(paa._previewIcons or {}) do paa._previewIcons[pi]:Hide() end
    paa:Show()
end
