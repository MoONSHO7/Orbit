-- [ TRACKED ICON ITEM ] -----------------------------------------------------------------------------
-- Stateless factory for icons-mode icon buttons; container owns events and calls Update in bulk.
local _, Orbit = ...

local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local FONT_SIZE_DEFAULT = 12
local ACTIVE_GLOW_KEY = "orbitActive"
local ICON_TEXCOORD_MIN = 0.07
local ICON_TEXCOORD_MAX = 0.93

-- DESAT_CURVE: remaining-percent → 0/1 desaturation flag; 0.001 step stabilizes exact-zero.
local DESAT_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0)
    c:AddPoint(0.001, 1)
    c:AddPoint(1.0, 1)
    return c
end)()

-- ONCD_CURVE: remaining-percent → numeric 0/1 "is on cooldown" flag; secret-safe state derivation.
local ONCD_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0)
    c:AddPoint(0.001, 1)
    c:AddPoint(1.0, 1)
    return c
end)()

local GC = OrbitEngine.GlowController
local Parser = Orbit.TooltipParser

-- [ MODULE ] ----------------------------------------------------------------------------------------
Orbit.TrackedIconItem = {}
local IconItem = Orbit.TrackedIconItem

-- [ FONT APPLIER ] ----------------------------------------------------------------------------------
-- Applies global font/outline to ChargeText and Cooldown timer text.
function IconItem:ApplyFont(plugin, icon)
    local font = plugin:GetGlobalFont() or STANDARD_TEXT_FONT
    local outline = Orbit.Skin and Orbit.Skin:GetFontOutline() or "OUTLINE"
    icon.ChargeText:SetFont(font, FONT_SIZE_DEFAULT, outline)
    self:StyleCooldownText(icon.Cooldown, font, outline)
    self:StyleCooldownText(icon.ActiveCooldown, font, outline)
end

-- [ COOLDOWN TEXT STYLE ] ---------------------------------------------------------------------------
-- Finds and styles the CooldownFrameTemplate's built-in countdown FontString.
function IconItem:StyleCooldownText(cd, font, outline)
    if not cd then return end
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

-- [ SWIPE COLOR APPLIER ] ---------------------------------------------------------------------------
function IconItem:ApplySwipeColor(plugin, icon, systemIndex)
    local colorCurve = plugin:GetSetting(systemIndex, "CooldownSwipeColorCurve")
    if colorCurve and colorCurve.pins and colorCurve.pins[1] then
        local c = colorCurve.pins[1].color
        if c and icon.Cooldown then icon.Cooldown:SetSwipeColor(c.r or 0, c.g or 0, c.b or 0, c.a or 0.8) end
    end
    local activeCurve = plugin:GetSetting(systemIndex, "ActiveSwipeColorCurve")
    if activeCurve and activeCurve.pins and activeCurve.pins[1] then
        local ac = activeCurve.pins[1].color
        if ac and icon.ActiveCooldown then
            local swipeTex = Constants.Assets and Constants.Assets.SwipeCustom
            if swipeTex then icon.ActiveCooldown:SetSwipeTexture(swipeTex) end
            icon.ActiveCooldown:SetSwipeColor(ac.r or 0, ac.g or 0, ac.b or 0, ac.a or 0.7)
            icon.ActiveCooldown:SetReverse(true)
        end
    end
end

-- [ CANVAS COMPONENT APPLY ] ------------------------------------------------------------------------
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

-- [ FACTORY ] ---------------------------------------------------------------------------------------
function IconItem:Build(container, removeCallback)
    local icon = CreateFrame("Frame", nil, container, "BackdropTemplate")
    OrbitEngine.Pixel:Enforce(icon)
    icon:SetSize(Constants.Cooldown.DefaultIconSize, Constants.Cooldown.DefaultIconSize)
    icon.trackedType = nil
    icon.trackedId = nil

    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()
    icon.Icon:SetTexCoord(ICON_TEXCOORD_MIN, ICON_TEXCOORD_MAX, ICON_TEXCOORD_MIN, ICON_TEXCOORD_MAX)

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
        if button == "RightButton" and IsShiftKeyDown() and not InCombatLockdown() then
            if removeCallback then removeCallback(self) end
        end
    end)

    return icon
end

