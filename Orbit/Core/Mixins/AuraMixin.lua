-- [ ORBIT AURA MIXIN ]------------------------------------------------------------------------------
-- Shared functionality for aura/debuff display (icon setup, cooldown handling, grid layout)

local _, addonTable = ...
local Orbit = addonTable
local pcall, type, ipairs = pcall, type, ipairs
local math_max = math.max
local tinsert = table.insert

---@class OrbitAuraMixin
Orbit.AuraMixin = {}
local Mixin = Orbit.AuraMixin

-- LibCustomGlow for pandemic glows
local LibCustomGlow = LibStub and LibStub("LibCustomGlow-1.0", true)

-- Pandemic threshold curve: <30% remaining = 1 (show glow), >30% = 0 (hide)
-- Created once at load time, reused for all icons
local PANDEMIC_CURVE
if C_CurveUtil and C_CurveUtil.CreateCurve then
    PANDEMIC_CURVE = C_CurveUtil.CreateCurve()
    PANDEMIC_CURVE:AddPoint(0.00, 0) -- 0% remaining = don't show pandemics on passive effects.
    PANDEMIC_CURVE:AddPoint(0.01, 1) -- Pandemic all the way to 0
    PANDEMIC_CURVE:AddPoint(0.30, 1) -- ≤30% remaining = show glow
    PANDEMIC_CURVE:AddPoint(0.301, 0) -- >30% remaining = hide glow
    PANDEMIC_CURVE:AddPoint(1.0, 0)
end

local DEFAULT_AURA_COUNT = 40
local TIMER_MIN_ICON_SIZE = 14

-- [ AURA POOL CREATION ]----------------------------------------------------------------------------

function Mixin:CreateAuraPool(frame, template, parent)
    if frame.auraPool then
        return frame.auraPool
    end
    frame.auraPool = CreateFramePool("Button", parent or frame, template or "BackdropTemplate")
    return frame.auraPool
end

-- [ AURA FETCHING ]---------------------------------------------------------------------------------
function Mixin:FetchAuras(unit, filter, maxCount)
    local auras = {}
    maxCount = maxCount or DEFAULT_AURA_COUNT
    if C_UnitAuras.GetUnitAuras then
        local ok, result = pcall(C_UnitAuras.GetUnitAuras, unit, filter, nil, nil)
        if ok and type(result) == "table" then
            for i, aura in ipairs(result) do
                if i > maxCount then
                    break
                end
                aura.index = i
                tinsert(auras, aura)
            end
            return auras
        end
    end
    return auras
end

-- [ ICON SETUP ]------------------------------------------------------------------------------------

function Mixin:SetupAuraIcon(icon, aura, size, unit, skinSettings)
    if not icon or not aura then
        return
    end

    icon:SetSize(size, size)
    if not icon.Icon then
        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    end
    icon.icon = icon.Icon
    icon.Icon:SetTexture(aura.icon)
    icon.Icon:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Icon)
    if not icon.Cooldown then
        icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.Cooldown:SetDrawEdge(true)
        icon.Cooldown:SetDrawSwipe(true)
        icon.Cooldown.noCooldownCount = false
        icon.Cooldown:SetFrameLevel(icon:GetFrameLevel() + 2)
    end
    icon.cooldown = icon.Cooldown
    if not icon.Overlay then
        icon.Overlay = CreateFrame("Frame", nil, icon)
        icon.Overlay:SetAllPoints()
        icon.Overlay:SetFrameLevel(icon:GetFrameLevel() + 10)
    end
    if not icon.count then
        icon.count = icon.Overlay:CreateFontString(nil, "OVERLAY")
    else
        icon.count:SetParent(icon.Overlay)
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontPath = (LSM and LSM:Fetch("font", Orbit.db.GlobalSettings.Font)) or "Fonts\\FRIZQT__.TTF"
    local fontOutline = Orbit.Skin:GetFontOutline()
    local countSize = Orbit.Skin:GetAdaptiveTextSize(size, 8, nil, 0.4)
    icon.count:SetFont(fontPath, countSize, fontOutline)
    icon.count:SetShadowColor(0, 0, 0, 1)
    icon.count:SetShadowOffset(1, -1)
    icon.count:ClearAllPoints()
    icon.count:SetPoint("BOTTOMRIGHT", icon.Overlay, "BOTTOMRIGHT", -1, 1)
    icon.count:SetJustifyH("RIGHT")
    self:ApplyAuraCooldown(icon, aura, unit)
    self:ApplyAuraCount(icon, aura, unit)

    -- Apply global font to cooldown countdown timer text
    if icon.Cooldown then
        local timerText = icon.Cooldown.Text
        if not timerText then
            for _, region in pairs({ icon.Cooldown:GetRegions() }) do
                if region:IsObjectType("FontString") then
                    timerText = region
                    break
                end
            end
            icon.Cooldown.Text = timerText
        end
        if timerText and timerText.SetFont then
            local timerSize = Orbit.Skin:GetAdaptiveTextSize(size, 8, nil, 0.45)
            timerText:SetFont(fontPath, timerSize, fontOutline)
        end
    end

    if skinSettings and Orbit.Skin and Orbit.Skin.Icons then
        Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
    end

    -- Size-based timer gate runs AFTER ApplyCustom so it has final authority
    if icon.Cooldown then
        icon.Cooldown:SetHideCountdownNumbers(size < TIMER_MIN_ICON_SIZE)
    end
    if skinSettings and skinSettings.enablePandemic then
        self:ApplyPandemicGlow(icon, aura, unit, skinSettings)
    end
    icon:Show()
    return icon
