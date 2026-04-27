---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local SYSTEM_ID = DM.SystemID
local SYSTEM_INDEX = DM.SystemIndex
local DEFAULT_METER_TYPE = DM.MeterType.Dps

-- [ PLUGIN REGISTRATION ] ---------------------------------------------------------------------------
-- ComponentPositions MUST match Default*Pos fallbacks in DamageMeterUI or Reset Positions drifts.
local Plugin = Orbit:RegisterPlugin("Damage Meter", SYSTEM_ID, {
    defaults = {
        MeterDefs   = {},
        DisabledComponents = {},
        AutoSwitchToCurrent = true,
        ComponentPositions = {
            Rank       = { anchorX = "LEFT",  offsetX = 4,  anchorY = "CENTER", offsetY = 0, justifyH = "LEFT"  },
            Name       = { anchorX = "LEFT",  offsetX = 26, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT"  },
            DPS        = { anchorX = "RIGHT", offsetX = 52, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            DamageDone = { anchorX = "RIGHT", offsetX = 4,  anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
        },
    },
})

-- DamageMeter's disable path mutates the Blizzard frame (NeutralizeRoot, InstallShowGuard hooks);
-- toggling at runtime cannot cleanly reverse those mutations, so require a reload.
Plugin.liveToggle = false
Plugin.canvasMode = true

-- [ SETTING OVERRIDES ] -----------------------------------------------------------------------------
-- Edit Mode resize writes per-meter fields via plugin:GetSetting(meterID, key); route into MeterDefs.

local BaseGetSetting = Plugin.GetSetting
local BaseSetSetting = Plugin.SetSetting

local DEF_KEY_MAP = {
    BarWidth            = "barWidth",
    BarHeight           = "barHeight",
    BarCount            = "barCount",
    BarGap              = "barGap",
    IconPosition        = "iconPosition",
    Style               = "style",
    Border              = "border",
    Background          = "background",
    Title               = "title",
    TitleSize           = "titleSize",
    Position            = "position",
    Anchor              = "anchor",
    ComponentPositions  = "componentPositions",
    DisabledComponents  = "disabledComponents",
    SessionType         = "sessionType",
    SessionID           = "sessionID",
    ViewMode            = "viewMode",
    BreakdownGUID       = "breakdownGUID",
    BreakdownCreatureID = "breakdownCreatureID",
    BreakdownClass      = "breakdownClass",
    BreakdownName       = "breakdownName",
}

-- Migration: legacy string-form iconPosition normalized on read so the int slider doesn't crash.
local ICON_STRING_TO_INT = { LEFT = 1, OFF = 2, RIGHT = 3 }

-- Meter id 1 (the seed) collides with SYSTEM_INDEX=1; defs-membership (not value-equality) is the only safe test.
local function ResolveMeterDef(plugin, systemIndex)
    if systemIndex == nil then return nil end
    local defs = BaseGetSetting(plugin, SYSTEM_INDEX, "MeterDefs") or {}
    return defs[systemIndex], defs
end

function Plugin:GetSetting(systemIndex, key)
    local def = ResolveMeterDef(self, systemIndex)
    if def then
        local field = DEF_KEY_MAP[key]
        if field then
            local val = def[field]
            if key == "IconPosition" and type(val) == "string" then
                return ICON_STRING_TO_INT[val] or 1
            end
            return val
        end
        if key == "TotalHeight" then
            -- Matches DamageMeterUI.FrameHeightFor: N bars stacked with (N-1) gaps between.
            return def.barCount * def.barHeight + math.max(0, def.barCount - 1) * def.barGap
        end
    end
    return BaseGetSetting(self, systemIndex, key)
end

function Plugin:SetSetting(systemIndex, key, value)
    local def, defs = ResolveMeterDef(self, systemIndex)
    if def then
        local field = DEF_KEY_MAP[key]
        if field then
            def[field] = value
            BaseSetSetting(self, SYSTEM_INDEX, "MeterDefs", defs)
            return
        end
        if key == "TotalHeight" then
            local stride = def.barHeight + def.barGap
            def.barCount = math.max(1, math.floor((value + def.barGap) / stride + 0.5))
            BaseSetSetting(self, SYSTEM_INDEX, "MeterDefs", defs)
            return
        end
    end
    BaseSetSetting(self, systemIndex, key, value)
end

-- Canvas + view-mode plumbing: RelayoutAllMeters is overridden by DamageMeterUI; this is the real hook.
function Plugin:OnCanvasApply() self:RelayoutAllMeters() end

-- [ CANVAS STATE LOOKUP ] ---------------------------------------------------------------------------
-- Default PluginMixin reads self.frame.systemIndex; multi-meter has no single frame, so resolve via txn.
-- NormalizeMeterDefs rewrites persisted disabledComponents to hash form; Dock stages txn in array
-- form, so this helper checks both shapes without allocating a temporary hash on every call.
local function ListContainsKey(list, key)
    if type(list) ~= "table" then return false end
    if list[key] then return true end
    for _, v in ipairs(list) do if v == key then return true end end
    return false
end

function Plugin:IsComponentDisabled(componentKey)
    local txn = Orbit.Engine.CanvasMode.Transaction
    local meterId = txn:GetSystemIndex()
    if not meterId then return false end
    if txn:IsActive() and ListContainsKey(txn:GetDisabledComponents(), componentKey) then
        return true
    end
    local def = self:GetMeterDef(meterId)
    return def and ListContainsKey(def.disabledComponents, componentKey) or false
end

-- [ HELPERS ] ---------------------------------------------------------------------------------------
local function EnsureBlizzardAddonLoaded()
    if _G.DamageMeter then return end
    C_AddOns.LoadAddOn("Blizzard_DamageMeter")
end

local function EnsureCvarDisabled()
    if InCombatLockdown() then return end
    if GetCVar("damageMeterEnabled") ~= "0" then SetCVar("damageMeterEnabled", "0") end
end

-- [ METER DEF FACTORY ] -----------------------------------------------------------------------------
function Plugin:GetMeterDefs()
    return self:GetSetting(SYSTEM_INDEX, "MeterDefs") or {}
end

function Plugin:SaveMeterDefs(defs)
    self:SetSetting(SYSTEM_INDEX, "MeterDefs", defs)
end

function Plugin:GetMeterDef(id)
    return self:GetMeterDefs()[id]
end

-- Sentinel: pairs() skips nil-valued patch keys, so erasing a field needs an explicit marker.
Plugin.CLEAR = {}
function Plugin:UpdateMeterDef(id, patch)
    local defs = self:GetMeterDefs()
    local def = defs[id]
    if not def then return end
    for k, v in pairs(patch) do
        if v == Plugin.CLEAR then def[k] = nil else def[k] = v end
    end
    self:SaveMeterDefs(defs)
end

function Plugin:GetMeterCount()
    local count = 0
    for _ in pairs(self:GetMeterDefs()) do count = count + 1 end
    return count
end

function Plugin:CanCreateMeter()
    return self:GetMeterCount() < DM.MaxMeters
end

-- Clones the constants-level position template so CreateMeter/EnsureSeedMeter don't share memory.
local function ClonePosition(pos)
    return { point = pos.point, x = pos.x, y = pos.y }
end

-- Applies DM.DefaultDef fields to a def table in-place so create/seed/normalize share one source of truth.
local function ApplyDefaultDefFields(def)
    for k, v in pairs(DM.DefaultDef) do def[k] = v end
end

function Plugin:CreateMeter(meterType)
    if not self:CanCreateMeter() then return nil end
    local defs = self:GetMeterDefs()
    -- Lowest unused positive id so delete-create recycles slots.
    local nextID = 1
    while defs[nextID] do nextID = nextID + 1 end
    local def = {
        id           = nextID,
        meterType    = meterType or DEFAULT_METER_TYPE,
        sessionType  = DM.SessionType.Current,
        sessionID    = nil,
        -- Spawn centered so the user can immediately see it and drag it where they want.
        position     = ClonePosition(DM.CenteredPosition),
        scrollOffset = 0,
    }
    ApplyDefaultDefFields(def)
    defs[nextID] = def
    self:SaveMeterDefs(defs)
    self:RebuildAllMeters()
    return nextID
end

-- Quick Copy whitelist: styling only. Identity, position, meterType/session, and view state stay put.
local COPYABLE_FIELDS = {
    barWidth           = true,
    barHeight          = true,
    barCount           = true,
    barGap             = true,
    iconPosition       = true,
    style              = true,
    border             = true,
    background         = true,
    title              = true,
    titleSize          = true,
    componentPositions = true,
    disabledComponents = true,
}

-- Returns a pre-copy snapshot for the settings dialog's Undo button.
function Plugin:CopyMeterSettings(sourceID, destID)
    local defs = self:GetMeterDefs()
    local source, dest = defs[sourceID], defs[destID]
    if not source or not dest then return nil end
    local snapshot = CopyTable(dest)
    for k in pairs(COPYABLE_FIELDS) do
        local v = source[k]
        if v == nil then
            dest[k] = nil
        elseif type(v) == "table" then
            dest[k] = CopyTable(v)
        else
            dest[k] = v
        end
    end
    self:SaveMeterDefs(defs)
    self:RebuildAllMeters()
    return snapshot
end

-- Replace wholesale (not merge) so transient fields revert too, keeping undo symmetric with copy.
function Plugin:RestoreMeterSnapshot(id, snapshot)
    if not snapshot then return end
    local defs = self:GetMeterDefs()
    if not defs[id] then return end
    defs[id] = snapshot
    self:SaveMeterDefs(defs)
    self:RebuildAllMeters()
end

function Plugin:DeleteMeter(id)
    -- Seed is tied to plugin lifetime; only disabling the plugin removes it.
    if id == DM.SeedID then return end
    local defs = self:GetMeterDefs()
    if not defs[id] then return end

    -- Wipe ephemeral edit-mode state and runtime anchor graph entries for this frame,
    -- so if the id is recycled by a future CreateMeter, the new meter starts clean.
    local frame = self:GetFrameBySystemIndex(id)
    if frame then
        Orbit.Engine.PositionManager:ClearFrame(frame)
        Orbit.Engine.FrameAnchor:BreakAnchor(frame, true)
    end

    -- Dropping the def wipes every per-meter setting (style, icon, position, anchor,
    -- componentPositions, disabledComponents, etc.) since they all live inside the def table.
    defs[id] = nil
    self:SaveMeterDefs(defs)
    self:RebuildAllMeters()
end

-- Snapshot parent class so spell bars inherit its color; DamageMeterCombatSpell has no school field.
function Plugin:EnterBreakdown(id, sourceGUID, sourceCreatureID, classFilename, displayName)
    self:UpdateMeterDef(id, {
        viewMode            = "breakdown",
        breakdownGUID       = sourceGUID,
        breakdownCreatureID = sourceCreatureID,
        breakdownClass      = classFilename or "",
        breakdownName       = displayName or "",
        scrollOffset        = 0,
    })
    self:RenderAllMeters()
end

-- Returns a breakdown meter to the normal chart view.
function Plugin:ExitBreakdown(id)
    self:UpdateMeterDef(id, {
        viewMode            = "chart",
        breakdownGUID       = Plugin.CLEAR,
        breakdownCreatureID = Plugin.CLEAR,
        breakdownClass      = Plugin.CLEAR,
        breakdownName       = Plugin.CLEAR,
        scrollOffset        = 0,
    })
    self:RenderAllMeters()
end

function Plugin:EnterHistory(id)
    self:UpdateMeterDef(id, {
        viewMode     = "history",
        scrollOffset = 0,
    })
    self:RenderAllMeters()
end

function Plugin:ReturnToChart(id)
    self:UpdateMeterDef(id, {
        viewMode            = "chart",
        breakdownGUID       = Plugin.CLEAR,
        breakdownCreatureID = Plugin.CLEAR,
        breakdownClass      = Plugin.CLEAR,
        breakdownName       = Plugin.CLEAR,
        scrollOffset        = 0,
    })
    self:RenderAllMeters()
end

-- Combat-start flip: force every meter to Current / chart so users don't stare at stale Overall data.
function Plugin:SnapAllMetersToCurrent()
    local defs = self:GetMeterDefs()
    local changed = false
    for _, def in pairs(defs) do
        if def.sessionType ~= DM.SessionType.Current or def.sessionID ~= nil
           or (def.viewMode ~= nil and def.viewMode ~= "chart")
           or def.breakdownGUID ~= nil or def.scrollOffset ~= 0 then
            def.sessionType         = DM.SessionType.Current
            def.sessionID           = nil
            def.sessionName         = nil
            def.viewMode            = "chart"
            def.breakdownGUID       = nil
            def.breakdownCreatureID = nil
            def.breakdownClass      = nil
            def.breakdownName       = nil
            def.scrollOffset        = 0
            changed = true
        end
    end
    if changed then
        self:SaveMeterDefs(defs)
        self:RenderAllMeters()
    end
end

-- Legacy master entry from pre-5.x profiles; drop it so it doesn't render as a phantom bar list.
function Plugin:MigrateLegacyMaster()
    local defs = self:GetMeterDefs()
    if defs[-1] == nil then return end
    defs[-1] = nil
    self:SaveMeterDefs(defs)
end

-- Self-heal orphan anchors: for each def whose anchor.target is not a live meter,
-- snapshot the child's current visual position into def.position and drop the anchor.
-- Runs on every rebuild so parent-delete never has to walk children — the child's
-- def detects the stale target on its own and reverts to a free position.
function Plugin:ScrubStaleAnchors()
    local defs = self:GetMeterDefs()
    local FRAME_PREFIX = "OrbitDamageMeter"
    local uiTop = UIParent:GetTop()
    local changed = false
    for id, def in pairs(defs) do
        if type(def.anchor) == "table" and def.anchor.target then
            local targetID = def.anchor.target:match("^" .. FRAME_PREFIX .. "(%-?%d+)$")
            local n = targetID and tonumber(targetID)
            if n and defs[n] == nil then
                local frame = self:GetFrameBySystemIndex(id)
                if frame then
                    local left, top = frame:GetLeft(), frame:GetTop()
                    if left and top then
                        def.position = { point = "TOPLEFT", x = left, y = top - uiTop }
                    end
                end
                def.anchor = nil
                changed = true
            end
        end
    end
    if changed then self:SaveMeterDefs(defs) end
end

function Plugin:EnsureSeedMeter()
    local defs = self:GetMeterDefs()
    if defs[DM.SeedID] then return end
    local def = {
        id           = DM.SeedID,
        meterType    = DEFAULT_METER_TYPE,
        sessionType  = DM.SessionType.Current,
        sessionID    = nil,
        position     = ClonePosition(DM.SeedPosition),
        scrollOffset = 0,
    }
    ApplyDefaultDefFields(def)
    defs[DM.SeedID] = def
    self:SaveMeterDefs(defs)
end

-- Backfill missing styling fields on every def. Profiles from earlier code paths can drop fields
-- (partial saves, legacy migrations), leaving nil holes that the render path would arithmetic on.
-- Also normalizes disabledComponents into hash form so IsComponentDisabled stays O(1).
function Plugin:NormalizeMeterDefs()
    local defs = self:GetMeterDefs()
    local changed = false
    for _, def in pairs(defs) do
        for k, v in pairs(DM.DefaultDef) do
            if def[k] == nil then def[k] = v; changed = true end
        end
        local list = def.disabledComponents
        if type(list) == "table" and #list > 0 then
            local hash = {}
            for _, key in ipairs(list) do hash[key] = true end
            for k, v in pairs(list) do
                if type(k) == "string" and v then hash[k] = true end
            end
            def.disabledComponents = hash
            changed = true
        end
    end
    if changed then self:SaveMeterDefs(defs) end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function Plugin:OnLoad()
    EnsureBlizzardAddonLoaded()
    EnsureCvarDisabled()

    self:InitEventBridge()
    self:InitUI()

    self:MigrateLegacyMaster()

    -- Eager build so mid-session enables draw immediately instead of waiting on the next zone change.
    -- RebuildAllMeters internally runs EnsureSeedMeter + NormalizeMeterDefs + ScrubStaleAnchors.
    self:RebuildAllMeters()

    self:RegisterStandardEvents()

    Orbit.EventBus:On("PLAYER_REGEN_DISABLED", function()
        if self:GetSetting(SYSTEM_INDEX, "AutoSwitchToCurrent") then
            self:SnapAllMetersToCurrent()
        end
    end, self)

    Orbit.EventBus:On("ORBIT_PROFILE_CHANGED", function()
        C_Timer.After(0.15, function()
            self:MigrateLegacyMaster()
            self:RebuildAllMeters()
        end)
    end, self)

    -- Separate Enter hook so the roster reshuffles BEFORE ApplySettings paints the preview.
    Orbit.Engine.EditMode:RegisterCallbacks({
        Enter = function() self:ReshufflePreviewRoster() end,
    }, self)

    -- Blizzard_DamageMeter can load after our OnLoad, so re-prime the pipeline on each world entry.
    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        EnsureBlizzardAddonLoaded()
        EnsureCvarDisabled()
        C_Timer.After(0.5, function() self:DisableBlizzardMeter() end)
    end, self)

    self:RegisterVisibilityEvents()
end

function Plugin:ApplySettings()
    -- `/orbit reset` wipes defs without tearing frames; detect drift so we recover without /reload.
    self:EnsureSeedMeter()
    local frames = self:GetMeterFrames()
    local defs = self:GetMeterDefs()
    local drift = false
    for id in pairs(frames) do
        if not defs[id] then drift = true; break end
    end
    if not drift then
        for id in pairs(defs) do
            if not frames[id] then drift = true; break end
        end
    end
    if drift then
        self:RebuildAllMeters()
    else
        self:RelayoutAllMeters()
    end
end