-- [ UPDATE ] ----------------------------------------------------------------------------------------
-- Refresh texture, cooldown state, and visibility. Update helpers return a numeric state
-- derived from curves (secret-safe); ApplyVisibilityAlpha consumes it.
function IconItem:Update(icon)
    if not icon.trackedId then icon:Hide(); icon._visShown = nil; return end

    local texture, state

    if icon.trackedType == "spell" then
        texture, state = self:UpdateSpell(icon)
    elseif icon.trackedType == "item" then
        texture, state = self:UpdateItem(icon)
    end

    if not texture then
        icon.Icon:SetTexture(PLACEHOLDER_ICON)
        icon.Icon:SetDesaturation(1)
        icon.Cooldown:Clear()
        icon.Cooldown:SetAlpha(1)
        icon.ActiveCooldown:Clear()
        icon.ChargeText:Hide()
        if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
        -- Placeholder bypasses visibility settings: force-show so users can see the unresolved icon.
        icon._visShown = true
        icon:Show()
        return
    end
    self:ApplyVisibilityAlpha(icon, state or "ready")
end

-- [ SPELL UPDATE ] ----------------------------------------------------------------------------------
function IconItem:UpdateSpell(icon)
    if not IsSpellKnown(icon.trackedId) and not IsPlayerSpell(icon.trackedId) then
        local activeId = FindSpellOverrideByID(icon.trackedId)
        if activeId == icon.trackedId or (not IsSpellKnown(activeId) and not IsPlayerSpell(activeId)) then
            return nil, nil
        end
    end

    local activeId = FindSpellOverrideByID(icon.trackedId) or icon.trackedId
    local texture = C_Spell.GetSpellTexture(activeId)
    if not texture then return nil, nil end
    icon.Icon:SetTexture(texture)

    local cdInfo = C_Spell.GetSpellCooldown(activeId)
    local onGCD = cdInfo and cdInfo.isOnGCD
    local showGCDSwipe = icon._showGCDSwipe
    local chargeInfo = icon._isChargeSpell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(activeId)

    local state
    if chargeInfo then
        state = self:UpdateChargeSpell(icon, activeId, chargeInfo, onGCD)
    elseif onGCD and not showGCDSwipe then
        icon.Cooldown:Clear()
        icon.Cooldown:SetAlpha(1)
        icon.ActiveCooldown:Clear()
        icon.Icon:SetDesaturation(0)
        if icon.Cooldown.SetHideCountdownNumbers then icon.Cooldown:SetHideCountdownNumbers(false) end
        if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
        state = "ready"
    else
        state = self:UpdateNonChargeSpell(icon, activeId, cdInfo, onGCD)
    end

    self:UpdateSpellChargeText(icon, activeId, chargeInfo)
    return texture, state
end

-- [ NON-CHARGE SPELL ] ------------------------------------------------------------------------------
-- Phase-aware desat/swipe/glow via desatCurve/cdAlphaCurve and ActiveCooldown reverse swipe.
-- Returns visibility state ("active"/"cooldown"/"ready") derived via ONCD_CURVE → numeric.
function IconItem:UpdateNonChargeSpell(icon, activeId, cdInfo, onGCD)
    -- ignoreGCD excludes the GCD contribution from durObj; ignored on older clients.
    local durObj = C_Spell.GetSpellCooldownDuration(activeId, not icon._showGCDSwipe)
    if durObj then
        icon.Cooldown:SetCooldownFromDurationObject(durObj, true)
        local desatPct = onGCD and 0 or durObj:EvaluateRemainingPercent(icon._desatCurve or DESAT_CURVE)
        icon.Icon:SetDesaturation(desatPct)
        if icon._cdAlphaCurve then icon.Cooldown:SetAlpha(durObj:EvaluateRemainingPercent(icon._cdAlphaCurve)) end
        local onRealCD = cdInfo and cdInfo.isActive
        if icon._activeDuration and onRealCD and not onGCD and icon._activeGlowExpiry then
            local castTime = icon._activeGlowExpiry - icon._activeDuration
            icon.ActiveCooldown:SetCooldown(castTime, icon._activeDuration)
            if icon.Cooldown.SetHideCountdownNumbers then icon.Cooldown:SetHideCountdownNumbers(true) end
        else
            icon.ActiveCooldown:Clear()
            if icon.Cooldown.SetHideCountdownNumbers then icon.Cooldown:SetHideCountdownNumbers(false) end
        end
        if icon._activeGlowExpiry then
            if GetTime() < icon._activeGlowExpiry then
                if icon._activeGlowTypeName and icon._activeGlowOptions then
                    GC:Show(icon, ACTIVE_GLOW_KEY, icon._activeGlowTypeName, icon._activeGlowOptions)
                end
                return "active"
            else
                GC:Hide(icon, ACTIVE_GLOW_KEY)
                icon._activeGlowExpiry = nil
            end
        else
            if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
        end
        if onGCD then return "ready" end
        local onCd = durObj:EvaluateRemainingPercent(ONCD_CURVE)
        if issecretvalue(onCd) then return "ready" end
        return onCd > 0.5 and "cooldown" or "ready"
    else
        icon.Cooldown:Clear()
        icon.Cooldown:SetAlpha(1)
        icon.ActiveCooldown:Clear()
        icon.Icon:SetDesaturation(0)
        if icon.Cooldown.SetHideCountdownNumbers then icon.Cooldown:SetHideCountdownNumbers(false) end
        if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
        return "ready"
    end