end

function Mixin:ApplyAuraCooldown(icon, aura, unit)
    if not icon or not icon.Cooldown then
        return
    end
    local applied = false
    if aura.auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDuration and icon.Cooldown.SetCooldownFromDurationObject then
        local ok, durationObj = pcall(C_UnitAuras.GetAuraDuration, unit, aura.auraInstanceID)
        if ok and durationObj and pcall(icon.Cooldown.SetCooldownFromDurationObject, icon.Cooldown, durationObj) then
            applied = true
            icon.Cooldown:Show()
        end
    end
    if not applied then
        icon.Cooldown:Hide()
    end
end

-- GetAuraApplicationDisplayCount returns nil if count < minDisplayCount (default 2)
function Mixin:ApplyAuraCount(icon, aura, unit)
    if not icon or not icon.count then
        return
    end
    if C_UnitAuras.GetAuraApplicationDisplayCount and aura.auraInstanceID and unit then
        local ok, displayCount = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, aura.auraInstanceID, 2, 1000)
        if ok and displayCount then
            icon.count:SetText(displayCount)
            icon.count:Show()
            return
        end
    end
    icon.count:SetText("")
    icon.count:Hide()
end

-- Pandemic glow: uses duration curve to detect <30% remaining
function Mixin:ApplyPandemicGlow(icon, aura, unit, skinSettings)
    if not icon or not aura or not LibCustomGlow then
        return
    end
    if not PANDEMIC_CURVE or not C_UnitAuras or not C_UnitAuras.GetAuraDuration or not aura.auraInstanceID then
        return
    end

    local GlowType = Orbit.Constants.PandemicGlow.Type
    local GlowConfig = Orbit.Constants.PandemicGlow
    local glowType = (skinSettings and skinSettings.pandemicGlowType) or GlowConfig.DefaultType
    local glowColor = (skinSettings and skinSettings.pandemicGlowColor) or GlowConfig.DefaultColor
    if glowType == GlowType.None then
        self:StopPandemicGlow(icon)
        return
    end
    local GLOW_KEY = "orbitPandemic"
    local colorTable = { glowColor.r or 1, glowColor.g or 0.8, glowColor.b or 0, glowColor.a or 1 }

    -- If same glow already running, just update aura refs
    if icon.orbitPandemicGlowActive == glowType then
        icon.orbitAura, icon.orbitUnit, icon.orbitPandemicAuraID = aura, unit, aura.auraInstanceID
        return
    end
    if icon.orbitPandemicGlowActive then
        self:StopPandemicGlow(icon)
    end
    icon.orbitAura, icon.orbitUnit, icon.orbitPandemicAuraID = aura, unit, aura.auraInstanceID

    -- Start the glow based on type (it will be controlled via alpha)
    if glowType == GlowType.Pixel then
        local cfg = GlowConfig.Pixel
        LibCustomGlow.PixelGlow_Start(icon, colorTable, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, GLOW_KEY)
        icon.orbitPandemicGlowActive = GlowType.Pixel
    elseif glowType == GlowType.Proc then
        local cfg = GlowConfig.Proc
        -- Calculate scale based on icon size vs standard 64px button
        local iconWidth = icon:GetWidth() or 64
        local scale = iconWidth / 64
        LibCustomGlow.ProcGlow_Start(icon, {
            color = colorTable,
            startAnim = false, -- Disable start animation to avoid oversized flash
            duration = cfg.Duration,
            scale = scale,
            key = GLOW_KEY,
        })
        icon.orbitPandemicGlowActive = GlowType.Proc
    elseif glowType == GlowType.Autocast then
        local cfg = GlowConfig.Autocast
        LibCustomGlow.AutoCastGlow_Start(icon, colorTable, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, GLOW_KEY)
        icon.orbitPandemicGlowActive = GlowType.Autocast
    elseif glowType == GlowType.Button then
        local cfg = GlowConfig.Button
        LibCustomGlow.ButtonGlow_Start(icon, colorTable, cfg.Frequency, cfg.FrameLevel)
        icon.orbitPandemicGlowActive = GlowType.Button
    end

    -- Get the glow frame that LibCustomGlow created
    local glowFrame = icon["_PixelGlow" .. GLOW_KEY] or icon["_ProcGlow" .. GLOW_KEY] or icon["_AutoCastGlow" .. GLOW_KEY] or icon["__ButtonGlow"]

    if glowFrame then
        -- Initially hide the glow
        glowFrame:SetAlpha(0)
    end

    -- Create controller frame for OnUpdate if not exists (reuse across updates)
    if not icon.PandemicController then
        icon.PandemicController = CreateFrame("Frame", nil, icon)

        -- OnUpdate handler to check pandemic state (only set once per icon)
        local updateInterval = 0.1
        local elapsed = 0

        icon.PandemicController:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed < updateInterval then
                return
            end
            elapsed = 0

            local parentIcon = self:GetParent()
            -- Defensive check: if icon is hidden or recycled, skip update
            if not parentIcon:IsVisible() then
                return
            end
            if not parentIcon.orbitAura or not parentIcon.orbitUnit then
                return
            end

            -- Get the appropriate glow frame
            local glow = parentIcon["_PixelGlow" .. GLOW_KEY]
                or parentIcon["_ProcGlow" .. GLOW_KEY]
                or parentIcon["_AutoCastGlow" .. GLOW_KEY]
                or parentIcon["__ButtonGlow"]
            if not glow then
                return
            end

            -- Get fresh duration object each update (auras can be refreshed)
            local ok, durObj = pcall(C_UnitAuras.GetAuraDuration, parentIcon.orbitUnit, parentIcon.orbitAura.auraInstanceID)
            if not ok or not durObj then
                -- Aura gone - hide glow
                glow:SetAlpha(0)
                return
            end

            -- Evaluate remaining percent using our pandemic curve
            -- Result is a secret number: 1 if <30% remaining (pandemic), 0 otherwise
            -- We can pass this directly to SetAlpha (secret sink pattern)
            local ok2, pandemicAlpha = pcall(durObj.EvaluateRemainingPercent, durObj, PANDEMIC_CURVE)
            if ok2 and pandemicAlpha then
                glow:SetAlpha(pandemicAlpha)
            end
        end)
    end
