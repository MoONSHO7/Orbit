-- [ SPELL GLOWS ] -----------------------------------------------------------------------------------
-- Per-icon conditional glow picker (proc / pandemic / active). Capability from C_CooldownViewer (tooltip-parser fallback); storage is owned per-surface via get/set closures passed to OpenMenu.
local _, Orbit = ...
local Constants = Orbit.Constants
local Engine = Orbit.Engine
local GC = Engine.GlowController
local L = Orbit.L

Orbit.SpellGlows = {}
local SpellGlows = Orbit.SpellGlows

local PROC_KEY = "orbitProcGlow"
local PANDEMIC_KEY = "orbitPandemicGlow"

-- Submenu scroll cap (native convention is ~20px rows): show at most 10 glows, scroll the rest.
local MENU_ROW_HEIGHT = 20
local MENU_MAX_VISIBLE = 10

-- [ PICKER ENTRIES ] --------------------------------------------------------------------------------
-- Parametric engine glows (numeric enum); names shared with the schema glow-type dropdown. The flipbook-pack glows (lowercase registry names) are appended live from the lib.
local ENGINE_GLOW_TYPES = {
    { name = L.CFG_GLOW_TYPE_PIXEL,    value = Constants.Glow.Type.Pixel },
    { name = L.CFG_GLOW_TYPE_STANDARD, value = Constants.Glow.Type.Medium },
    { name = L.CFG_GLOW_TYPE_AUTOCAST, value = Constants.Glow.Type.Autocast },
    { name = L.CFG_GLOW_TYPE_CLASSIC,  value = Constants.Glow.Type.Classic },
    { name = L.CFG_GLOW_TYPE_THIN,     value = Constants.Glow.Type.Thin },
    { name = L.CFG_GLOW_TYPE_THICK,    value = Constants.Glow.Type.Thick },
}
-- Registry counterparts of the engine glows share these lowercase names; skip them so each look lists once.
local ENGINE_DUP = { pixel = true, autocast = true, classic = true }

