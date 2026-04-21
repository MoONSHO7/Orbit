---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local SYSTEM_ID = DM.SystemID
local SYSTEM_INDEX = DM.SystemIndex
local DEFAULT_METER_TYPE = DM.MeterType.Dps
local DEFAULT_BAR_COUNT = 10
local DEFAULT_BAR_WIDTH = 219
local DEFAULT_BAR_HEIGHT = 20

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

Plugin.liveToggle = true
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
            local count = def.barCount or 1
            local barHeight = def.barHeight or DEFAULT_BAR_HEIGHT
            local gap = def.barGap or 0
            return count * barHeight + math.max(0, count - 1) * gap
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
            local barHeight = def.barHeight or DEFAULT_BAR_HEIGHT
            local gap = def.barGap or 0
            local stride = barHeight + gap
            local newCount = math.max(1, math.floor((value + gap) / stride + 0.5))
            def.barCount = newCount
            BaseSetSetting(self, SYSTEM_INDEX, "MeterDefs", defs)
            return
        end
    end
    BaseSetSetting(self, systemIndex, key, value)
end

-- [ STUBS (overwritten by sub-modules) ] ------------------------------------------------------------
function Plugin:InitUI() end
function Plugin:RebuildAllMeters() end
function Plugin:RenderAllMeters() end
function Plugin:RelayoutAllMeters() end
function Plugin:OnCanvasApply() self:RelayoutAllMeters() end

-- [ CANVAS STATE LOOKUP ] ---------------------------------------------------------------------------
-- Default PluginMixin reads self.frame.systemIndex; multi-meter has no single frame, so resolve via txn.
function Plugin:IsComponentDisabled(componentKey)
    local txn = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode.Transaction
    local meterId = txn and txn.GetSystemIndex and txn:GetSystemIndex()
    if not meterId then return false end
    if txn and txn.IsActive and txn:IsActive() and txn.GetDisabledComponents then
        local pending = txn:GetDisabledComponents()
        if pending then
            for _, k in ipairs(pending) do if k == componentKey then return true end end
            if pending[componentKey] then return true end
        end
    end
    local def = self:GetMeterDef(meterId)
    local list = def and def.disabledComponents
    if type(list) ~= "table" then return false end
    for _, k in ipairs(list) do if k == componentKey then return true end end
    return list[componentKey] and true or false
end

-- [ HELPERS ] ---------------------------------------------------------------------------------------
function Plugin:GetBlizzardFrame() return _G.DamageMeter end

function Plugin:IsMeterAvailable()
    if not C_DamageMeter or not C_DamageMeter.IsDamageMeterAvailable then return false end
    local ok = C_DamageMeter.IsDamageMeterAvailable()
    return ok and true or false
end

local function EnsureBlizzardAddonLoaded()
    if _G.DamageMeter then return true end
    if C_AddOns and C_AddOns.LoadAddOn then
        local loaded = C_AddOns.LoadAddOn("Blizzard_DamageMeter")
        return loaded and true or (_G.DamageMeter ~= nil)
    end
    return false
end

local function EnsureCvarEnabled()
    if InCombatLockdown() then return end
    if not SetCVar or not GetCVar then return end
    if GetCVar("damageMeterEnabled") ~= "1" then SetCVar("damageMeterEnabled", "1") end
end

-- Blizzard's data pipeline stays inert until a session window is opened once; the hidden one suffices.
local function EnsureSessionWindowShown()
    local frame = _G.DamageMeter
    if not frame or InCombatLockdown() then return end
    Orbit.db.AccountSettings = Orbit.db.AccountSettings or {}
    if Orbit.db.AccountSettings.DamageMeterFirstShown then return end
    if frame.CanShowNewSessionWindow and frame:CanShowNewSessionWindow() and frame.ShowNewSessionWindow then
        frame:ShowNewSessionWindow()
    end
    Orbit.db.AccountSettings.DamageMeterFirstShown = true
end

-- [ METER DEF FACTORY ] -----------------------------------------------------------------------------
function Plugin:GetMeterDefs()
    return self:GetSetting(SYSTEM_INDEX, "MeterDefs") or {}
end

function Plugin:_SaveMeterDefs(defs)
    self:SetSetting(SYSTEM_INDEX, "MeterDefs", defs)
end

function Plugin:GetMeterDef(id)
    local defs = self:GetMeterDefs()
    return defs[id]
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
    self:_SaveMeterDefs(defs)
end

function Plugin:GetMeterCount()
    local count = 0
    for _ in pairs(self:GetMeterDefs()) do count = count + 1 end
    return count
end

function Plugin:CanCreateMeter()
    return self:GetMeterCount() < DM.MaxMeters
end

function Plugin:CreateMeter(meterType)
    if not self:CanCreateMeter() then return nil end
    local defs = self:GetMeterDefs()
    -- Lowest unused positive id so delete-create recycles slots.
    local nextID = 1
    while defs[nextID] do nextID = nextID + 1 end
    defs[nextID] = {
        id           = nextID,
        meterType    = meterType or DEFAULT_METER_TYPE,
        sessionType  = DM.SessionType.Current,
        sessionID    = nil,
        barCount     = DEFAULT_BAR_COUNT,
        barWidth     = DEFAULT_BAR_WIDTH,
        barHeight    = DEFAULT_BAR_HEIGHT,
        barGap       = 1,
        iconPosition = 1,
        style        = 100,
        border       = 3,
        background   = 3,
        title        = 2,
        titleSize    = 14,
        -- Spawn centered so the user can immediately see it and drag it where they want.
        position     = { point = "CENTER", x = 0, y = 0 },
        scrollOffset = 0,
    }
    self:_SaveMeterDefs(defs)
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
    local DeepCopy = Orbit.Engine.DeepCopy
    local snapshot = DeepCopy and DeepCopy(dest) or CopyTable(dest)
    for k in pairs(COPYABLE_FIELDS) do
        local v = source[k]
        if v == nil then
            dest[k] = nil
        elseif type(v) == "table" then
            dest[k] = DeepCopy and DeepCopy(v) or CopyTable(v)
        else
            dest[k] = v
        end
    end
    self:_SaveMeterDefs(defs)
    self:RebuildAllMeters()
    return snapshot