end

function Mixin:StopPandemicGlow(icon)
    if not icon or not LibCustomGlow then
        return
    end
    local GLOW_KEY = "orbitPandemic"
    LibCustomGlow.PixelGlow_Stop(icon, GLOW_KEY)
    LibCustomGlow.ProcGlow_Stop(icon, GLOW_KEY)
    LibCustomGlow.AutoCastGlow_Stop(icon, GLOW_KEY)
    LibCustomGlow.ButtonGlow_Stop(icon)
    icon.orbitPandemicGlowActive = nil
end

function Mixin:CleanupPandemicGlow(icon)
    if not icon then
        return
    end
    self:StopPandemicGlow(icon)
    icon.orbitAura, icon.orbitUnit, icon.orbitPandemicAuraID, icon.orbitPandemicGlowType = nil, nil, nil, nil
end



function Mixin:SetupAuraTooltip(icon, aura, unit, filter)
    if not icon or not aura then
        return
    end
    filter = filter or "HELPFUL"
    local isHarmful = filter:find("HARMFUL")
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        if aura.auraInstanceID then
            if isHarmful then
                pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, unit, aura.auraInstanceID, filter)
            else
                pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, unit, aura.auraInstanceID, filter)
            end
        end
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- [ GRID LAYOUT ]-----------------------------------------------------------------------------------

