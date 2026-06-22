---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Bar v2")

-- [ FILL MODES + DURABILITY WARNING ]----------------------------------------------------------------
-- Currency is a selectable source (right-click menu / PrimarySource). Durability is NOT a source — it's an always-on
-- centre warning: whenever equipped gear drops low the orb's forged ring cracks inward (cracked metal)
-- tinted yellow then red, with the % in the centre, regardless of what the ring is showing.
local CRACKEDMETAL_BASE = "Interface\\AddOns\\Orbit\\Core\\assets\\Radial\\orbit-radial-crackedmetal-"
local CRACKEDMETAL_VARIANTS = 6   -- numbered fracture set; one is picked at random (+ a random spin) per warning
-- Ring crack overlay (durability-gated): light at 20-40%, heavy (more cracks) at <20%.
local RINGCRACK = {
    [1] = "Interface\\AddOns\\Orbit\\Core\\assets\\Radial\\orbit-radial-ringcrack-light",
    [2] = "Interface\\AddOns\\Orbit\\Core\\assets\\Radial\\orbit-radial-ringcrack-heavy",
}
local DURA_WARN, DURA_CRIT = 0.40, 0.20
local DURA_WARN_COLOR = { r = 1.0, g = 0.78, b = 0.20 }   -- yellow (slow pulse)
local DURA_CRIT_COLOR = { r = 1.0, g = 0.25, b = 0.18 }   -- red (faster pulse)

function Plugin:SetupFillModes()
    local frame = self.frame
    -- Cracked-metal disc fills the whole hollow centre. It lives on frame.Content at BACKGROUND sublevel -2 —
    -- BENEATH the ring/border/background (track is BACKGROUND 0) — so the annular ring art frames it and covers
    -- its outer edge, while it shows through the (transparent-centred) ring in the hollow. On Content so it
    -- rides the reveal animation. Cleared by _ClearCenterFX while a flourish owns the centre.
    local metal = frame.Content:CreateTexture(nil, "BACKGROUND", nil, -2)
    metal:SetAllPoints(frame.Content)
    metal:Hide()
    frame.CrackedMetal = metal
    self:_RandomizeCrackedMetal()   -- initial variant + spin (so it varies per /reload)
    local pulse = metal:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local pa = pulse:CreateAnimation("Alpha")
    pa:SetFromAlpha(0.62); pa:SetToAlpha(1.0); pa:SetDuration(0.95)   -- throb stays solid (opaque metal must not fade see-through)
    frame.CrackedMetalPulse = pulse
    frame.CrackedMetalPulseA = pa

    local f = CreateFrame("Frame")
    f:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    f:SetScript("OnEvent", function(_, event, ...) self:OnFillEvent(event, ...) end)
    self._fillFrame = f
end

function Plugin:OnFillEvent(event, ...)
    if event == "UPDATE_INVENTORY_DURABILITY" then
        self:UpdateBar()   -- refresh the always-on durability warning
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        if self:GetSetting(self.system, "PrimarySource") ~= "currency" then return end
        local currencyID, _, change = ...
        if change and change > 0 and currencyID and currencyID == self:_TrackedCurrencyID() and C_CurrencyInfo then
            local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
            if info then self:PlayIconFlourish(info.iconFileID, self.FlourishColors.gold, ("+%d  %s"):format(change, info.name or "")) end
        end
        self:UpdateBar()
    end
end

-- Total equipped-gear durability as a 0..1 fraction, or nil if nothing durable is worn.
function Plugin:_DurabilityPct()
    local cur, max = 0, 0
    for slot = 1, 18 do
        local du, mx = GetInventoryItemDurability(slot)
        if du and mx and mx > 0 then cur = cur + du; max = max + mx end
    end
    if max <= 0 then return nil end
    return cur / max
end

