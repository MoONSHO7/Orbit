-- [ ORBIT AURA MIXIN ]------------------------------------------------------------------------------
-- Shared functionality for aura/debuff display (TargetFrame buffs, BossFrame debuffs)
-- Consolidates icon setup, cooldown handling, and grid layout logic

local _, addonTable = ...
local Orbit = addonTable

---@class OrbitAuraMixin
Orbit.AuraMixin = {}
local Mixin = Orbit.AuraMixin

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

    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
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
    local fontName = (Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font) or "Friz Quadrata TT"
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

    -- Method 1: Use GetAuraApplicationDisplayCount (12.0+ API)
    -- Usage: GetAuraApplicationDisplayCount(unit, auraInstanceID, min, max)
    -- This handles logic (like min count 2) inside the API, returning a value only if it should show.
    if C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount and aura.auraInstanceID and unit then
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

    -- Method 2: Fallback to aura.applications for non-secret values
    -- Only use this if we can safely compare the value (not secret)
    local count = aura.applications or aura.count
    if count and (not canaccessvalue or canaccessvalue(count)) then
        if type(count) == "number" and count > 1 then
            icon.count:SetText(count)
            icon.count:Show()
            return
        end
    end

    -- No valid count or secret fallback - hide the count
    icon.count:SetText("")
    icon.count:Hide()
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

        local success = false

        -- Method 1: Use auraInstanceID-based APIs (secret-value safe, preferred)
        if aura.auraInstanceID then
            if isHarmful then
                success =
                    pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, unit, aura.auraInstanceID, filter)
            else
                success = pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, unit, aura.auraInstanceID, filter)
            end
        end

        -- Method 2: Fallback to index-based SetUnitAura (only if out of combat)
        if not success and aura.index and not InCombatLockdown() then
            success = pcall(GameTooltip.SetUnitAura, GameTooltip, unit, aura.index, filter)
        end

        -- Method 3: Last resort - use spellId but ONLY if we can verify it's not secret
        if not success and aura.spellId then
            -- Check if spellId is a secret value before using
            if not issecretvalue or not issecretvalue(aura.spellId) then
                pcall(GameTooltip.SetSpellByID, GameTooltip, aura.spellId)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff777777(Limited info during combat)|r")
            else
                -- spellId is secret, show nothing or generic text
                GameTooltip:AddLine("|cff777777Aura info unavailable during combat|r")
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
