-- [ CANVAS MODE - SETTINGS TRANSACTION ]------------------------------------------------------------
-- Transactional cache for Canvas Mode edits.
-- Buffers all changes until Apply (commit) or Cancel (rollback).
-- Fires CANVAS_SETTINGS_CHANGED so preview frames can live-update.

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode

-- [ MODULE ]-------------------------------------------------------------------------------------

local Transaction = {}
CanvasMode.Transaction = Transaction
local NIL_SENTINEL = {}

-- [ STATE ]--------------------------------------------------------------------------------------

local active = false
local plugin = nil
local systemIndex = nil
local originalSettings = {}  -- snapshot of settings at Begin()
local pendingSettings = {}   -- staged changes
local originalPositions = {} -- snapshot of ComponentPositions at Begin()
local pendingPositions = {}  -- staged position changes

-- [ DEEP COPY ]---------------------------------------------------------------------------------

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do copy[k] = DeepCopy(v) end
    return copy
end

-- [ SESSION API ]--------------------------------------------------------------------------------

function Transaction:Begin(targetPlugin, targetSystemIndex)
    self:Rollback() -- clean any stale state
    if not targetPlugin then return end

    active = true
    plugin = targetPlugin
    systemIndex = targetSystemIndex or 1
    wipe(originalSettings)
    wipe(pendingSettings)
    wipe(originalPositions)
    wipe(pendingPositions)

    -- Snapshot current ComponentPositions
    local positions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
    originalPositions = DeepCopy(positions)
end

function Transaction:IsActive()
    return active
end

function Transaction:GetPlugin()
    return plugin
end

function Transaction:GetSystemIndex()
    return systemIndex
end

-- [ SETTINGS ]-----------------------------------------------------------------------------------

function Transaction:Set(key, value)
    if not active then return end
    -- Snapshot original if first time touching this key
    if originalSettings[key] == nil then
        local current = plugin:GetSetting(systemIndex, key)
        originalSettings[key] = current ~= nil and DeepCopy(current) or NIL_SENTINEL
    end
    pendingSettings[key] = value ~= nil and value or NIL_SENTINEL
    self:FireChanged()
end

function Transaction:Get(key)
    if not active then return plugin and plugin:GetSetting(systemIndex, key) end
    local pending = pendingSettings[key]
    if pending ~= nil then return pending ~= NIL_SENTINEL and pending or nil end
    return plugin:GetSetting(systemIndex, key)
end

-- Read pending state only — no fallback to GetSetting (avoids recursion from PluginMixin:GetSetting)
function Transaction:GetPending(key)
    if not active then return nil end
    local pending = pendingSettings[key]
    if pending == NIL_SENTINEL then return nil end
    return pending
end

-- [ POSITIONS ]----------------------------------------------------------------------------------

function Transaction:SetPosition(compKey, posData)
    if not active then return end
    -- Merge into existing pending (or snapshot from original) to preserve overrides
    if not pendingPositions[compKey] then
        pendingPositions[compKey] = DeepCopy(originalPositions[compKey] or {})
    end
    for k, v in pairs(posData) do pendingPositions[compKey][k] = v end
    self:FireChanged()
end

function Transaction:GetPositions()
    if not active then return plugin and plugin:GetSetting(systemIndex, "ComponentPositions") or {} end
    -- Merge: original positions + pending overrides
    local merged = DeepCopy(originalPositions)
    for k, v in pairs(pendingPositions) do merged[k] = v end
    return merged
end

function Transaction:SetPositionOverride(compKey, overrideKey, value)
    if not active then return end
    if not pendingPositions[compKey] then
        pendingPositions[compKey] = DeepCopy(originalPositions[compKey] or {})
    end
    pendingPositions[compKey].overrides = pendingPositions[compKey].overrides or {}
    pendingPositions[compKey].overrides[overrideKey] = value
    self:FireChanged()
end

-- [ DISABLED COMPONENTS ]------------------------------------------------------------------------

function Transaction:SetDisabledComponents(keys)
    if not active then return end
    self:Set("DisabledComponents", keys)
end

function Transaction:GetDisabledComponents()
    return self:Get("DisabledComponents") or {}
end

function Transaction:ClearPositions() wipe(pendingPositions) end

-- Writes all pending settings and positions to SavedVariables.
-- NOTE: Unused — Dialog:Apply() writes directly because it needs sync/global
-- routing and rebuilds positions from preview component state.
function Transaction:Commit()
    if not active or not plugin then return end

    -- Write pending settings to SavedVariables
    for key, value in pairs(pendingSettings) do
        local writeVal = value ~= NIL_SENTINEL and value or nil
        plugin:SetSetting(systemIndex, key, writeVal)
    end

    -- Write merged positions to SavedVariables
    if next(pendingPositions) then
        local merged = self:GetPositions()
        plugin:SetSetting(systemIndex, "ComponentPositions", merged)
    end

    local savedPlugin = plugin
    self:Clear()

    -- Trigger live frame + preview refresh
    if savedPlugin.OnCanvasApply then savedPlugin:OnCanvasApply() end
end

-- [ ROLLBACK ]-----------------------------------------------------------------------------------

function Transaction:Rollback()
    if not active then return end
    local savedPlugin = plugin
    self:Clear()
    -- Restore all frames to their pre-edit state (live + preview)
    if savedPlugin and savedPlugin.ApplySettings then savedPlugin:ApplySettings() end
    if savedPlugin and savedPlugin.SchedulePreviewUpdate then savedPlugin:SchedulePreviewUpdate() end
end

-- [ INTERNAL ]-----------------------------------------------------------------------------------

function Transaction:Clear()
    active = false
    fireTimer = nil
    plugin = nil
    systemIndex = nil
    wipe(originalSettings)
    wipe(pendingSettings)
    wipe(originalPositions)
    wipe(pendingPositions)
end

local fireTimer = nil
local FIRE_DEBOUNCE = 0.05
function Transaction:FireChanged()
    if fireTimer then return end
    local p = plugin
    fireTimer = C_Timer.After(FIRE_DEBOUNCE, function()
        fireTimer = nil
        if active and p then Orbit.EventBus:Fire("CANVAS_SETTINGS_CHANGED", p) end
    end)
end