end

-- [ CHARGE SPELL ] ----------------------------------------------------------------------------------
-- Caches charges out of combat via issecretvalue; desaturates only when all charges consumed.
-- Returns state: "active" during glow window, "cooldown" while recharging, "ready" otherwise.
function IconItem:UpdateChargeSpell(icon, activeId, chargeInfo, onGCD)
    if not issecretvalue(chargeInfo.currentCharges) then
        icon._trackedCharges = chargeInfo.currentCharges
        icon._knownRechargeDuration = chargeInfo.cooldownDuration
        icon._rechargeEndsAt = (chargeInfo.cooldownStartTime > 0 and chargeInfo.cooldownDuration > 0) and (chargeInfo.cooldownStartTime + chargeInfo.cooldownDuration) or nil
    end
    CooldownUtils:TrackChargeCompletion(icon)

    local chargeDurObj = C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(activeId)
    if chargeDurObj then
        icon.Cooldown:SetCooldownFromDurationObject(chargeDurObj, true)
    else
        icon.Cooldown:Clear()
        icon._trackedCharges = icon._maxCharges
        icon._rechargeEndsAt = nil
    end

    local allConsumed = icon._trackedCharges and icon._trackedCharges == 0
    icon.Icon:SetDesaturation(allConsumed and 1 or 0)
    icon.Cooldown:SetAlpha(1)

    if icon._activeDuration and icon._activeGlowExpiry and GetTime() < icon._activeGlowExpiry then
        icon.Cooldown:Clear()
        local castTime = icon._activeGlowExpiry - icon._activeDuration
        icon.ActiveCooldown:SetCooldown(castTime, icon._activeDuration)
        if icon._activeGlowTypeName and icon._activeGlowOptions then
            GC:Show(icon, ACTIVE_GLOW_KEY, icon._activeGlowTypeName, icon._activeGlowOptions)
        end
        return "active"
    end
    icon.ActiveCooldown:Clear()
    if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
    if icon._activeGlowExpiry and GetTime() >= icon._activeGlowExpiry then icon._activeGlowExpiry = nil end
    return chargeDurObj and "cooldown" or "ready"
end

-- [ ITEM UPDATE ] -----------------------------------------------------------------------------------
function IconItem:UpdateItem(icon)
    local usable, noMana = C_Item.IsUsableItem(icon.trackedId)
    local isUsable = usable or noMana or C_Item.GetItemCount(icon.trackedId, false, true) > 0

    local texture = C_Item.GetItemIconByID(icon.trackedId)
    if not texture then return nil, nil end
    icon.Icon:SetTexture(texture)

    if not isUsable then
        icon.Cooldown:Clear()
        icon.Cooldown:SetAlpha(1)
        icon.ActiveCooldown:Clear()
        icon.Icon:SetDesaturation(1)
        icon.ChargeText:SetText("0")
        if not icon._chargeTextDisabled then icon.ChargeText:Show() end
        if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
        return texture, "ready"
    end

    local state
    if icon._useSpellId then
        state = self:UpdateItemWithSpellId(icon)
    else
        state = self:UpdateItemDirect(icon)
    end

    local count = C_Item.GetItemCount(icon.trackedId, false, true)
    if count and count > 1 then
        icon.ChargeText:SetText(count)
        if not icon._chargeTextDisabled then icon.ChargeText:Show() end
    else
        icon.ChargeText:Hide()
    end
    return texture, state
end

