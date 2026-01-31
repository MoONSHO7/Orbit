-- [ ORBIT AURA MIXIN ]------------------------------------------------------------------------------
-- Shared functionality for aura/debuff display (TargetFrame buffs, BossFrame debuffs)
-- Consolidates icon setup, cooldown handling, and grid layout logic

local _, addonTable = ...
local Orbit = addonTable

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
    PANDEMIC_CURVE:AddPoint(0.00, 0)    -- 0% remaining = don't show pandemics on passive effects.
    PANDEMIC_CURVE:AddPoint(0.01, 1)    -- Pandemic all the way to 0
    PANDEMIC_CURVE:AddPoint(0.30, 1)    -- ≤30% remaining = show glow
    PANDEMIC_CURVE:AddPoint(0.301, 0)   -- >30% remaining = hide glow
    PANDEMIC_CURVE:AddPoint(1.0, 0)
end

local DEFAULT_AURA_COUNT = 40
local TOOLTIP_ANCHOR_THRESHOLD = 0.7

-- [ AURA POOL CREATION ]----------------------------------------------------------------------------

function Mixin:CreateAuraPool(frame, template, parent)
    if frame.auraPool then
        return frame.auraPool
    end

    template = template or "BackdropTemplate"
    parent = parent or frame

    frame.auraPool = CreateFramePool("Button", parent, template)
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
                aura.index = i -- Preserve index for tooltip fallback
                table.insert(auras, aura)
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

    -- Icon texture (support both capital and lowercase naming)
    if not icon.Icon then
        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
        -- SetAllPoints handled by Skin.Icons:ApplyCustom
    end
    icon.icon = icon.Icon
    icon.Icon:SetTexture(aura.icon)
    icon.Icon:SetDrawLayer("ARTWORK")

    -- Cooldown frame
    if not icon.Cooldown then
        icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        -- SetAllPoints handled by Skin.Icons:ApplyCustom
        icon.Cooldown:SetHideCountdownNumbers(false)
        icon.Cooldown:SetDrawEdge(true)
        icon.Cooldown:SetDrawSwipe(true)
        icon.Cooldown.noCooldownCount = false
        -- Ensure Cooldown is above Icon (+1) but below Overlay (+10) and Border (+5)
        icon.Cooldown:SetFrameLevel(icon:GetFrameLevel() + 2)
    end
    icon.cooldown = icon.Cooldown

    -- Overlay for stack count (use frame level, not strata, to avoid appearing above UI dialogs)
    if not icon.Overlay then
        icon.Overlay = CreateFrame("Frame", nil, icon)
        icon.Overlay:SetAllPoints()
        icon.Overlay:SetFrameLevel(icon:GetFrameLevel() + 10)
    end

    -- Stack count - use global font settings
    if not icon.count then
        icon.count = icon.Overlay:CreateFontString(nil, "OVERLAY")
    else
        icon.count:SetParent(icon.Overlay)
    end

    -- Apply global font settings
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontName = Orbit.db.GlobalSettings.Font
    local fontPath = (LSM and LSM:Fetch("font", fontName)) or "Fonts\\FRIZQT__.TTF"
    local fontSize = math.max(8, size * 0.4) -- Scale font with icon size, min 8
    icon.count:SetFont(fontPath, fontSize, "OUTLINE")
    icon.count:SetShadowColor(0, 0, 0, 1)
    icon.count:SetShadowOffset(1, -1)

    icon.count:ClearAllPoints()
    icon.count:SetPoint("BOTTOMRIGHT", icon.Overlay, "BOTTOMRIGHT", -1, 1)
    icon.count:SetJustifyH("RIGHT")

    -- Apply cooldown (secret-value safe)
    self:ApplyAuraCooldown(icon, aura, unit)

    -- Apply stack count (secret-value safe, needs unit for GetAuraApplicationDisplayCount)
    self:ApplyAuraCount(icon, aura, unit)

    -- Apply Skin
    if skinSettings and Orbit.Skin and Orbit.Skin.Icons then
        Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
    end

    -- Apply pandemic glow for player-applied buffs (if enabled in skinSettings)
    if skinSettings and skinSettings.enablePandemic then
        self:ApplyPandemicGlow(icon, aura, unit, skinSettings)
    end

    icon:Show()
    return icon
