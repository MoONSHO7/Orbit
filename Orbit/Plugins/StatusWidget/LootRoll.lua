---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ LOOT ROLL ]--------------------------------------------------------------------------------------
local PANEL_W, PANEL_H = 200, 46   -- width matches the M+ info panel so the shared side stack aligns
local ICON_SIZE = 34
local BTN_SIZE = 22
local BTN_GAP = 3
local TIMER_H = 7
local PAD = 6
local PANEL_GAP = 6      -- between stacked panels
local ANCHOR_GAP = 10    -- between the orb and the first panel
local NAME_SIZE = 13
local NUMBER_SIZE = 26   -- rolled-number size in the dice reveal
local MASK_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local TIMER_COLOR = { r = 1.0, g = 0.82, b = 0.35 }
local FALLBACK_COLOR = { r = 0.62, g = 0.62, b = 0.62 }
local BONUS_BORDER_COLOR = { r = 1.0, g = 0.80, b = 0.20, a = 1 }   -- bonus rolls always border gold
local FAKE_DURATION = 30   -- /orbitroll preview countdown

-- RollOnLoot type ids match Blizzard's button ids (GroupLootFrame.xml): pass 0, need 1, greed 2, transmog 4.
local ROLL_PASS, ROLL_NEED, ROLL_GREED, ROLL_TRANSMOG = 0, 1, 2, 4
local ATLAS = {
    need     = { "lootroll-toast-icon-need-up",     "lootroll-toast-icon-need-highlight",     "lootroll-toast-icon-need-down" },
    greed    = { "lootroll-toast-icon-greed-up",    "lootroll-toast-icon-greed-highlight",    "lootroll-toast-icon-greed-down" },
    transmog = { "lootroll-toast-icon-transmog-up", "lootroll-toast-icon-transmog-highlight", "lootroll-toast-icon-transmog-down" },
    pass     = { "lootroll-toast-icon-pass-up",     "lootroll-toast-icon-pass-highlight",     "lootroll-toast-icon-pass-down" },
}

-- The group is created on its texture, so each animation auto-targets it (vault-FX pattern), no SetTarget needed.
local function Flip(group, rows, cols, frames, dur, delay)
    local f = group:CreateAnimation("FlipBook")
    f:SetDuration(dur)
    if delay then f:SetStartDelay(delay) end
    f:SetFlipBookRows(rows); f:SetFlipBookColumns(cols); f:SetFlipBookFrames(frames)
    f:SetFlipBookFrameWidth(0); f:SetFlipBookFrameHeight(0)
    return f
end
local function Fade(group, from, to, dur, delay)
    local a = group:CreateAnimation("Alpha")
    a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(dur)
    if delay then a:SetStartDelay(delay) end
    return a
end

local function SetButtonEnabled(button, enabled, reason)
    button.reason = enabled and nil or reason
    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or 0.4)
    local normal = button:GetNormalTexture()
    if normal then normal:SetDesaturated(not enabled) end
end

local function MakeButton(panel, atlasKey, rollType, tooltipText)
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(BTN_SIZE, BTN_SIZE)
    b:SetNormalAtlas(ATLAS[atlasKey][1])
    b:SetHighlightAtlas(ATLAS[atlasKey][2])
    b:SetPushedAtlas(ATLAS[atlasKey][3])
    local hl = b:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end
    b.rollType = rollType
    b.tooltipText = tooltipText
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText)
        if not self:IsEnabled() and self.reason then
            GameTooltip:AddLine(self.reason, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self)
        local p = self:GetParent()
        if p._isBonus then   -- bonus-roll mode: the only visible MakeButton button is Pass = decline
            if p._bonusSpellID then DeclineSpellConfirmationPrompt(p._bonusSpellID) end
            Plugin:_ReleasePanel(p)
            return
        end
        if p._rollID then
            RollOnLoot(p._rollID, self.rollType)   -- fires CONFIRM_LOOT_ROLL itself for BoP need; Blizzard's popup handles it
            Plugin:_MarkRolled(p)
        elseif self.rollType == ROLL_NEED then
            local r = math.random(1, 100)          -- preview: simulate the need-roll reveal
            Plugin:_PlayRollAnim(p, r, r > 50)
        else
            Plugin:_ReleasePanel(p)   -- preview: other buttons just dismiss
        end
    end)
    return b