function Mixin:LayoutAurasGrid(frame, icons, config)
    config = config or {}

    local size = config.size or 20
    local spacing = config.spacing or 2
    local maxPerRow = config.maxPerRow or 8
    local anchor = config.anchor or "BOTTOMLEFT"
    local xOffset = config.xOffset or 0
    local yOffset = config.yOffset or 0
    local growthY = config.growthY or "DOWN"

    local col = 0
    local currentX = xOffset
    local currentY = yOffset

    local scale = frame:GetEffectiveScale()
    size = Orbit.Engine.Pixel:Snap(size, scale)
    spacing = Orbit.Engine.Pixel:Snap(spacing, scale)
    currentX = Orbit.Engine.Pixel:Snap(currentX, scale)
    currentY = Orbit.Engine.Pixel:Snap(currentY, scale)

    -- Determine layout direction parameters
    local iconPoint, yStep
    if growthY == "UP" then
        iconPoint = "BOTTOMLEFT"
        yStep = size + spacing
    else
        iconPoint = "TOPLEFT"
        yStep = -(size + spacing)
        -- Default yOffset adjustment for DOWN if not specified (legacy compat)
        if not config.yOffset then
            currentY = -4
        end
    end

    for i, icon in ipairs(icons) do
        icon:ClearAllPoints()

        if col >= maxPerRow then
            col = 0
            currentY = currentY + yStep
            currentX = xOffset
        end

        icon:SetPoint(iconPoint, frame, anchor, currentX, currentY)
        currentX = currentX + size + spacing
        col = col + 1
    end
end

-- [ LINEAR LAYOUT (Left/Right) ]--------------------------------------------------------------------

function Mixin:LayoutAurasLinear(container, icons, config)
    config = config or {}

    local size = config.size or 20
    local spacing = config.spacing or 2
    local growDirection = config.growDirection or "RIGHT"

    local xOffset = 0

    local scale = container:GetEffectiveScale()
    size = Orbit.Engine.Pixel:Snap(size, scale)
    spacing = Orbit.Engine.Pixel:Snap(spacing, scale)

    for i, icon in ipairs(icons) do
        icon:ClearAllPoints()

        if growDirection == "LEFT" then
            icon:SetPoint("TOPRIGHT", container, "TOPRIGHT", -xOffset, 0)
        else
            icon:SetPoint("TOPLEFT", container, "TOPLEFT", xOffset, 0)
        end

        xOffset = xOffset + size + spacing
    end

    -- Update container size
    container:SetSize(xOffset > 0 and xOffset or 1, size)
end

function Mixin:ApplyAuraSkin(icon, settings)
    if not icon or not Orbit.Skin or not Orbit.Skin.Icons then return end
    Orbit.Skin.Icons:ApplyCustom(icon, settings or { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = true })
end

-- [ SMART AURA LAYOUT ]-----------------------------------------------------------------------------

local SMART_AURA_SPACING = 1
local SMART_MIN_ICON_SIZE = 10
local SMART_DEFAULT_ICON_SIZE = 10

function Mixin:CalculateSmartAuraLayout(frameW, frameH, position, maxIcons, numIcons, overrides)
    local isHorizontal = (position == "Above" or position == "Below")
    local maxRows = (overrides and overrides.MaxRows) or 2
    local iconSize = math_max(SMART_MIN_ICON_SIZE, (overrides and overrides.IconSize) or SMART_DEFAULT_ICON_SIZE)
    local rows, iconsPerRow, containerWidth, containerHeight
    if isHorizontal then
        iconsPerRow = math_max(1, math.floor((frameW + SMART_AURA_SPACING) / (iconSize + SMART_AURA_SPACING)))
        rows = math.min(maxRows, math.ceil(numIcons / iconsPerRow))
        local displayCols = math.min(math.min(numIcons, iconsPerRow * rows), iconsPerRow)
        containerWidth = (displayCols * iconSize) + ((displayCols - 1) * SMART_AURA_SPACING)
        containerHeight = (rows * iconSize) + ((rows - 1) * SMART_AURA_SPACING)
    else
        rows = math.min(maxRows, math_max(1, numIcons))
        iconsPerRow = math.ceil(numIcons / rows)
        containerWidth = math_max(iconSize, (iconsPerRow * iconSize) + ((iconsPerRow - 1) * SMART_AURA_SPACING))
        containerHeight = (rows * iconSize) + ((rows - 1) * SMART_AURA_SPACING)
    end
    return iconSize, rows, iconsPerRow, containerWidth, containerHeight
