-- [ TRACKED ICON ITEM ] -------------------------------------------------------
-- Single icon button used inside a TrackedContainer (icons mode). Pure factory:
-- creates the frame, owns the cooldown swipe + charge text + drop highlight,
-- and exposes Update(plugin, icon) so the container can refresh state in bulk.
-- The container owns event registration; this module is stateless.
local _, Orbit = ...

local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ] ---------------------------------------------------------------
local PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local FONT_SIZE_DEFAULT = 12
local ACTIVE_GLOW_KEY = "orbitActive"

-- DESAT curve maps cooldown remaining-percent to a 0/1 desaturation flag.
-- Spending a defensive AddPoint(0.001, 1) keeps the curve stable when the
-- DurationObject reports an exact 0 remaining (just-started cooldown).
local DESAT_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0)
    c:AddPoint(0.001, 1)
    c:AddPoint(1.0, 1)
    return c
end)()

-- IDENTITY_CURVE maps remaining-percent (secret) → itself (numeric). Required
-- for Lua-side state detection (active vs cooldown phase breakpoint).
local IDENTITY_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0.0)
    c:AddPoint(1.0, 1.0)
    return c
end)()

local GC = OrbitEngine.GlowController

-- [ MODULE ] ------------------------------------------------------------------
Orbit.TrackedIconItem = {}
local IconItem = Orbit.TrackedIconItem

-- [ FONT APPLIER ] ------------------------------------------------------------
-- Reads GlobalSettings.Font (via plugin:GetGlobalFont) and FontOutline (via
-- Orbit.Skin:GetFontOutline) and applies to the icon's ChargeText and Cooldown
-- timer text. Called from TrackedContainer:Apply on every layout pass so global
-- font/outline changes propagate without rebuilding the icons.
function IconItem:ApplyFont(plugin, icon)
    local font = plugin:GetGlobalFont() or STANDARD_TEXT_FONT
    local outline = Orbit.Skin and Orbit.Skin:GetFontOutline() or "OUTLINE"
    icon.ChargeText:SetFont(font, FONT_SIZE_DEFAULT, outline)
    self:StyleCooldownText(icon.Cooldown, font, outline)
end