end

-- The roll timer drains every frame from GetLootRollTimeLeft (ms), or a faked countdown for the preview.
local function PanelOnUpdate(self)
    local left
    if self._rollID then
        left = GetLootRollTimeLeft(self._rollID)
    elseif self._bonusEnd then
        left = math.max(0, (self._bonusEnd - GetTime()) * 1000)   -- visual only; SPELL_CONFIRMATION_TIMEOUT closes it
    elseif self._fakeEnd then
        left = math.max(0, (self._fakeEnd - GetTime()) * 1000)
        if left <= 0 then Plugin:_ReleasePanel(self); return end
    else
        return
    end
    local min, max = self.Timer:GetMinMaxValues()
    if left < min or left > max then left = min end
    self.Timer:SetValue(left)
end

local function CreateRollPanel()
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()
    OrbitEngine.Pixel:Enforce(panel)

    -- Registered as a masked surface so the bg rounds under a rounded border; theme colour/border/fonts come from _StylePanel.
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(panel)
    panel.bg = bg
    Orbit.Skin:RegisterMaskedSurface(panel, bg)

    -- Item disc (circular-masked, matching the loot reel), with stack count + tooltip.
    local iconBtn = CreateFrame("Button", nil, panel)
    iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
    iconBtn:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    local icon = iconBtn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(iconBtn)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local mask = iconBtn:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetTexture(MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)
    panel.Icon = icon
    local count = iconBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", iconBtn, "BOTTOMRIGHT", -1, 1)
    count:Hide()
    panel.Count = count
    iconBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if panel._rollID then GameTooltip:SetLootRollItem(panel._rollID)
        elseif panel._bonusItemID then GameTooltip:SetItemByID(panel._bonusItemID)
        elseif panel._isBonus then GameTooltip:SetText(BONUS_LOOT_LABEL)
        elseif panel._fakeItemID then GameTooltip:SetItemByID(panel._fakeItemID) end
        GameTooltip:Show()
    end)
    iconBtn:SetScript("OnLeave", GameTooltip_Hide)
    iconBtn:SetScript("OnClick", function()
        if panel._rollID then HandleModifiedItemClick(GetLootRollItemLink(panel._rollID)) end
    end)
    panel.IconButton = iconBtn

    -- Buttons, right to left: Pass, [Greed | Transmog], Need.
    panel.PassButton = MakeButton(panel, "pass", ROLL_PASS, PASS)
    panel.PassButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -PAD)
    panel.GreedButton = MakeButton(panel, "greed", ROLL_GREED, GREED)
    panel.GreedButton:SetPoint("RIGHT", panel.PassButton, "LEFT", -BTN_GAP, 0)
    panel.TransmogButton = MakeButton(panel, "transmog", ROLL_TRANSMOG, TRANSMOGRIFICATION)
    panel.TransmogButton:SetPoint("RIGHT", panel.PassButton, "LEFT", -BTN_GAP, 0)
    panel.NeedButton = MakeButton(panel, "need", ROLL_NEED, NEED)
    panel.NeedButton:SetPoint("RIGHT", panel.GreedButton, "LEFT", -BTN_GAP, 0)
    panel._buttons = { panel.NeedButton, panel.GreedButton, panel.TransmogButton, panel.PassButton }

    -- Bonus-roll dice button: accepts via the same insecure `AcceptSpellConfirmationPrompt` Blizzard's own roll button calls.
    local roll = CreateFrame("Button", nil, panel)
    roll:SetSize(BTN_SIZE, BTN_SIZE)
    roll:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
    roll:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight")
    local rhl = roll:GetHighlightTexture(); if rhl then rhl:SetBlendMode("ADD") end
    roll:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down")
    roll:SetPoint("RIGHT", panel.PassButton, "LEFT", -BTN_GAP, 0)   -- the Need/Greed slot
    roll:Hide()
    roll:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ROLL)
        if self:GetParent()._bonusCostText then GameTooltip:AddLine(self:GetParent()._bonusCostText, 1, 1, 1) end
        GameTooltip:Show()
    end)
    roll:SetScript("OnLeave", GameTooltip_Hide)
    roll:SetScript("OnClick", function(self)
        local p = self:GetParent()
        if p._bonusSpellID then AcceptSpellConfirmationPrompt(p._bonusSpellID) end
        Plugin:_ReleasePanel(p)
    end)
    panel.RollButton = roll

    -- Item name (quality-coloured), between the disc and the buttons.
    local name = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    name:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 6, -1)
    name:SetPoint("RIGHT", panel.NeedButton, "LEFT", -6, 0)
    name:SetJustifyH("LEFT")
    name:SetJustifyV("MIDDLE")
    name:SetWordWrap(false)
    name:SetHeight(BTN_SIZE)
    panel.Name = name

    -- Timer bar along the bottom, under the name.
    local timer = CreateFrame("StatusBar", nil, panel)
    timer:SetPoint("BOTTOMLEFT", iconBtn, "BOTTOMRIGHT", 6, 0)
    timer:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    timer:SetHeight(TIMER_H)
    timer:SetMinMaxValues(0, 1)
    timer:SetValue(0)
    Orbit.Skin:SkinStatusBar(timer, Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.StatusbarTexture, TIMER_COLOR)
    local tbg = timer:CreateTexture(nil, "BACKGROUND")
    tbg:SetAllPoints(timer)
    tbg:SetColorTexture(0, 0, 0, 0.5)
    panel.Timer = timer

    -- Need-roll reveal (MAIN_SPEC_NEED_ROLL): dice + glow + number, one animation group per texture.
    local anim = CreateFrame("Frame", nil, panel)
    anim:SetSize(70, 80)
    anim:SetScale(0.9)
    anim:SetPoint("CENTER", panel, "CENTER", 32, 0)
    anim:SetFrameLevel(panel:GetFrameLevel() + 12)
    anim:Hide()
    panel.RollAnim = anim

    local glow = anim:CreateTexture(nil, "ARTWORK", nil, -1)
    glow:SetAtlas("lootroll-animdiceglow"); glow:SetSize(70, 76); glow:SetPoint("CENTER"); glow:SetAlpha(0)
    local dice = anim:CreateTexture(nil, "ARTWORK")
    dice:SetAtlas("lootroll-animdice"); dice:SetSize(58, 74); dice:SetPoint("CENTER")
    local number = anim:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    number:SetPoint("CENTER", anim, "CENTER", 0, -2)
    number:SetAlpha(0)
    panel.RollNumber = number

    local diceG = dice:CreateAnimationGroup()
    Flip(diceG, 9, 5, 44, 1.47)
    Fade(diceG, 1, 0, 0.2, 1.47)
    local glowG = glow:CreateAnimationGroup()
    Flip(glowG, 10, 5, 50, 1.5, 1.47)
    Fade(glowG, 0, 1, 0.2, 1.47)
    Fade(glowG, 1, 0, 0.4, 2.6)
    local gscale = glowG:CreateAnimation("Scale")
    gscale:SetScaleFrom(1, 1); gscale:SetScaleTo(1.3, 1.3); gscale:SetOrigin("CENTER", 0, 0)
    gscale:SetDuration(1.5); gscale:SetStartDelay(1.47)
    local numG = number:CreateAnimationGroup()
    Fade(numG, 0, 1, 0.2, 1.5)
    Fade(numG, 1, 0, 0.3, 2.9)
    local ntr = numG:CreateAnimation("Translation")
    ntr:SetOffset(0, 6); ntr:SetDuration(0.4); ntr:SetStartDelay(1.5)
    numG:SetScript("OnFinished", function()
        panel._animating = false
        anim:Hide()
        Plugin:_ReleasePanel(panel)
    end)
    panel._animGroups = { diceG, glowG, numG }

    Plugin:_StylePanel(panel)
    panel:SetScript("OnUpdate", PanelOnUpdate)
    return panel