-- The currency to show: the one picked in the source menu (ResolveMode stashes _activeCurrencyID per slot),
-- else the first backpack-tracked currency. Only currencies with a KNOWN CAP drive a fill — one without a
-- max falls back to the auto (xp/rep) source rather than fabricating a ceiling.
function Plugin:CurrencyRecord()
    local C = C_CurrencyInfo
    if not C or not C.GetCurrencyInfo then return self:_AutoRecord() end
    local id = self._activeCurrencyID
    local info = (id and id > 0) and C.GetCurrencyInfo(id) or nil
    if not info and C.GetBackpackCurrencyInfo then
        local bp = C.GetBackpackCurrencyInfo(1)
        id = bp and bp.currencyTypesID
        info = id and C.GetCurrencyInfo(id) or nil
    end
    local max = info and self:_CurrencyMax(info) or 0
    if not info or max <= 0 then return self:_AutoRecord() end
    self._currencyID = id
    local cur = info.quantity or 0
    return { mode = "currency", name = info.name or "", level = tostring(cur), current = cur, max = max,
             color = self.FlourishColors.gold }
end

-- The currency the orb tracks as its PRIMARY at-rest source — the picked PrimaryCurrencyID, else the first
-- backpack-tracked currency. Gates the gain flourish without relying on _currencyID (a CurrencyRecord side
-- effect that's nil when the picked/backpack currency is uncapped).
function Plugin:_TrackedCurrencyID()
    local id = self:GetSetting(self.system, "PrimaryCurrencyID")
    if id and id > 0 then return id end
    local C = C_CurrencyInfo
    local bp = C and C.GetBackpackCurrencyInfo and C.GetBackpackCurrencyInfo(1)
    return bp and bp.currencyTypesID
end

-- A currency's known cap (total cap, else weekly cap), or 0 when it has no max — those can't drive a fill.
function Plugin:_CurrencyMax(info)
    if info.maxQuantity and info.maxQuantity > 0 then return info.maxQuantity end
    if info.maxWeeklyQuantity and info.maxWeeklyQuantity > 0 then return info.maxWeeklyQuantity end
    return 0
end

-- Discovered currencies with a known cap, for the source menu's currency picker. Mirrors the character-pane
-- currency list (`GetCurrencyListInfo` carries `currencyID`); headers / unused entries are skipped. Currencies
-- under a collapsed header are absent from the list, exactly as in Blizzard's own currency tab.
function Plugin:_EligibleCurrencies()
    local C = C_CurrencyInfo
    local out = {}
    if not (C and C.GetCurrencyListSize and C.GetCurrencyListInfo) then return out end
    for i = 1, C.GetCurrencyListSize() do
        local info = C.GetCurrencyListInfo(i)
        if info and not info.isHeader and not info.isTypeUnused and info.currencyID and info.currencyID > 0
           and self:_CurrencyMax(info) > 0 then
            out[#out + 1] = { id = info.currencyID, name = info.name or "" }
        end
    end
    return out
end

-- Pick a random fracture variant and a random rotation, so the cracked metal looks different each time it
-- appears (per /reload and per fresh low-durability warning). Spin via Texture:SetRotation (untainted).
function Plugin:_RandomizeCrackedMetal()
    local metal = self.frame.CrackedMetal
    if not metal then return end
    metal:SetTexture(CRACKEDMETAL_BASE .. math.random(CRACKEDMETAL_VARIANTS), nil, nil, "TRILINEAR")
    metal:SetRotation(math.random() * 2 * math.pi)
end

-- Always-on durability warning, driven from UpdateBar (and UPDATE_INVENTORY_DURABILITY). Idle only;
-- yields to any flourish. Sets self._durabilityWarn so the numeral defers to the % display.
function Plugin:_UpdateCrackedMetal(record)
    local frame = self.frame
    local metal = frame.CrackedMetal
    if not metal then return end
    local realPct = self:_DurabilityPct()
    -- One-shot shatter break on each downward crossing of 40% / 20% (queued; never fires on login — the
    -- first read only seeds _lastDuraPct). The queue serializes it behind any active flourish.
    if realPct then
        local last = self._lastDuraPct
        if last then
            if realPct <= DURA_CRIT and last > DURA_CRIT then self:PlayShatterFlourish(true)
            elseif realPct <= DURA_WARN and last > DURA_WARN then self:PlayShatterFlourish(false) end
        end
        self._lastDuraPct = realPct
    end
    -- Ring cracks track the ACTUAL durability (persist through flourishes, unlike the centre): off above
    -- 40%, light at 20-40%, heavy below 20%.
    self:_SetRingCrack((not realPct or realPct > DURA_WARN) and 0 or (realPct <= DURA_CRIT and 2 or 1))
    -- A shatter flourish OWNS the centre cracked-metal + _durabilityWarn (it reveals them mid-blast); don't
    -- let the idle warning tear them down while the shatter holds the centre. Other flourishes still hide it.
    if self._event == "shatter" then return end
    local pct = (self._event == nil) and realPct or nil
    if not pct or pct > DURA_WARN then
        frame.CrackedMetalPulse:Stop(); metal:Hide()
        self._durabilityWarn, self._metalCrit = false, nil
        self:_RefreshInner()
        return
    end
    if not self._durabilityWarn then self:_RandomizeCrackedMetal() end   -- fresh fracture on each new warning
    self:_ShowCrackedWarning(pct <= DURA_CRIT, pct)
    self:_RefreshInner()
end

-- Show the persistent cracked-metal warning visuals: tinted disc + pulse + %. `crit` picks red/amber +
-- the pulse speed; `pct` drives the number. Shared by _UpdateCrackedMetal (idle warning) and the shatter
-- mid-blast reveal. If `pct` isn't in the warn band (e.g. the /orbitshatter test on full-durability gear),
-- a representative band value is shown so the % still reads sensibly.
function Plugin:_ShowCrackedWarning(crit, pct)
    if not pct or pct > DURA_WARN then pct = crit and (DURA_CRIT - 0.02) or (DURA_WARN - 0.05) end
    local frame = self.frame
    local col = crit and DURA_CRIT_COLOR or DURA_WARN_COLOR
    frame.CrackedMetal:SetVertexColor(col.r, col.g, col.b); frame.CrackedMetal:Show()
    if self._metalCrit ~= crit or not frame.CrackedMetalPulse:IsPlaying() then
        self._metalCrit = crit
        frame.CrackedMetalPulseA:SetDuration(crit and 0.45 or 0.95)   -- red faster, yellow slower
        frame.CrackedMetalPulse:Stop(); frame.CrackedMetalPulse:Play()
    end
    if frame.CenterNumber then
        -- White + a hard dark shadow so the % reads over the bright cracked metal filling the centre
        -- (the metal's yellow/red tint carries the severity; the numeral just needs to stay legible).
        frame.CenterNumber:SetText(("%d%%"):format(pct * 100 + 0.5))
        frame.CenterNumber:SetTextColor(0.98, 0.98, 0.98)
        frame.CenterNumber:SetShadowColor(0, 0, 0, 0.95)
        frame.CenterNumber:SetShadowOffset(1.5, -1.5)
        frame.CenterNumber:Show()
    end
    self._durabilityWarn = true
end

-- Crack overlay on the ring, only when durability is low: 0 = off, 1 = light (20-40%), 2 = heavy (<20%).
-- Idempotent (only re-textures on a level change) since UpdateBar calls run often. A fresh RANDOM rotation
-- is applied each time the cracks first appear (0 → shown), so they never look the same per load / episode;
-- light↔heavy keeps the same spin so the heavy superset's shared cracks stay put (no jump).
function Plugin:_SetRingCrack(level)
    local rc = self.frame.RingCrack
    local was = self._ringCrackLevel
    if not rc or level == was then return end
    self._ringCrackLevel = level
    if level == 0 then rc:Hide(); return end
    if not was or was == 0 then rc:SetRotation(math.random() * 2 * math.pi) end
    rc:SetTexture(RINGCRACK[level], nil, nil, "TRILINEAR")
    rc:Show()
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
-- "/orbitshatter" previews both durability breaks (40% amber, then the 20% red queued behind it);
-- "/orbitshatter 40" or "20" fires just one. Works on any gear — the cracked circle shows a representative %.
SLASH_ORBITSHATTER1 = "/orbitshatter"
SlashCmdList["ORBITSHATTER"] = function(arg)
    arg = arg and arg:lower():match("%S+")
    if arg == "20" then Plugin:PlayShatterFlourish(true)
    elseif arg == "40" then Plugin:PlayShatterFlourish(false)
    else
        Plugin:PlayShatterFlourish(false)   -- 40% damaged (amber)
        Plugin:PlayShatterFlourish(true)    -- 20% broken (red), queued after
    end
end
