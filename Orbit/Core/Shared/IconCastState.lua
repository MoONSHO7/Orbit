-- [ ICON CAST STATE ] -------------------------------------------------------------------------------
-- Range / usable / ready visuals using the SAME resources as Blizzard's CooldownViewer items (CooldownViewerConstants colors, UI-CooldownManager-OORshadow, UI-HUD-ActionBar-GCD-Flipbook) so Tracked + injected icons match the native CDM.
local _, Orbit = ...

Orbit.IconCastState = {}
local ICS = Orbit.IconCastState

local registry = setmetatable({}, { __mode = "k" })
local watcher
local colors

-- Pull the live CooldownViewerConstants item colors once they're loaded; fall back to their current values otherwise.
local function Colors()
    if colors then return colors end
    local C = CooldownViewerConstants
    local t = {
        OOR      = (C and C.ITEM_NOT_IN_RANGE_COLOR) or CreateColor(0.64, 0.15, 0.15, 1),
        USABLE   = (C and C.ITEM_USABLE_COLOR) or CreateColor(1, 1, 1, 1),
        NOMANA   = (C and C.ITEM_NOT_ENOUGH_MANA_COLOR) or CreateColor(0.5, 0.5, 1, 1),
        UNUSABLE = (C and C.ITEM_NOT_USABLE_COLOR) or CreateColor(0.4, 0.4, 0.4, 1),
    }
    if C then colors = t end
    return t
end

-- [ COLOR + OUT-OF-RANGE ] --------------------------------------------------------------------------
-- Same priority and resources as CooldownViewerCooldownItemMixin: tint the icon, plus the OOR shadow overlay.
function ICS:RefreshColor(icon, spellID)
    local tex = icon and icon.Icon
    if not tex then return end
    spellID = spellID or (registry[icon] and registry[icon].spellIDFn())
    if not spellID then return end
    local pal = Colors()
    local c
    if icon._outOfRange then
        c = pal.OOR
    else
        local usable, noMana = C_Spell.IsSpellUsable(spellID)
        c = usable and pal.USABLE or (noMana and pal.NOMANA) or pal.UNUSABLE
    end
    tex:SetVertexColor(c:GetRGBA())
    if not icon._oorShadow then
        local s = icon:CreateTexture(nil, "OVERLAY")
        s:SetAllPoints(tex)
        s:SetAtlas("UI-CooldownManager-OORshadow")
        s:SetVertexColor(1, 1, 1, 0.5)
        s:Hide()
        icon._oorShadow = s
    end
    icon._oorShadow:SetShown(icon._outOfRange == true)
end

-- [ WATCHER ] ---------------------------------------------------------------------------------------
local function OnEvent(_, event, spellID, inRange, checksRange)
    if event == "SPELL_RANGE_CHECK_UPDATE" then
        if not spellID or issecretvalue(spellID) then return end
        for icon, reg in pairs(registry) do
            if reg.spellIDFn() == spellID then
                icon._outOfRange = (checksRange == true and inRange == false) or nil
                ICS:RefreshColor(icon, spellID)
            end
        end
    else
        for icon in pairs(registry) do ICS:RefreshColor(icon) end
    end
end

-- Register a spell icon for range/usable tinting. Resolves spellID at event time so pooled/empty icons (spellIDFn -> nil) are skipped.
function ICS:Track(icon, spellIDFn)
    if not icon or not spellIDFn then return end
    registry[icon] = { spellIDFn = spellIDFn }
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:RegisterEvent("SPELL_UPDATE_USABLE")
        watcher:RegisterEvent("SPELL_RANGE_CHECK_UPDATE")
        watcher:SetScript("OnEvent", OnEvent)
    end
    local sid = spellIDFn()
    if sid and C_Spell.EnableSpellRangeCheck then
        C_Spell.EnableSpellRangeCheck(sid, true)
        icon._outOfRange = (C_Spell.IsSpellInRange and C_Spell.IsSpellInRange(sid) == false) or nil
    end
    self:RefreshColor(icon, sid)
end

-- [ READY FLASH ] -----------------------------------------------------------------------------------
-- The native CooldownFlash: a UI-HUD-ActionBar-GCD-Flipbook texture run through a 22-frame (11x2), 0.75s FlipBook animation.
function ICS:Flash(icon)
    local anchor = icon and (icon.Icon or icon)
    if not anchor then return end
    local flash = icon._readyFlash
    if not flash then
        flash = CreateFrame("Frame", nil, icon)
        flash:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 1)
        flash:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 1)
        flash:SetFrameLevel(icon:GetFrameLevel() + 6)
        local fb = flash:CreateTexture(nil, "ARTWORK")
        fb:SetAllPoints()
        fb:SetAtlas("UI-HUD-ActionBar-GCD-Flipbook")
        fb:SetAlpha(0)
        flash.Flipbook = fb
        local ag = flash:CreateAnimationGroup()
        local show = ag:CreateAnimation("Alpha")
        show:SetTarget(fb); show:SetDuration(0); show:SetOrder(1); show:SetFromAlpha(1); show:SetToAlpha(1)
        local play = ag:CreateAnimation("FlipBook")
        play:SetTarget(fb); play:SetDuration(0.75); play:SetOrder(1)
        play:SetFlipBookRows(11); play:SetFlipBookColumns(2); play:SetFlipBookFrames(22)
        play:SetFlipBookFrameWidth(0); play:SetFlipBookFrameHeight(0)
        ag:SetScript("OnFinished", function() fb:SetAlpha(0) end)
        flash.Anim = ag
        icon._readyFlash = flash
    end
    flash:Show()
    flash.Anim:Stop()
    flash.Flipbook:SetAlpha(1)
    flash.Anim:Play()
end