end

-- [ COOLDOWN APPLICATION ]--------------------------------------------------------------------------

function Mixin:ApplyAuraCooldown(icon, aura, unit)
    if not icon or not icon.Cooldown then
        return
    end

    local applied = false

    -- Method 1: Duration Object (Safe for Secret Values in 12.0+)
    if
        aura.auraInstanceID
        and C_UnitAuras
        and C_UnitAuras.GetAuraDuration
        and icon.Cooldown.SetCooldownFromDurationObject
    then
        local ok, durationObj = pcall(C_UnitAuras.GetAuraDuration, unit, aura.auraInstanceID)
        if ok and durationObj then
            if pcall(icon.Cooldown.SetCooldownFromDurationObject, icon.Cooldown, durationObj) then
                applied = true
                icon.Cooldown:Show()
            end
        end
    end

    if not applied then
        icon.Cooldown:Hide()
    end
end

-- [ STACK COUNT ]-----------------------------------------------------------------------------------
-- GetAuraApplicationDisplayCount returns nil if count < minDisplayCount (default 2)
-- For enemy units in combat, values may be secret - use canaccessvalue to check

function Mixin:ApplyAuraCount(icon, aura, unit)
    if not icon or not icon.count then
        return
    end

    -- Use GetAuraApplicationDisplayCount (12.0+ API)
    -- Usage: GetAuraApplicationDisplayCount(unit, auraInstanceID, min, max)
    -- This handles logic (like min count 2) inside the API, returning a value only if it should show.
    if C_UnitAuras.GetAuraApplicationDisplayCount and aura.auraInstanceID and unit then
        -- Pass 2 as min count (don't show 1), 1000 as max
        local ok, displayCount = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, aura.auraInstanceID, 2, 1000)

        if ok and displayCount then
            -- We can pass secret values directly to SetText
            -- This marks the fontstring with a secret aspect but displays the correct value
            icon.count:SetText(displayCount)
            icon.count:Show()
            return
        end
    end

    -- No valid count - hide the count
    icon.count:SetText("")
    icon.count:Hide()
end

-- [ PANDEMIC GLOW ]---------------------------------------------------------------------------------
-- Uses duration curve to detect if aura is in pandemic window (<30% remaining)
-- Works with secret values by using EvaluateRemainingPercent + SetAlpha pattern
-- Supports all glow types via skinSettings.pandemicGlowType and skinSettings.pandemicGlowColor

function Mixin:ApplyPandemicGlow(icon, aura, unit, skinSettings)
    if not icon or not aura then
        return
    end

    -- Ensure LibCustomGlow is available
    if not LibCustomGlow then
        return
    end

    -- Ensure we have the curve and duration API available
    if not PANDEMIC_CURVE or not C_UnitAuras or not C_UnitAuras.GetAuraDuration then
        return
    end

    -- Need auraInstanceID for duration object
    if not aura.auraInstanceID then
        return
    end

    -- Get glow settings from skinSettings or use defaults
    local GlowType = Orbit.Constants.PandemicGlow.Type
    local GlowConfig = Orbit.Constants.PandemicGlow
    
    local glowType = (skinSettings and skinSettings.pandemicGlowType) or GlowConfig.DefaultType
    local glowColor = (skinSettings and skinSettings.pandemicGlowColor) or GlowConfig.DefaultColor
    
    -- If glow type is None, stop any existing glow and return
    if glowType == GlowType.None then
        self:StopPandemicGlow(icon)
        return
    end
    
    local GLOW_KEY = "orbitPandemic"
    local colorTable = { glowColor.r or 1, glowColor.g or 0.8, glowColor.b or 0, glowColor.a or 1 }

    -- KEY FIX: If glow is already running with same type, just update aura references
    -- This prevents animation restart on every UNIT_AURA update
    if icon.orbitPandemicGlowActive == glowType then
        -- Same glow type already running - just update aura data for OnUpdate
        icon.orbitAura = aura
        icon.orbitUnit = unit
        icon.orbitPandemicAuraID = aura.auraInstanceID
        return
    end

    -- Different glow type or no glow yet - need to start
    -- Stop any existing glow first if type changed
    if icon.orbitPandemicGlowActive then
        self:StopPandemicGlow(icon)
    end
    
    -- Store aura data on icon for OnUpdate
    icon.orbitAura = aura
    icon.orbitUnit = unit
    icon.orbitPandemicAuraID = aura.auraInstanceID

    -- Start the glow based on type (it will be controlled via alpha)
    if glowType == GlowType.Pixel then
        local cfg = GlowConfig.Pixel
        LibCustomGlow.PixelGlow_Start(
            icon,
            colorTable,
            cfg.Lines,
            cfg.Frequency,
            cfg.Length,
            cfg.Thickness,
            cfg.XOffset,
            cfg.YOffset,
            cfg.Border,
            GLOW_KEY
        )
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
        LibCustomGlow.AutoCastGlow_Start(
            icon,
            colorTable,
            cfg.Particles,
            cfg.Frequency,
            cfg.Scale,
            cfg.XOffset,
            cfg.YOffset,
            GLOW_KEY
        )
        icon.orbitPandemicGlowActive = GlowType.Autocast
    elseif glowType == GlowType.Button then
        local cfg = GlowConfig.Button
        LibCustomGlow.ButtonGlow_Start(icon, colorTable, cfg.Frequency, cfg.FrameLevel)
        icon.orbitPandemicGlowActive = GlowType.Button
    end

    -- Get the glow frame that LibCustomGlow created
    local glowFrame = icon["_PixelGlow" .. GLOW_KEY] 
        or icon["_ProcGlow" .. GLOW_KEY] 
        or icon["_AutoCastGlow" .. GLOW_KEY]
        or icon["__ButtonGlow"]
    
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