end

-- Replace wholesale (not merge) so transient fields revert too, keeping undo symmetric with copy.
function Plugin:RestoreMeterSnapshot(id, snapshot)
    if not snapshot then return end
    local defs = self:GetMeterDefs()
    if not defs[id] then return end
    defs[id] = snapshot
    self:_SaveMeterDefs(defs)
    self:RebuildAllMeters()
end

function Plugin:DeleteMeter(id)
    -- Seed is tied to plugin lifetime; only disabling the plugin removes it.
    if id == DM.SeedID then return end
    local defs = self:GetMeterDefs()
    if not defs[id] then return end

    -- Wipe ephemeral edit-mode state and runtime anchor graph entries for this frame,
    -- so if the id is recycled by a future CreateMeter, the new meter starts clean.
    local frame = self.GetFrameBySystemIndex and self:GetFrameBySystemIndex(id)
    if frame then
        if Orbit.Engine and Orbit.Engine.PositionManager and Orbit.Engine.PositionManager.ClearFrame then
            Orbit.Engine.PositionManager:ClearFrame(frame)
        end
        if Orbit.Engine and Orbit.Engine.FrameAnchor and Orbit.Engine.FrameAnchor.BreakAnchor then
            Orbit.Engine.FrameAnchor:BreakAnchor(frame, true)
        end
    end

    -- Dropping the def wipes every per-meter setting (style, icon, position, anchor,
    -- componentPositions, disabledComponents, etc.) since they all live inside the def table.
    defs[id] = nil
    self:_SaveMeterDefs(defs)
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
        self:_SaveMeterDefs(defs)
        self:RenderAllMeters()
    end
end

-- Legacy master entry from pre-5.x profiles; drop it so it doesn't render as a phantom bar list.
function Plugin:MigrateLegacyMaster()
    local defs = self:GetMeterDefs()
    if defs[-1] == nil then return end
    defs[-1] = nil
    self:_SaveMeterDefs(defs)
end

-- Self-heal orphan anchors: for each def whose anchor.target is not a live meter,
-- snapshot the child's current visual position into def.position and drop the anchor.
-- Runs on every rebuild so parent-delete never has to walk children — the child's
-- def detects the stale target on its own and reverts to a free position.
function Plugin:ScrubStaleAnchors()
    local defs = self:GetMeterDefs()
    local FRAME_PREFIX = "OrbitDamageMeter"
    local uiTop = UIParent and UIParent:GetTop()
    local changed = false
    for id, def in pairs(defs) do
        if type(def.anchor) == "table" and def.anchor.target then
            local targetID = def.anchor.target:match("^" .. FRAME_PREFIX .. "(%-?%d+)$")
            local n = targetID and tonumber(targetID)
            if n and defs[n] == nil then
                local frame = self:GetFrameBySystemIndex(id)
                if frame and uiTop then
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
    if changed then self:_SaveMeterDefs(defs) end
end

function Plugin:EnsureSeedMeter()
    local defs = self:GetMeterDefs()
    if defs[DM.SeedID] then return end
    defs[DM.SeedID] = {
        id           = DM.SeedID,
        meterType    = DEFAULT_METER_TYPE,
        sessionType  = DM.SessionType.Current,
        sessionID    = nil,
        barCount     = DEFAULT_BAR_COUNT,
        barWidth     = DEFAULT_BAR_WIDTH,
        barHeight    = DEFAULT_BAR_HEIGHT,
        barGap       = 1,
        iconPosition = 1,
        style        = 100,
        border       = 3,
        background   = 3,
        title        = 2,
        titleSize    = 14,
        position     = { point = "TOPLEFT", x = 40, y = -200 },
        scrollOffset = 0,
    }
    self:_SaveMeterDefs(defs)
end

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function Plugin:OnLoad()
    EnsureBlizzardAddonLoaded()
    EnsureCvarEnabled()

    if self.InitEventBridge then self:InitEventBridge() end
    if self.InitUI then self:InitUI() end

    self:MigrateLegacyMaster()

    -- Eager build so mid-session enables draw immediately instead of waiting on the next zone change.
    -- RebuildAllMeters internally runs EnsureSeedMeter + ScrubStaleAnchors before laying out frames.
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
    if Orbit.Engine and Orbit.Engine.EditMode then
        Orbit.Engine.EditMode:RegisterCallbacks({
            Enter = function()
                if self.ReshufflePreviewRoster then self:ReshufflePreviewRoster() end
            end,
        }, self)
    end

    -- Blizzard_DamageMeter can load after our OnLoad, so re-prime the pipeline on each world entry.
    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        EnsureBlizzardAddonLoaded()
        EnsureCvarEnabled()
        C_Timer.After(0.5, function()
            EnsureSessionWindowShown()
            self:DisableBlizzardMeter()
        end)
    end, self)

    self:RegisterVisibilityEvents()
end

function Plugin:ApplySettings()
    -- `/orbit reset` wipes defs without tearing frames; detect drift so we recover without /reload.
    self:EnsureSeedMeter()
    local frames = self.GetMeterFrames and self:GetMeterFrames() or {}
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