end

-- Re-read theme bg/border/fonts on every fill so a live theme change shows on the next roll; per-roll name/number colour is kept.
function Plugin:_StylePanel(panel)
    local gs = Orbit.db.GlobalSettings
    local c = Orbit.Skin:GetBackgroundColor()
    panel.bg:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    if panel._isBonus then
        -- Same selected border style as a normal roll, tinted gold (SkinBorder now forwards the colour into the styled paths too).
        Orbit.Skin:SkinBorder(panel, panel, (gs and gs.BorderSize) or 1, BONUS_BORDER_COLOR)
    else
        Orbit.Skin:SkinBorder(panel, panel, (gs and gs.BorderSize) or 1)
    end
    Orbit.Skin:SkinText(panel.Name, { font = gs and gs.Font, textSize = NAME_SIZE })
    Orbit.Skin:SkinText(panel.RollNumber, { font = gs and gs.Font, textSize = NUMBER_SIZE })
end

-- [ POOL + STATE ]-----------------------------------------------------------------------------------
function Plugin:_AcquirePanel()
    self._rollPool = self._rollPool or {}
    for _, p in ipairs(self._rollPool) do
        if not p:IsShown() then return p end
    end
    local p = CreateRollPanel()
    self._rollPool[#self._rollPool + 1] = p
    return p
end

function Plugin:_ReleasePanel(panel)
    panel._rollID = nil
    panel._fakeEnd = nil
    panel._fakeItemID = nil
    panel._isBonus = nil
    panel._bonusSpellID = nil
    panel._bonusEnd = nil
    panel._bonusItemID = nil
    panel._bonusCostText = nil
    if self._bonusPanel == panel then self._bonusPanel = nil end
    panel._animating = false
    if panel._animGroups then for _, g in ipairs(panel._animGroups) do g:Stop() end end
    if panel.RollAnim then panel.RollAnim:Hide() end
    panel:Hide()
    if self._activePanels then
        for i, p in ipairs(self._activePanels) do
            if p == panel then table.remove(self._activePanels, i); break end
        end
    end
    self:_LayoutRolls()
end

-- Lays out ALL side widgets as one screen-edge-aware vertical stack BESIDE the orb so they never overlap: the M+ info panel (when shown) on top, then each loot/bonus roll panel. Shared by the M+ panel refresh and every roll add/remove. Side + grow direction follow the orb's screen quadrant.
function Plugin:_LayoutRolls()
    if not self.frame then return end
    local widgets = {}
    local mp = self.frame.MPlusPanel
    if mp and mp:IsShown() then widgets[#widgets + 1] = mp end
    if self._activePanels then
        for _, p in ipairs(self._activePanels) do
            if p:IsShown() then widgets[#widgets + 1] = p end
        end
    end
    if #widgets == 0 then return end
    local orb = self.frame
    local cx, cy = orb:GetCenter()
    local scale = orb:GetEffectiveScale()
    local sw = UIParent:GetWidth() * UIParent:GetEffectiveScale()
    local sh = UIParent:GetHeight() * UIParent:GetEffectiveScale()
    local growRight = not cx or (cx * scale) <= sw / 2
    local growDown = not cy or (cy * scale) >= sh / 2

    local vP = growDown and "TOP" or "BOTTOM"
    local vR = growDown and "BOTTOM" or "TOP"
    local hP = growRight and "LEFT" or "RIGHT"
    local hR = growRight and "RIGHT" or "LEFT"

    widgets[1]:ClearAllPoints()
    widgets[1]:SetPoint(vP .. hP, orb, vP .. hR, growRight and ANCHOR_GAP or -ANCHOR_GAP, 0)   -- first widget sits beside the orb, top/bottom-aligned
    for i = 2, #widgets do
        widgets[i]:ClearAllPoints()
        widgets[i]:SetPoint(vP .. hP, widgets[i - 1], vR .. hP, 0, growDown and -PANEL_GAP or PANEL_GAP)
    end
end

function Plugin:_MarkRolled(panel)
    for _, b in ipairs(panel._buttons) do
        b:SetEnabled(false)
        b:SetAlpha(0.4)
        local n = b:GetNormalTexture()
        if n then n:SetDesaturated(true) end
    end
end

-- Populate a panel from item display data (shared by the live roll path and the preview).
function Plugin:_FillPanel(panel, texture, name, count, quality, canNeed, canGreed, canTransmog, reasonNeed, reasonGreed)
    panel.Icon:SetTexture(texture)
    panel.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- restore the disc trim (a prior bonus may have SetAtlas'd it)
    if panel.RollButton then panel.RollButton:Hide() end
    panel.Name:SetText(name or "")
    local qc = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]) or FALLBACK_COLOR
    panel.Name:SetTextColor(qc.r, qc.g, qc.b)
    if count and count > 1 then
        panel.Count:SetText(count)
        panel.Count:Show()
    else
        panel.Count:Hide()
    end

    -- Reset any leftover dice reveal from a pooled panel and restore the chrome + hidden buttons.
    panel._animating = false
    if panel.RollAnim then panel.RollAnim:Hide() end
    panel.bg:Show()
    if panel.SetBorderHidden then panel:SetBorderHidden(false) end
    panel.Timer:Show()
    panel.NeedButton:Show()
    panel.PassButton:Show()
    self:_StylePanel(panel)   -- re-read bg/border/fonts from the global theme each show

    -- SetButtonEnabled also clears any desaturation/alpha left by a prior _MarkRolled on a pooled panel.
    SetButtonEnabled(panel.NeedButton, canNeed, reasonNeed and _G["LOOT_ROLL_INELIGIBLE_REASON" .. reasonNeed])
    if canTransmog then
        panel.GreedButton:Hide()
        SetButtonEnabled(panel.TransmogButton, true)
        panel.TransmogButton:Show()
    else
        panel.TransmogButton:Hide()
        panel.GreedButton:Show()
        SetButtonEnabled(panel.GreedButton, canGreed, reasonGreed and _G["LOOT_ROLL_INELIGIBLE_REASON" .. reasonGreed])
    end
    SetButtonEnabled(panel.PassButton, true)
end

-- [ EVENTS ]-----------------------------------------------------------------------------------------
local function IsEnabled()
    return not Plugin._disabled and Plugin:GetSetting(Plugin.system, "ReplaceLootRoll")
end

function Plugin:OnRollStart(rollID, rollTime)
    if not IsEnabled() or not self.frame then return end
    local texture, name, count, quality, _, canNeed, canGreed, _, reasonNeed, reasonGreed, _, _, canTransmog = GetLootRollItemInfo(rollID)
    if not name then return end

    local panel = self._activeByRoll and self._activeByRoll[rollID] or self:_AcquirePanel()
    panel._rollID = rollID
    panel._fakeEnd = nil
    panel._fakeItemID = nil
    panel.Timer:SetMinMaxValues(0, rollTime)
    panel.Timer:SetValue(rollTime)
    self:_FillPanel(panel, texture, name, count, quality, canNeed, canGreed, canTransmog, reasonNeed, reasonGreed)

    self._activePanels = self._activePanels or {}
    self._activeByRoll = self._activeByRoll or {}
    if not self._activeByRoll[rollID] then
        self._activePanels[#self._activePanels + 1] = panel
        self._activeByRoll[rollID] = panel
    end
    panel:Show()
    self:_LayoutRolls()
end

function Plugin:OnRollEnd(rollID)
    local panel = self._activeByRoll and self._activeByRoll[rollID]
    if not panel then return end
    self._activeByRoll[rollID] = nil
    if panel._animating then return end   -- the dice reveal's OnFinished will release it
    self:_ReleasePanel(panel)
end

function Plugin:OnNeedRoll(rollID, roll, isWinning)
    local panel = self._activeByRoll and self._activeByRoll[rollID]
    if panel then self:_PlayRollAnim(panel, roll, isWinning) end
end

function Plugin:_PlayRollAnim(panel, roll, isWinning)
    if not panel.RollAnim then return end
    panel._animating = true
    -- Drop the panel chrome so the dice + number read against the world, not the dark panel.
    panel.bg:Hide()
    if panel.SetBorderHidden then panel:SetBorderHidden(true) end
    panel.Timer:Hide()
    for _, b in ipairs(panel._buttons) do b:Hide() end
    panel.RollNumber:SetText(roll)
    local c = isWinning and GREEN_FONT_COLOR or RED_FONT_COLOR
    panel.RollNumber:SetTextColor(c.r, c.g, c.b)
    PlaySound(isWinning and SOUNDKIT.UI_NEED_ROLL_POSITIVE or SOUNDKIT.UI_NEED_ROLL_NEGATIVE)
    panel.RollAnim:Show()
    for _, g in ipairs(panel._animGroups) do g:Stop(); g:Play() end
end

function Plugin:OnRollEndAll()
    if not self._activePanels then return end
    -- CANCEL_ALL_LOOT_ROLLS only cancels group rolls; a bonus roll is its own system (SPELL_CONFIRMATION_TIMEOUT closes it), so leave it.
    for _, p in ipairs({ unpack(self._activePanels) }) do
        if not p._isBonus then self:_ReleasePanel(p) end
    end
    self._activeByRoll = {}
end

-- [ BONUS ROLL ]-------------------------------------------------------------------------------------
-- Roll/Pass drive the same INSECURE Accept/DeclineSpellConfirmationPrompt Blizzard's own buttons call, so it's combat-safe; nil spellID is preview.
function Plugin:_ShowBonusRoll(spellID, duration, currencyID, currencyCost, displayItemID)
    if not IsEnabled() or not self.frame then return end
    local panel = self._bonusPanel or self:_AcquirePanel()
    panel._rollID = nil; panel._fakeEnd = nil; panel._fakeItemID = nil
    panel._isBonus = true
    panel._bonusSpellID = spellID
    panel._bonusItemID = (displayItemID and displayItemID ~= 0) and displayItemID or nil
    panel._bonusEnd = (duration and duration > 0) and (GetTime() + duration) or nil   -- duration is in SECONDS

    if panel._bonusItemID then   -- a specific item to roll for, else the generic bonus chest
        panel.Icon:SetTexture(select(5, C_Item.GetItemInfoInstant(panel._bonusItemID)) or 134400)
        panel.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        panel.Icon:SetAtlas("BonusLoot-Chest")
    end
    panel.Name:SetText(BONUS_LOOT_LABEL)
    panel.Name:SetTextColor(1.0, 0.82, 0.25)   -- gold; bonus rolls aren't quality-specific
    panel.Count:Hide()

    panel._bonusCostText = nil   -- "<n> [coin] <name>" shown in the Roll tooltip
    if C_CurrencyInfo and currencyID and currencyID > 0 then
        local ci = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if ci then panel._bonusCostText = ("%d |T%d:14|t %s"):format(currencyCost or 1, ci.iconFileID or 0, ci.name or "") end
    end

    -- the Timer bar runs in ms (PanelOnUpdate's `_bonusEnd` branch returns ms), so scale the seconds up
    local durMs = (duration and duration > 0) and (duration * 1000) or 1
    panel.Timer:SetMinMaxValues(0, durMs)
    panel.Timer:SetValue(durMs)

    panel._animating = false
    if panel.RollAnim then panel.RollAnim:Hide() end
    panel.bg:Show()
    if panel.SetBorderHidden then panel:SetBorderHidden(false) end
    panel.Timer:Show()
    panel.NeedButton:Hide(); panel.GreedButton:Hide(); panel.TransmogButton:Hide()
    panel.RollButton:Show(); panel.RollButton:Enable()
    panel.PassButton:Show(); SetButtonEnabled(panel.PassButton, true)
    self:_StylePanel(panel)

    self._activePanels = self._activePanels or {}
    if not self._bonusPanel then
        self._activePanels[#self._activePanels + 1] = panel
        self._bonusPanel = panel
    end
    panel:Show()
    self:_LayoutRolls()
end

function Plugin:_RemoveBonusRoll(spellID)
    local panel = self._bonusPanel
    if panel and (not spellID or panel._bonusSpellID == spellID) then
        self:_ReleasePanel(panel)
    end
end

-- [ SETUP + SUPPRESSION ]----------------------------------------------------------------------------
function Plugin:SetupLootRoll()
    if self._rollHooked then return end
    self._rollHooked = true
    self._activePanels = {}
    self._activeByRoll = {}

    -- Dedicated frame (never the shared EventBus), consistent with the loot capture path.
    local f = CreateFrame("Frame")
    f:RegisterEvent("START_LOOT_ROLL")
    f:RegisterEvent("CANCEL_LOOT_ROLL")
    f:RegisterEvent("CANCEL_ALL_LOOT_ROLLS")
    f:RegisterEvent("MAIN_SPEC_NEED_ROLL")
    f:RegisterEvent("SPELL_CONFIRMATION_PROMPT")    -- bonus roll prompt rides this (confirmType == BonusRoll)
    f:RegisterEvent("SPELL_CONFIRMATION_TIMEOUT")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "START_LOOT_ROLL" then
            local rollID, rollTime = ...
            self:OnRollStart(rollID, rollTime)
        elseif event == "CANCEL_LOOT_ROLL" then
            self:OnRollEnd(...)
        elseif event == "MAIN_SPEC_NEED_ROLL" then
            self:OnNeedRoll(...)
        elseif event == "SPELL_CONFIRMATION_PROMPT" then
            local spellID, confirmType, _, duration, currencyID, currencyCost, _, displayItemID = ...
            if confirmType == Enum.ConfirmationPromptUIType.BonusRoll then
                self:_ShowBonusRoll(spellID, duration, currencyID, currencyCost, displayItemID)
            end
        elseif event == "SPELL_CONFIRMATION_TIMEOUT" then
            local spellID, confirmType = ...
            if confirmType == Enum.ConfirmationPromptUIType.BonusRoll then self:_RemoveBonusRoll(spellID) end
        else
            self:OnRollEndAll()
        end
    end)
    self._rollFrame = f

    -- MUST HookScript each frame, not hooksecurefunc GroupLootFrame_OnShow: the XML bound each frame's OnShow to the original reference, so a global swap never fires.
    local function SuppressFrame(frame)
        local on = IsEnabled()
        frame:SetAlpha(on and 0 or 1)
        frame:EnableMouse(not on)
        if frame.IconFrame then frame.IconFrame:EnableMouse(not on) end
        if frame.LootButtons then
            for _, b in ipairs(frame.LootButtons) do b:EnableMouse(not on) end
        end
    end
    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame then
            frame:HookScript("OnShow", SuppressFrame)
            if frame:IsShown() then SuppressFrame(frame) end   -- catch one already up when we install
        end
    end
    if GroupLootContainer_Update then
        hooksecurefunc("GroupLootContainer_Update", function(container)
            if IsEnabled() then container:Hide() end   -- collapse the bottom-managed layout slot
        end)
    end

    -- BonusRollFrame is a UIParent child merely ANCHORED to the container, so hiding the container won't reach it — suppress it directly.
    if BonusRollFrame then
        local function SuppressBonus()
            local on = IsEnabled()
            BonusRollFrame:SetAlpha(on and 0 or 1)
            BonusRollFrame:EnableMouse(not on)
            local pf = BonusRollFrame.PromptFrame
            if pf then
                if pf.RollButton then pf.RollButton:EnableMouse(not on) end
                if pf.PassButton then pf.PassButton:EnableMouse(not on) end
            end
        end
        BonusRollFrame:HookScript("OnShow", SuppressBonus)
        if BonusRollFrame:IsShown() then SuppressBonus() end
    end
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
SLASH_ORBITROLL1 = "/orbitroll"
SlashCmdList["ORBITROLL"] = function(arg)
    if not Plugin.frame then return end
    local id = tonumber(arg) or 18832   -- Brutality Blade (epic) by default; /orbitroll <itemID> to preview another
    local item = Item:CreateFromItemID(id)
    item:ContinueOnItemLoad(function()
        local panel = Plugin:_AcquirePanel()
        panel._rollID = nil
        panel._fakeItemID = id
        panel._fakeEnd = GetTime() + FAKE_DURATION
        panel.Timer:SetMinMaxValues(0, FAKE_DURATION * 1000)
        panel.Timer:SetValue(FAKE_DURATION * 1000)
        Plugin:_FillPanel(panel, item:GetItemIcon(), item:GetItemName(), 1, item:GetItemQuality(), true, true, false)
        Plugin._activePanels = Plugin._activePanels or {}
        Plugin._activePanels[#Plugin._activePanels + 1] = panel
        panel:Show()
        Plugin:_LayoutRolls()
    end)
end

-- "/orbitbonus" previews the bonus-roll panel (no real spellID — Roll/Pass just dismiss).
SLASH_ORBITBONUS1 = "/orbitbonus"
SlashCmdList["ORBITBONUS"] = function()
    if not Plugin.frame then return end
    Plugin:_ShowBonusRoll(nil, FAKE_DURATION, BONUS_ROLL_REQUIRED_CURRENCY, 1, nil)   -- FAKE_DURATION is seconds
end