-- Engine glows + every registered pack glow (rendered via the lib.Proc path), alphabetical. Built per open so newly-loaded packs appear; Default/Disable live above the divider, not in this list.
local function BuildGlowTypeList()
    local glows = {}
    for _, g in ipairs(ENGINE_GLOW_TYPES) do glows[#glows + 1] = g end
    local LCG = LibStub and LibStub("LibOrbitGlow-1.0", true)
    if LCG and LCG.GetGlowList then
        for _, n in ipairs(LCG:GetGlowList()) do
            if not ENGINE_DUP[n] then glows[#glows + 1] = { name = n:sub(1, 1):upper() .. n:sub(2), value = n } end
        end
    end
    table.sort(glows, function(a, b) return a.name < b.name end)
    return glows
end
local CONDITION_LABELS = { proc = L.PLU_GLOW_COND_PROC, pandemic = L.PLU_GLOW_COND_PANDEMIC, active = L.PLU_GLOW_COND_ACTIVE }
local CONDITION_ORDER = { "proc", "pandemic", "active" }
local ALERT_OPTIONS = {
    { name = L.CMN_NONE,                    value = nil },
    { name = L.PLU_RAIDPANEL_READY_CHECK,   value = SOUNDKIT and SOUNDKIT.READY_CHECK },
    { name = L.PLU_GLOW_ALERT_RAID_WARNING, value = SOUNDKIT and SOUNDKIT.RAID_WARNING },
    { name = L.PLU_GLOW_ALERT_SPOKEN_NAME,  value = "tts" },
}

-- Built-in alerts + every LibSharedMedia sound (stored by name, fetched live at play time), alphabetical with None pinned first.
local function BuildSoundList()
    local sounds = {}
    for i = 2, #ALERT_OPTIONS do sounds[#sounds + 1] = ALERT_OPTIONS[i] end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.List then
        for _, n in ipairs(LSM:List("sound")) do
            if n ~= "tts" then sounds[#sounds + 1] = { name = n, value = n } end
        end
    end
    table.sort(sounds, function(a, b) return a.name < b.name end)
    table.insert(sounds, 1, ALERT_OPTIONS[1])
    return sounds
end

-- Play a per-icon condition alert (a sound-kit id, or "tts" to speak the spell name). No-op for None/nil.
function SpellGlows:FireAlert(value, spellID)
    if not value then return end
    if value == "tts" then
        if not (C_VoiceChat and C_VoiceChat.SpeakText and C_VoiceChat.GetTtsVoices) then return end
        if not spellID or issecretvalue(spellID) then return end
        local voices = C_VoiceChat.GetTtsVoices()
        local voiceID = voices and voices[1] and voices[1].voiceID
        local name = spellID and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        if voiceID and name then
            local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate() or 0
            local volume = C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume() or 100
            C_VoiceChat.SpeakText(voiceID, name, rate, volume, false)
        end
    elseif type(value) == "number" then
        PlaySound(value, "Master")
    elseif type(value) == "string" then
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local path = LSM and LSM.Fetch and LSM:Fetch("sound", value, true)
        if path then PlaySoundFile(path, "Master") end
    end
end

-- [ CAPABILITY ] ------------------------------------------------------------------------------------
-- Which conditions a source supports. C_CooldownViewer is authoritative; falls back to the tooltip parser when there's no source data.
function SpellGlows:GetConditions(itemType, id)
    local proc, pandemic, active = false, false, false
    -- No static "can this proc" API; offer Proc only for spells observed firing the spell-activation overlay (or overlayed right now). See CanProc.
    if itemType == "spell" and id then proc = self:CanProc(id) end
    local info = (itemType == "spell") and id and Orbit.CooldownData:GetInfo(id) or nil
    if info then
        if info.hasAura then active = true end
        local cdID = info.cooldownID
        if cdID and C_CooldownViewer and C_CooldownViewer.GetValidAlertTypes and Enum and Enum.CooldownViewerAlertEventType then
            local valid = C_CooldownViewer.GetValidAlertTypes(cdID)
            if valid then
                for _, t in ipairs(valid) do
                    if t == Enum.CooldownViewerAlertEventType.PandemicTime then pandemic = true
                    elseif t == Enum.CooldownViewerAlertEventType.OnAuraApplied then active = true end
                end
            end
        end
    else
        local actDur = Orbit.TooltipParser and Orbit.TooltipParser:ParseActiveDuration(itemType, id)
        if actDur and actDur > 0 then active = true end
    end
    return proc, pandemic, active
end

-- [ MENU ] ------------------------------------------------------------------------------------------
-- Glow editing is out-of-combat only: refuse to open in combat, and the watcher closes any open menu the instant combat starts.
local openMenu
local combatWatcher

local function EnsureCombatWatcher()
    if combatWatcher then return end
    combatWatcher = CreateFrame("Frame")
    combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatWatcher:SetScript("OnEvent", function()
        if openMenu and openMenu.Close then openMenu:Close() end
        openMenu = nil
        -- The colour picker uses protected keyboard APIs; close it the instant combat starts.
        local lib = LibStub and LibStub("LibOrbitColorPicker-1.0", true)
        if lib and lib.IsOpen and lib:IsOpen() and lib.CloseFrame then lib:CloseFrame() end
    end)
end

-- Per-condition glow colour: the swatch shows the stored colour (or the default) and clicking opens Orbit's colour picker.
local function CurrentGlowColor(opts, cond)
    local c = opts.getColor and opts.getColor(cond)
    if c and c.r then return c end
    return Constants.Glow.DefaultColor
end

local function AddGlowColorSwatch(glowMenu, opts, cond)
    local liveButton
    local function OnClick()
        local lib = LibStub and LibStub("LibOrbitColorPicker-1.0", true)
        if not lib then return end
        local as = Orbit.db and Orbit.db.AccountSettings
        if as and not as.RecentColors then as.RecentColors = {} end
        local cur = CurrentGlowColor(opts, cond)
        -- The picker fires its callback live on every wheel move; store immediately but debounce the heavy re-apply to the settled colour.
        local applyTimer
        lib:Open({
            initialData = { r = cur.r, g = cur.g, b = cur.b, a = cur.a or 1 },
            forceSingleColor = true,
            recentColorsDb = as and as.RecentColors,
            callback = function(result, wasCancelled)
                if wasCancelled or not result then return end
                local pin = result.pins and result.pins[1]
                if pin and pin.color and opts.setColor then
                    opts.setColor(cond, { r = pin.color.r, g = pin.color.g, b = pin.color.b, a = pin.color.a or 1 })
                    if liveButton and liveButton.leftTexture2 then liveButton.leftTexture2:SetVertexColor(pin.color.r, pin.color.g, pin.color.b) end
                    if applyTimer then applyTimer:Cancel() end
                    applyTimer = C_Timer.NewTimer(0.1, function()
                        applyTimer = nil
                        if opts.onChange then opts.onChange() end
                    end)
                end
            end,
        })
    end
    -- Native radio so the indicator sits on the left like the glow rows; force it "selected" so the dot renders, then tint the dot to the current colour.
    local desc = glowMenu:CreateRadio(L.CMN_COLOR, function() return true end, OnClick)
    desc:AddInitializer(function(button)
        liveButton = button
        local tex = button.leftTexture2
        if not tex then return end
        local c = CurrentGlowColor(opts, cond)
        tex:SetDesaturated(true)
        tex:SetVertexColor(c.r, c.g, c.b)
    end)
end

-- opts: { id, itemType, supported, get/set(cond)->type, getColor/setColor(cond)->color, getAlert/setAlert(cond), onChange(), removeCallback() }
function SpellGlows:OpenMenu(anchor, opts)
    if not anchor or not opts or not MenuUtil then return end
    if InCombatLockdown() then return end
    EnsureCombatWatcher()
    local proc, pandemic, active = self:GetConditions(opts.itemType, opts.id)
    local capable = { proc = proc, pandemic = pandemic, active = active }
    local supported = opts.supported
    openMenu = MenuUtil.CreateContextMenu(anchor, function(_, root)
        local name = opts.id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(opts.id)
        root:CreateTitle(name or "")
        for _, cond in ipairs(CONDITION_ORDER) do
            if capable[cond] and (not supported or supported[cond]) then
                local condMenu = root:CreateButton(CONDITION_LABELS[cond])
                local glowMenu = condMenu:CreateButton(L.PLU_GLOW_LABEL)
                -- "Default" inherits the container's base glow by clearing the per-icon override (type + colour).
                glowMenu:CreateRadio(L.CMN_DEFAULT, function() return opts.get and opts.get(cond) == nil end, function()
                    if opts.set then opts.set(cond, nil) end
                    if opts.setColor then opts.setColor(cond, nil) end
                    if opts.onChange then opts.onChange() end
                    if MenuResponse then return MenuResponse.Refresh end
                end)
                -- "Disable" forces no glow for this icon regardless of the container default.
                glowMenu:CreateRadio(L.PLU_GLOW_DISABLE, function() return (opts.get and opts.get(cond)) == Constants.Glow.Type.None end, function()
                    if opts.set then opts.set(cond, Constants.Glow.Type.None) end
                    if opts.onChange then opts.onChange() end
                    if MenuResponse then return MenuResponse.Refresh end
                end)
                -- Colour applies only to a real glow style, so it sits at the bottom of this section and renders only when one is selected (not Default/Disable). The menu refreshes on selection, so it appears/hides as the choice changes.
                local curGlow = opts.get and opts.get(cond)
                if opts.getColor and curGlow ~= nil and curGlow ~= Constants.Glow.Type.None then
                    AddGlowColorSwatch(glowMenu, opts, cond)
                end
                glowMenu:CreateDivider()
                for _, gt in ipairs(BuildGlowTypeList()) do
                    glowMenu:CreateRadio(gt.name, function() return (opts.get and opts.get(cond)) == gt.value end, function()
                        if opts.set then opts.set(cond, gt.value) end
                        if opts.onChange then opts.onChange() end
                        if MenuResponse then return MenuResponse.Refresh end
                    end)
                end
                glowMenu:SetScrollMode(MENU_ROW_HEIGHT * MENU_MAX_VISIBLE)
                local soundMenu = condMenu:CreateButton(L.PLU_GLOW_SOUND)
                for _, al in ipairs(BuildSoundList()) do
                    soundMenu:CreateRadio(al.name, function() return (opts.getAlert and opts.getAlert(cond)) == al.value end, function()
                        if opts.setAlert then opts.setAlert(cond, al.value) end
                        SpellGlows:FireAlert(al.value, opts.id)
                        if MenuResponse then return MenuResponse.Refresh end
                    end)
                end
                soundMenu:SetScrollMode(MENU_ROW_HEIGHT * MENU_MAX_VISIBLE)
            end
        end
        if opts.removeCallback then
            root:CreateDivider()
            root:CreateButton(L.PLU_GLOW_REMOVE, function() opts.removeCallback() end)
        end
    end)
end

-- [ RENDER OPTIONS ] --------------------------------------------------------------------------------
-- Turn a stored glow type into (typeName, options) for GlowController:Show. Returns nil when unset; None yields a nil typeName (glow off).
function SpellGlows:BuildGlowOptions(glowType, key, defaultColor)
    if glowType == nil or glowType == "" or glowType == Constants.Glow.Type.None then return nil, nil end
    local lookup = function(k)
        if k == "GType" then return glowType end
        if k == "GColor" then return defaultColor end
        return nil
    end
    return Engine.GlowUtils:BuildOptionsFromLookup(lookup, "G", defaultColor, key)
end

-- Apply (or clear) a condition glow on a frame from a stored type. Shared by every surface's render path.
function SpellGlows:ApplyGlow(frame, glowKey, glowType, defaultColor)
    if not frame or not GC then return end
    local typeName, options = self:BuildGlowOptions(glowType, glowKey, defaultColor)
    if typeName and typeName ~= "" then GC:Show(frame, glowKey, typeName, options) else GC:Hide(frame, glowKey) end
end

-- [ CDM NATIVE STORE ] ------------------------------------------------------------------------------
-- Native CDM icons have no per-instance record (one native frame per spell), so their per-icon glow is stored per-spell.
local function CDMStore()
    local gs = Orbit.db and Orbit.db.GlobalSettings
    if not gs then return nil end
    gs.CDMSpellGlows = gs.CDMSpellGlows or {}
    return gs.CDMSpellGlows
end

-- key is the cooldownID (non-secret config) — never the live spellID, which is secret in restricted combat. issecretvalue guards against any secret key reaching a table index.
function SpellGlows:GetCDM(key, cond)
    if not key or issecretvalue(key) then return nil end
    local s = CDMStore()
    local e = s and s[key]
    return e and e[cond] or nil
end

function SpellGlows:SetCDM(key, cond, glowType)
    if not key or issecretvalue(key) then return end
    local s = CDMStore()
    if not s then return end
    local e = s[key]
    if not e then e = {}; s[key] = e end
    e[cond] = glowType
end

-- Per-spell CDM glow colour, parallel to the per-spell glow type. Injected into the render lookup by CDMLookup.
local function CDMColorStore()
    local gs = Orbit.db and Orbit.db.GlobalSettings
    if not gs then return nil end
    gs.CDMSpellGlowColors = gs.CDMSpellGlowColors or {}
    return gs.CDMSpellGlowColors
end

function SpellGlows:GetCDMColor(key, cond)
    if not key or issecretvalue(key) then return nil end
    local s = CDMColorStore()
    local e = s and s[key]
    return e and e[cond] or nil
end

function SpellGlows:SetCDMColor(key, cond, color)
    if not key or issecretvalue(key) then return end
    local s = CDMColorStore()
    if not s then return end
    local e = s[key]
    if not e then e = {}; s[key] = e end
    e[cond] = color
end

local function CDMAlertStore()
    local gs = Orbit.db and Orbit.db.GlobalSettings
    if not gs then return nil end
    gs.CDMSpellAlerts = gs.CDMSpellAlerts or {}
    return gs.CDMSpellAlerts
end

function SpellGlows:GetCDMAlert(key, cond)
    if not key or issecretvalue(key) then return nil end
    local s = CDMAlertStore()
    local e = s and s[key]
    return e and e[cond] or nil
end

function SpellGlows:SetCDMAlert(key, cond, value)
    if not key or issecretvalue(key) then return end
    local s = CDMAlertStore()
    if not s then return end
    local e = s[key]
    if not e then e = {}; s[key] = e end
    e[cond] = value
end

-- key = cooldownID. Per-cooldown Type/Color override the viewer setting when set; everything else falls back unchanged (additive).
function SpellGlows:CDMLookup(key, prefix, fallback)
    local cond = (prefix == "ProcGlow" and "proc") or (prefix == "PandemicGlow" and "pandemic") or nil
    return function(k)
        if cond and k == prefix .. "Type" then
            local t = self:GetCDM(key, cond)
            if t ~= nil then return t end
        end
        if cond and k == prefix .. "Color" then
            local c = self:GetCDMColor(key, cond)
            if c ~= nil then return c end
        end
        return fallback(k)
    end
end

-- [ PROC DRIVER ] -----------------------------------------------------------------------------------
-- One shared SPELL_ACTIVATION_OVERLAY watcher for Orbit-built icons (Tracked + injected); CDM native procs stay on CooldownGlows. Resolves spellID at event time so pooled/released icons (spellIDFn -> nil) are skipped.
local procRegistry = setmetatable({}, { __mode = "k" })
local procWatcher

-- A proc's overlay fires for the resolved cast spell, which may be the talent override of the base trackedId; query all three.
local function SpellOrOverrideOverlayed(sid)
    local C = C_SpellActivationOverlay
    if not (C and C.IsSpellOverlayed) then return nil end
    if C.IsSpellOverlayed(sid) then return true end
    local ov = C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(sid)
    if ov and ov ~= sid and C.IsSpellOverlayed(ov) then return true end
    local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(sid)
    if base and base ~= sid and C.IsSpellOverlayed(base) then return true end
    return false
end

-- Mirror native RefreshOverlayGlow: drive from overlay STATE not the event payload, so an already-active proc (post-reload, spec swap, override-id mismatch) still shows. Alerts fire only on a real glow-event edge.
local function RefreshProcFrame(frame, reg, fromGlowEvent)
    local sid = reg.spellIDFn()
    if not sid then GC:Hide(frame, PROC_KEY); reg._procOn = false; return end
    local show = SpellOrOverrideOverlayed(sid)
    if show == nil then return end
    if show then
        if not reg._procOn then
            reg._procOn = true
            if fromGlowEvent and reg.alertFn then SpellGlows:FireAlert(reg.alertFn("proc"), sid) end
        end
        SpellGlows:ApplyGlow(frame, PROC_KEY, reg.glowTypeFn("proc"), (reg.colorFn and reg.colorFn("proc")) or Constants.Glow.DefaultColor)
    elseif reg._procOn then
        reg._procOn = false
        GC:Hide(frame, PROC_KEY)
    end
end

-- Account-wide record of spells that have fired the spell-activation overlay (a proc). There is no static "can this spell proc" API, so the menu offers Proc only for spells observed proccing (or overlayed right now).
local function RecordSeenProc(spellID)
    if not spellID or issecretvalue(spellID) then return end
    local as = Orbit.db and Orbit.db.AccountSettings
    if not as then return end
    as.SeenProcs = as.SeenProcs or {}
    as.SeenProcs[spellID] = true
    local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID)
    if base and base ~= spellID then as.SeenProcs[base] = true end
end

local function OnProcEvent(_, event, spellID)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then RecordSeenProc(spellID) end
    local fromGlowEvent = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    for frame, reg in pairs(procRegistry) do
        RefreshProcFrame(frame, reg, fromGlowEvent)
    end
end

-- Always-on so the seen-proc record builds even before any icon registers (CDM-only setups, fresh login).
local function EnsureProcWatcher()
    if procWatcher then return end
    procWatcher = CreateFrame("Frame")
    procWatcher:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    procWatcher:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    procWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    procWatcher:SetScript("OnEvent", OnProcEvent)
end
EnsureProcWatcher()

-- True if the spell has been seen proccing (recorded, persisted) or is overlayed right now; checks base + talent override too.
function SpellGlows:CanProc(id)
    if not id then return false end
    local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(id)
    local ov = C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(id)
    local as = Orbit.db and Orbit.db.AccountSettings
    local seen = as and as.SeenProcs
    if seen and (seen[id] or (base and seen[base]) or (ov and seen[ov])) then return true end
    local C = C_SpellActivationOverlay
    if C and C.IsSpellOverlayed and (C.IsSpellOverlayed(id) or (ov and C.IsSpellOverlayed(ov)) or (base and C.IsSpellOverlayed(base))) then return true end
    return false
end

-- spellIDFn() -> current spellID (or nil if the icon is empty/released); glowTypeFn(cond) -> chosen glow type (or nil); colorFn(cond) -> per-condition glow colour (or nil for default).
function SpellGlows:RegisterProc(frame, spellIDFn, glowTypeFn, alertFn, colorFn)
    if not frame or not spellIDFn or not glowTypeFn then return end
    local reg = { spellIDFn = spellIDFn, glowTypeFn = glowTypeFn, alertFn = alertFn, colorFn = colorFn }
    procRegistry[frame] = reg
    EnsureProcWatcher()
    RefreshProcFrame(frame, reg, false)
end