-- [ ITEM WITH SPELL ID ] ----------------------------------------------------------------------------
-- Prefers GetItemCooldown (numeric); falls back to GetSpellCooldownDuration for in-combat access.
-- Returns "active"/"cooldown"/"ready" state.
function IconItem:UpdateItemWithSpellId(icon)
    local start, duration = C_Container.GetItemCooldown(icon.trackedId)
    if start and duration and duration > 1.5 then
        icon.Cooldown:SetCooldown(start, duration)
        if icon._activeDuration and duration > icon._activeDuration then
            local inActivePhase = (GetTime() - start) < icon._activeDuration
            if inActivePhase then
                icon.Icon:SetDesaturation(0)
                icon.Cooldown:SetAlpha(0)
                icon.ActiveCooldown:SetCooldown(start, icon._activeDuration)
                if icon._activeGlowTypeName and icon._activeGlowOptions then
                    GC:Show(icon, ACTIVE_GLOW_KEY, icon._activeGlowTypeName, icon._activeGlowOptions)
                end
                return "active"
            else
                icon.Icon:SetDesaturation(1)
                icon.Cooldown:SetAlpha(1)
                icon.ActiveCooldown:Clear()
                if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
                return "cooldown"
            end
        else
            icon.Icon:SetDesaturation(1)
            icon.Cooldown:SetAlpha(1)
            icon.ActiveCooldown:Clear()
            return "cooldown"
        end
    else
        local durObj = C_Spell.GetSpellCooldownDuration(icon._useSpellId)
        if durObj then
            icon.Cooldown:SetCooldownFromDurationObject(durObj, true)
            icon.Icon:SetDesaturation(durObj:EvaluateRemainingPercent(icon._desatCurve or DESAT_CURVE))
            icon.ActiveCooldown:Clear()
            if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
            local onCd = durObj:EvaluateRemainingPercent(ONCD_CURVE)
            if issecretvalue(onCd) then return "ready" end
            return onCd > 0.5 and "cooldown" or "ready"
        end
        icon.Cooldown:Clear()
        icon.Cooldown:SetAlpha(1)
        icon.Icon:SetDesaturation(0)
        icon.ActiveCooldown:Clear()
        if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
        return "ready"
    end
end

-- [ ITEM WITHOUT SPELL ID ] -------------------------------------------------------------------------
-- Pure numeric path via C_Container.GetItemCooldown. Returns "active"/"cooldown"/"ready" state.
function IconItem:UpdateItemDirect(icon)
    local start, duration = C_Container.GetItemCooldown(icon.trackedId)
    if start and duration and duration > 0 then
        icon.Cooldown:SetCooldown(start, duration)
        if icon._activeDuration and duration > icon._activeDuration then
            local inActivePhase = (GetTime() - start) < icon._activeDuration
            if inActivePhase then
                icon.Icon:SetDesaturation(0)
                icon.Cooldown:SetAlpha(0)
                icon.ActiveCooldown:SetCooldown(start, icon._activeDuration)
                if icon._activeGlowTypeName and icon._activeGlowOptions then
                    GC:Show(icon, ACTIVE_GLOW_KEY, icon._activeGlowTypeName, icon._activeGlowOptions)
                end
                return "active"
            else
                icon.Icon:SetDesaturation(1)
                icon.Cooldown:SetAlpha(1)
                icon.ActiveCooldown:Clear()
                if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
                return "cooldown"
            end
        else
            icon.Icon:SetDesaturation(1)
            icon.Cooldown:SetAlpha(1)
            icon.ActiveCooldown:Clear()
            return "cooldown"
        end
    end
    icon.Cooldown:Clear()
    icon.Cooldown:SetAlpha(1)
    icon.ActiveCooldown:Clear()
    icon.Icon:SetDesaturation(0)
    if GC:IsActive(icon, ACTIVE_GLOW_KEY) then GC:Hide(icon, ACTIVE_GLOW_KEY) end
    return "ready"
end

-- [ CHARGE TEXT ] -----------------------------------------------------------------------------------
-- chargeInfo.currentCharges is secret in combat — pipe it straight into SetText.
function IconItem:UpdateSpellChargeText(icon, spellId, chargeInfo)
    if icon._chargeTextDisabled then icon.ChargeText:Hide(); return end
    local displayCount = chargeInfo and chargeInfo.currentCharges or (C_Spell.GetSpellDisplayCount and C_Spell.GetSpellDisplayCount(spellId))
    if displayCount then
        icon.ChargeText:SetText(displayCount)
        icon.ChargeText:Show()
    else
        icon.ChargeText:Hide()
    end
end

-- [ VISIBILITY ] ------------------------------------------------------------------------------------
-- SetShown not SetAlpha — matches TrackedBar. Debounced via _visShown so the OnUpdate poll is a
-- no-op when state hasn't changed; state is derived secret-safely by the update helpers.
function IconItem:ApplyVisibilityAlpha(icon, state)
    local hide = (icon._hideOnCooldown and state == "cooldown")
              or (icon._hideOnAvailable and state == "ready")
    if hide and (Orbit:IsEditMode() or GetCursorInfo()) then hide = false end
    local target = not hide
    if icon._visShown == target then return end
    icon._visShown = target
    icon:SetShown(target)
end

-- [ DROP HIGHLIGHT ] --------------------------------------------------------------------------------
function IconItem:SetDropHighlight(icon, shown)
    if shown then icon.DropHighlight:Show() else icon.DropHighlight:Hide() end
end