end

-- [ AURA ICON POSITIONING ]-------------------------------------------------------------------------

function Mixin:PositionAuraIcon(icon, container, justifyH, anchorY, col, row, iconSize, iconsPerRow)
    local xOff = col * (iconSize + SMART_AURA_SPACING)
    local yOff = row * (iconSize + SMART_AURA_SPACING)
    icon:ClearAllPoints()
    local growDown = (anchorY ~= "BOTTOM")
    if justifyH == "RIGHT" then
        if growDown then icon:SetPoint("TOPRIGHT", container, "TOPRIGHT", -xOff, -yOff)
        else icon:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -xOff, yOff) end
    else
        if growDown then icon:SetPoint("TOPLEFT", container, "TOPLEFT", xOff, -yOff)
        else icon:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOff, yOff) end
    end
    local nextCol = col + 1
    local nextRow = row
    if nextCol >= iconsPerRow then nextCol = 0; nextRow = row + 1 end
    return nextCol, nextRow
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
    local iconSize, _, iconsPerRow, containerW, containerH = self:CalculateSmartAuraLayout(frameW, frameH, position, maxIcons, #auras, overrides)

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
        col, row = self:PositionAuraIcon(icon, container, justifyH, anchorY, col, row, iconSize, iconsPerRow)
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

-- [ DEFENSIVE ICON DISPLAY ]------------------------------------------------------------------------

function Mixin:UpdateDefensiveIcon(frame, plugin, iconSize)
    self:UpdateSingleAuraIcon(frame, plugin, "DefensiveIcon", "HELPFUL|BIG_DEFENSIVE", iconSize)
    if frame.DefensiveIcon and not frame.DefensiveIcon:IsShown() then
        self:UpdateSingleAuraIcon(frame, plugin, "DefensiveIcon", "HELPFUL|EXTERNAL_DEFENSIVE", iconSize)
    end
end

-- [ CROWD CONTROL ICON DISPLAY ]--------------------------------------------------------------------

function Mixin:UpdateCrowdControlIcon(frame, plugin, iconSize)
    self:UpdateSingleAuraIcon(frame, plugin, "CrowdControlIcon", "HARMFUL|CROWD_CONTROL", iconSize)
end

-- [ PREVIEW AURA ICON DISPLAY ]---------------------------------------------------------------------

local PREVIEW_SKIN = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = true }
local PREVIEW_TIMER_MIN_SIZE = 14
local PREVIEW_COOLDOWN_ELAPSED = 10
local PREVIEW_COOLDOWN_DURATION = 60

