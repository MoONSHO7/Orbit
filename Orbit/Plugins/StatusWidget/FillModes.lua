---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ FILL MODES + DURABILITY WARNING ]----------------------------------------------------------------
local CRACKEDMETAL_BASE = "Interface\\AddOns\\Orbit\\Core\\assets\\Radial\\orbit-radial-crackedmetal-"
local CRACKEDMETAL_VARIANTS = 6   -- numbered fracture set; one is picked at random (+ a random spin) per warning
-- Ring crack overlay (durability-gated): light at 20-40%, heavy (more cracks) at <20%.
local RINGCRACK = {
    [1] = "Interface\\AddOns\\Orbit\\Core\\assets\\Radial\\orbit-radial-ringcrack-light",
    [2] = "Interface\\AddOns\\Orbit\\Core\\assets\\Radial\\orbit-radial-ringcrack-heavy",
}
local DURA_WARN, DURA_CRIT, DURA_ALWAYS = 0.40, 0.20, 0.10
local DURA_WARN_TIME, DURA_CRIT_TIME = 5, 10   -- centre warning auto-hides after this; below DURA_ALWAYS it never times out
local DURA_WARN_COLOR = { r = 1.0, g = 0.78, b = 0.20 }   -- yellow (slow pulse)
local DURA_CRIT_COLOR = { r = 1.0, g = 0.25, b = 0.18 }   -- red (faster pulse)

function Plugin:SetupFillModes()
    local frame = self.frame
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

-- Gates the gain flourish without relying on _currencyID (a CurrencyRecord side effect, nil when the picked/backpack currency is uncapped).
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

-- Mirrors the character-pane currency list, so currencies under a collapsed header are absent (Blizzard's GetCurrencyListInfo skips them).
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

-- Spin via Texture:SetRotation (untainted).
function Plugin:_RandomizeCrackedMetal()
    local metal = self.frame.CrackedMetal
    if not metal then return end
    metal:SetTexture(CRACKEDMETAL_BASE .. math.random(CRACKEDMETAL_VARIANTS), nil, nil, "TRILINEAR")
    metal:SetRotation(math.random() * 2 * math.pi)
end

-- The centre warning is timed (5s warn / 10s crit), re-armed on every durability loss in the band; below DURA_ALWAYS (10%) it's persistent. It is NOT suppressed in M+ — it plays over the timer, which yields via _DuraWarnActive.
function Plugin:_TriggerDuraWarning(realPct)
    if self._duraTimer then self._duraTimer:Cancel(); self._duraTimer = nil end
    if realPct < DURA_ALWAYS then return end   -- handled by _duraAlways; no timeout
    local dur = (realPct <= DURA_CRIT) and DURA_CRIT_TIME or DURA_WARN_TIME
    self._duraWarnUntil = GetTime() + dur
    self._duraTimer = C_Timer.NewTimer(dur, function()
        self._duraWarnUntil, self._duraTimer = nil, nil
        if self.frame then self:UpdateBar() end
    end)
end

function Plugin:_DuraWarnActive()
    if self._duraAlways then return true end
    return self._duraWarnUntil ~= nil and GetTime() < self._duraWarnUntil
end

function Plugin:_UpdateCrackedMetal(record)
    local frame = self.frame
    local metal = frame.CrackedMetal
    if not metal then return end
    local realPct = self:_DurabilityPct()
    if realPct then
        local last = self._lastDuraPct
        if last then
            -- Shatter shrapnel only on the downward 40% / 20% crossings.
            if realPct <= DURA_CRIT and last > DURA_CRIT then self:PlayShatterFlourish(true)
            elseif realPct <= DURA_WARN and last > DURA_WARN then self:PlayShatterFlourish(false) end
            if realPct < last and realPct <= DURA_WARN then self:_TriggerDuraWarning(realPct) end   -- any loss in-band re-arms
        elseif realPct <= DURA_WARN then
            self:_TriggerDuraWarning(realPct)   -- first read already low (login / reload)
        end
        self._lastDuraPct = realPct
    end
    -- Ring cracks track the ACTUAL durability, so they persist through flourishes unlike the centre.
    self:_SetRingCrack((not realPct or realPct > DURA_WARN) and 0 or (realPct <= DURA_CRIT and 2 or 1))
    self._duraAlways = realPct ~= nil and realPct < DURA_ALWAYS
    if not realPct or realPct > DURA_WARN then
        self._duraWarnUntil = nil
        if self._duraTimer then self._duraTimer:Cancel(); self._duraTimer = nil end
    end
    -- A shatter flourish owns the centre cracked-metal mid-blast; don't let the timed warning tear it down while it holds the centre.
    if self._event == "shatter" then return end
    if not realPct or self._event ~= nil or not self:_DuraWarnActive() then
        frame.CrackedMetalPulse:Stop(); metal:Hide()
        self._durabilityWarn, self._metalCrit = false, nil
        self:_RefreshInner()
        return
    end
    if not self._durabilityWarn then self:_RandomizeCrackedMetal() end   -- fresh fracture on each new warning
    self:_ShowCrackedWarning(realPct <= DURA_CRIT, realPct)
    self:_RefreshInner()
end

-- A `pct` outside the warn band (e.g. /orbitshatter on full-durability gear) is substituted with a representative band value so the % still reads.
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
        -- White + a hard dark shadow so the % stays legible over the bright cracked metal (the tint carries the severity).
        frame.CenterNumber:SetText(("%d%%"):format(pct * 100 + 0.5))
        frame.CenterNumber:SetTextColor(0.98, 0.98, 0.98)
        frame.CenterNumber:SetShadowColor(0, 0, 0, 0.95)
        frame.CenterNumber:SetShadowOffset(1.5, -1.5)
        frame.CenterNumber:Show()
    end
    self._durabilityWarn = true
end

-- Re-spins only when cracks first appear (0 → shown); a light↔heavy change keeps the spin so the heavy superset's shared cracks stay put.
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