-- [ COOLDOWN TEXT STYLE ] -----------------------------------------------------
-- Finds and styles the Cooldown frame's built-in FontString with global font.
-- The CooldownFrameTemplate creates a FontString for the countdown timer;
-- we enable it, reparent to TextOverlay, and apply consistent styling.
function IconItem:StyleCooldownText(cd, font, outline)
    if not cd then return end
    -- Enable countdown numbers (disabled by default in some templates)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    local fs = cd.Text
    if not fs then
        for _, region in ipairs({ cd:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                fs = region
                cd.Text = fs
                break
            end
        end
    end
    if not fs then return end
    fs:SetFont(font, FONT_SIZE_DEFAULT, outline)
    fs:SetDrawLayer("OVERLAY", 7)
    if Orbit.Skin and Orbit.Skin.ApplyFontShadow then Orbit.Skin:ApplyFontShadow(fs) end
end

-- [ SWIPE COLOR APPLIER ] -----------------------------------------------------
-- Applies the CooldownSwipeColorCurve setting to the Cooldown frame's swipe.
-- Called from TrackedContainer:Apply on every layout pass.
function IconItem:ApplySwipeColor(plugin, icon, systemIndex)
    local colorCurve = plugin:GetSetting(systemIndex, "CooldownSwipeColorCurve")
    if colorCurve and colorCurve.pins and colorCurve.pins[1] then
        local c = colorCurve.pins[1].color
        if c and icon.Cooldown then icon.Cooldown:SetSwipeColor(c.r or 0, c.g or 0, c.b or 0, c.a or 0.8) end
    end
end

-- [ CANVAS COMPONENT APPLY ] --------------------------------------------------
-- Applies the saved ChargeText position and font overrides for one icon.
-- Reads from the parent CONTAINER's record (record.id == systemIndex) so all
-- icons in the same container share the same component layout. Disabled state
-- force-hides the text via icon._chargeTextDisabled, which the per-tick Update
-- path checks before re-showing. Mirrors CooldownText:ApplyTextSettings.
function IconItem:ApplyCanvasComponents(plugin, icon, systemIndex)
    local positions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
    local disabledList = plugin:GetSetting(systemIndex, "DisabledComponents") or {}
    local disabledSet = {}
    for _, k in ipairs(disabledList) do disabledSet[k] = true end

    local pos = positions.ChargeText
    icon._chargeTextDisabled = disabledSet.ChargeText or false
    if disabledSet.ChargeText then
        icon.ChargeText:Hide()
        return
    end

    local OverrideUtils = OrbitEngine.OverrideUtils
    if OverrideUtils then
        local overrides = pos and pos.overrides or {}
        local fontPath = plugin:GetGlobalFont()
        OverrideUtils.ApplyOverrides(icon.ChargeText, overrides, { fontSize = FONT_SIZE_DEFAULT, fontPath = fontPath })
    end

    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
    if ApplyTextPosition then
        ApplyTextPosition(icon.ChargeText, icon, pos, "BOTTOMRIGHT", -2, 2)
    end
end

-- [ FACTORY ] -----------------------------------------------------------------
-- Builds an icon-item frame parented to `container`. The container is responsible
-- for sizing and anchoring the icon — this factory only sets up the textures and
-- input wiring. `removeCallback(icon)` runs on shift-right-click; the container
-- supplies it.
function IconItem:Build(container, removeCallback)
    local icon = CreateFrame("Frame", nil, container, "BackdropTemplate")
    OrbitEngine.Pixel:Enforce(icon)
    icon:SetSize(Constants.Cooldown.DefaultIconSize, Constants.Cooldown.DefaultIconSize)
    icon.trackedType = nil
    icon.trackedId = nil

    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()
    icon.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.Cooldown:SetAllPoints()
    icon.Cooldown:SetDrawSwipe(true)
    icon.Cooldown:SetDrawBling(false)
    icon.Cooldown:Clear()

    icon.ActiveCooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.ActiveCooldown:SetAllPoints()
    icon.ActiveCooldown:SetDrawSwipe(true)
    icon.ActiveCooldown:SetDrawBling(false)
    icon.ActiveCooldown:SetReverse(true)
    icon.ActiveCooldown:Clear()

    -- Text overlay frame: parent for ChargeText. Sits at icon level + IconOverlay
    -- so the text renders above the per-icon border (IconBorder = 3) and the
    -- cooldown swipe (IconSwipe = 2). Mirrors CooldownText:GetTextOverlay.
    icon.TextOverlay = CreateFrame("Frame", nil, icon)
    icon.TextOverlay:SetAllPoints()
    icon.TextOverlay:SetFrameLevel(icon:GetFrameLevel() + Constants.Levels.IconOverlay)

    icon.ChargeText = icon.TextOverlay:CreateFontString(nil, "OVERLAY")
    icon.ChargeText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    icon.ChargeText:SetFont(STANDARD_TEXT_FONT, FONT_SIZE_DEFAULT, Orbit.Skin and Orbit.Skin:GetFontOutline() or "OUTLINE")
    icon.ChargeText:Hide()

    icon.DropHighlight = icon:CreateTexture(nil, "OVERLAY")
    icon.DropHighlight:SetAllPoints()
    icon.DropHighlight:SetColorTexture(1, 1, 1, 0.2)
    icon.DropHighlight:Hide()

    icon:EnableMouse(true)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            if removeCallback then removeCallback(self) end
        end
    end)

    return icon
end

-- [ UPDATE ] ------------------------------------------------------------------
-- Refresh icon texture, cooldown state, and visibility. Secret-value safe:
-- spell state detected via IDENTITY_CURVE (returns numeric); items use
-- C_Container.GetItemCooldown which returns numeric start/duration.
--
-- State model (per icon, per tick):
--   ready      — no cooldown running (pct <= 0 or no durObj)
--   active     — cooldown running AND within the active-duration phase
--   on cooldown — cooldown running AND past the active phase (or no active phase)
--
-- Active-phase visuals (per user spec):
--   * Icon stays saturated
--   * No swipe (both Cooldown and ActiveCooldown cleared)
--   * No timer text
--   * Active glow if configured
--
-- Cooldown-phase visuals:
--   * Icon desaturated
--   * Cooldown swipe showing remaining time
--   * Timer text visible
--
-- GCD handling: if ShowGCDSwipe is false and spell is only on GCD, clear swipe.
--
-- Cached fields set by TrackedContainer:Apply each layout pass:
--   icon._activeDuration, icon._cooldownDuration — from grid entry
--   icon._showGCDSwipe    — ShowGCDSwipe setting
--   icon._hideOnCooldown, icon._hideOnAvailable  — visibility checkboxes
--   icon._activeGlowTypeName, icon._activeGlowOptions — pre-built glow config
function IconItem:Update(icon)
    if not icon.trackedId then icon:Hide(); return end

    local texture
    local isReady, isActive = true, false

    if icon.trackedType == "spell" then
        local activeId = FindSpellOverrideByID(icon.trackedId) or icon.trackedId
        texture = C_Spell.GetSpellTexture(activeId)
        if texture then
            icon.Icon:SetTexture(texture)
            local cdInfo = C_Spell.GetSpellCooldown(activeId)
            local onGCD = cdInfo and cdInfo.isOnGCD
            local durObj = C_Spell.GetSpellCooldownDuration(activeId)
            -- State detection via remaining percent
            local pct = durObj and IDENTITY_CURVE and durObj:EvaluateRemainingPercent(IDENTITY_CURVE)
            local hasCooldown = pct and not issecretvalue(pct) and pct > 0
            if hasCooldown then
                isReady = false
                local actDur = icon._activeDuration
                local cdDur = icon._cooldownDuration
                if actDur and actDur > 0 and cdDur and cdDur > 0 then
                    local breakpoint = 1 - (actDur / cdDur)
                    isActive = pct >= breakpoint
                end
            end
            -- Visual updates based on state
            if not hasCooldown then
                -- Ready: saturated, no swipe
                icon.Cooldown:Clear()
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(0)
            elseif onGCD and not icon._showGCDSwipe then
                -- GCD-only with swipe suppressed: saturated, no swipe
                icon.Cooldown:Clear()
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(0)
            elseif isActive then
                -- Active phase: saturated, no swipe
                icon.Cooldown:Clear()
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(0)
            else
                -- Cooldown phase: desaturated, swipe visible
                icon.Cooldown:SetCooldownFromDurationObject(durObj, true)
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(1)
            end
            self:UpdateChargeText(icon, activeId)
        end
    elseif icon.trackedType == "item" then
        texture = C_Item.GetItemIconByID(icon.trackedId)
        if texture then
            icon.Icon:SetTexture(texture)
            local start, duration = C_Container.GetItemCooldown(icon.trackedId)
            if start and duration and duration > 0 then
                isReady = false
                local actDur = icon._activeDuration
                if actDur and actDur > 0 and duration > actDur then
                    isActive = (GetTime() - start) < actDur
                end
                if isActive then
                    -- Active phase: saturated, no swipe
                    icon.Cooldown:Clear()
                    icon.ActiveCooldown:Clear()
                    icon.Icon:SetDesaturation(0)
                else
                    -- Cooldown phase: desaturated, swipe
                    icon.Cooldown:SetCooldown(start, duration)
                    icon.ActiveCooldown:Clear()
                    icon.Icon:SetDesaturation(1)
                end
            else
                icon.Cooldown:Clear()
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(0)
            end
            local count = C_Item.GetItemCount(icon.trackedId, false, true)
            if count and count > 1 then
                icon.ChargeText:SetText(count)
                if not icon._chargeTextDisabled then icon.ChargeText:Show() end
            else
                icon.ChargeText:Hide()
            end
        end
    end

    if not texture then
        icon.Icon:SetTexture(PLACEHOLDER_ICON)
        icon.Icon:SetDesaturation(1)
        icon.Cooldown:Clear()
        icon.ActiveCooldown:Clear()
        icon.ChargeText:Hide()
    end
    icon:Show()

    -- Active glow
    if isActive and icon._activeGlowTypeName and icon._activeGlowOptions then
        GC:Show(icon, ACTIVE_GLOW_KEY, icon._activeGlowTypeName, icon._activeGlowOptions)
    else
        GC:Hide(icon, ACTIVE_GLOW_KEY)
    end

    -- Visibility alpha
    local isOnCooldown = not isReady and not isActive
    if icon._hideOnCooldown and isOnCooldown then
        icon:SetAlpha(0)
    elseif icon._hideOnAvailable and isReady then
        icon:SetAlpha(0)
    else
        icon:SetAlpha(1)
    end
end

-- chargeInfo.currentCharges is secret in combat — pipe it straight into SetText
-- (a sink) without any boolean test or comparison.
function IconItem:UpdateChargeText(icon, spellId)
    if icon._chargeTextDisabled then icon.ChargeText:Hide(); return end
    local chargeInfo = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellId)
    if chargeInfo then
        icon.ChargeText:SetText(chargeInfo.currentCharges)
        icon.ChargeText:Show()
        return
    end
    local displayCount = C_Spell.GetSpellDisplayCount and C_Spell.GetSpellDisplayCount(spellId)
    if displayCount then
        icon.ChargeText:SetText(displayCount)
        icon.ChargeText:Show()
    else
        icon.ChargeText:Hide()
    end
end

-- [ DROP HIGHLIGHT ] ----------------------------------------------------------
function IconItem:SetDropHighlight(icon, shown)
    if shown then icon.DropHighlight:Show() else icon.DropHighlight:Hide() end
end