function Mixin:ShowPreviewAuraIcons(frame, auraType, posData, numIcons, sampleIcons, overrides, cfg)
    local containerKey = auraType .. "Container"
    local poolKey = "preview" .. auraType:gsub("^%l", string.upper) .. "s"
    if numIcons == 0 then
        if frame[containerKey] then frame[containerKey]:Hide() end
        return
    end
    if not frame[containerKey] then frame[containerKey] = CreateFrame("Frame", nil, frame) end
    local container = frame[containerKey]
    container:SetParent(frame)
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Highlight)
    container:Show()
    local helpers = cfg.helpers()
    local frameW, frameH = frame:GetWidth(), frame:GetHeight()
    local position = helpers:AnchorToPosition(posData.posX, posData.posY, frameW / 2, frameH / 2)
    local iconSize, _, iconsPerRow, containerW, containerH = self:CalculateSmartAuraLayout(frameW, frameH, position, numIcons, numIcons, overrides)
    container:SetSize(containerW, containerH)
    container:ClearAllPoints()
    local anchorX = posData.anchorX or (cfg.defaultAnchorX or "RIGHT")
    local anchorY = posData.anchorY or "CENTER"
    local justifyH = posData.justifyH or (cfg.defaultJustifyH or "LEFT")
    local offsetX, offsetY = posData.offsetX or 0, posData.offsetY or 0
    local anchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)
    local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(false, true, anchorY, justifyH)
    local finalX, finalY = offsetX, offsetY
    if anchorX == "RIGHT" then finalX = -offsetX end
    if anchorY == "TOP" then finalY = -offsetY end
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
        icon.Icon:SetTexture(sampleIcons[((idx - 1) % #sampleIcons) + 1])
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
            timerText:SetFont(fontPath, Orbit.Skin:GetAdaptiveTextSize(iconSize, 8, nil, 0.45), fontOutline)
        end
        icon.Cooldown:SetHideCountdownNumbers(iconSize < PREVIEW_TIMER_MIN_SIZE)
        icon.Cooldown:SetCooldown(GetTime() - PREVIEW_COOLDOWN_ELAPSED, PREVIEW_COOLDOWN_DURATION)
        icon.Cooldown:Show()
        col, row = self:PositionAuraIcon(icon, container, justifyH, anchorY, col, row, iconSize, iconsPerRow)
        icon:Show()
    end
end

-- [ PREVIEW PRIVATE AURA ANCHORS ]-----------------------------------------------------------------

local PREVIEW_PAA_SKIN = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = false }
local PREVIEW_PAA_SPACING = 1
local PREVIEW_PAA_COUNT = 3

function Mixin:ShowPreviewPrivateAuras(frame, posData, baseIconSize)
    local paa = frame.PrivateAuraAnchor
    if not paa then return end
    local overrides = posData and posData.overrides
    local paaScale = (overrides and overrides.Scale) or 1
    local iconSize = math.floor(baseIconSize * paaScale)
    local totalWidth = (PREVIEW_PAA_COUNT * iconSize) + ((PREVIEW_PAA_COUNT - 1) * PREVIEW_PAA_SPACING)
    local anchorX = (posData and posData.anchorX) or "CENTER"
    local paaTexture = Orbit.StatusIconMixin:GetPrivateAuraTexture()
    paa.Icon:SetTexture(nil)
    paa:SetSize(totalWidth, iconSize)
    if not posData or not posData.anchorX then
        paa:ClearAllPoints()
        paa:SetPoint("CENTER", frame, "BOTTOM", 0, OrbitEngine.Pixel:Snap(iconSize * 0.5 + 2, frame:GetEffectiveScale() or 1))
    end
    paa._previewIcons = paa._previewIcons or {}
    for pi = 1, PREVIEW_PAA_COUNT do
        local sub = paa._previewIcons[pi]
        if not sub then
            sub = CreateFrame("Button", nil, paa, "BackdropTemplate")
            sub.Icon = sub:CreateTexture(nil, "ARTWORK")
            sub.Icon:SetAllPoints()
            sub.icon = sub.Icon
            sub:EnableMouse(false)
            paa._previewIcons[pi] = sub
        end
        sub:SetParent(paa)
        sub:SetSize(iconSize, iconSize)
        sub.Icon:SetTexture(paaTexture)
        sub:ClearAllPoints()
        if anchorX == "RIGHT" then
            sub:SetPoint("TOPRIGHT", paa, "TOPRIGHT", -((pi - 1) * (iconSize + PREVIEW_PAA_SPACING)), 0)
        elseif anchorX == "LEFT" then
            sub:SetPoint("TOPLEFT", paa, "TOPLEFT", (pi - 1) * (iconSize + PREVIEW_PAA_SPACING), 0)
        else
            local centeredStart = -(totalWidth - iconSize) / 2
            sub:SetPoint("CENTER", paa, "CENTER", centeredStart + (pi - 1) * (iconSize + PREVIEW_PAA_SPACING), 0)
        end
        if Orbit.Skin and Orbit.Skin.Icons then Orbit.Skin.Icons:ApplyCustom(sub, PREVIEW_PAA_SKIN) end
        sub:Show()
    end
    for pi = PREVIEW_PAA_COUNT + 1, #(paa._previewIcons or {}) do paa._previewIcons[pi]:Hide() end
    paa:Show()
end