-- Stop pandemic glow (all types)
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

-- Cleanup pandemic glow when icon is released
function Mixin:CleanupPandemicGlow(icon)
    if not icon then
        return
    end

    self:StopPandemicGlow(icon)
    
    icon.orbitAura = nil
    icon.orbitUnit = nil
    icon.orbitPandemicAuraID = nil
    icon.orbitPandemicGlowType = nil
end

-- [ TOOLTIP SETUP ]---------------------------------------------------------------------------------

-- Helper: Choose tooltip anchor based on icon position (avoid offscreen tooltips)
local function GetSmartTooltipAnchor(icon)
    if not icon or not icon.GetRight then
        return "ANCHOR_BOTTOMRIGHT"
    end

    local screenWidth = GetScreenWidth()
    local iconRight = icon:GetRight()

    -- If icon is in right 30% of screen, flip tooltip to left side
    if iconRight and screenWidth and iconRight > (screenWidth * TOOLTIP_ANCHOR_THRESHOLD) then
        return "ANCHOR_BOTTOMLEFT"
    end
    return "ANCHOR_BOTTOMRIGHT"
end

function Mixin:SetupAuraTooltip(icon, aura, unit, filter)
    if not icon or not aura then
        return
    end

    filter = filter or "HELPFUL"
    local isHarmful = filter:find("HARMFUL")

    icon:SetScript("OnEnter", function(self)
        local anchor = GetSmartTooltipAnchor(self)
        GameTooltip:SetOwner(self, anchor)

        -- Use auraInstanceID-based APIs (secret-value safe, 12.0+)
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

    -- Pixel Snap Layout
    if Orbit.Engine.Pixel then
        local scale = frame:GetEffectiveScale()
        size = Orbit.Engine.Pixel:Snap(size, scale)
        spacing = Orbit.Engine.Pixel:Snap(spacing, scale)
        currentX = Orbit.Engine.Pixel:Snap(currentX, scale)
        currentY = Orbit.Engine.Pixel:Snap(currentY, scale)
    end

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
    
    if Orbit.Engine.Pixel then
        local scale = container:GetEffectiveScale()
        size = Orbit.Engine.Pixel:Snap(size, scale)
        spacing = Orbit.Engine.Pixel:Snap(spacing, scale)
    end

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

-- [ SKIN APPLICATION ]------------------------------------------------------------------------------

function Mixin:ApplyAuraSkin(icon, settings)
    if not icon then
        return
    end
    if not Orbit.Skin or not Orbit.Skin.Icons then
        return
    end

    settings = settings
        or {
            zoom = 0,
            borderStyle = 1,
            borderSize = 1,
            showTimer = true,
        }

    Orbit.Skin.Icons:ApplyCustom(icon, settings)
end
