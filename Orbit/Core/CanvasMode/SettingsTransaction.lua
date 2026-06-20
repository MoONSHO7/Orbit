-- [ CANVAS MODE - SETTINGS TRANSACTION ]-------------------------------------------------------------

local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode

-- [ MODULE ] ----------------------------------------------------------------------------------------
local Transaction = {}
CanvasMode.Transaction = Transaction
local NIL_SENTINEL = {}
local FIRE_DEBOUNCE = 0.05

-- [ STATE ] -----------------------------------------------------------------------------------------
local active = false
local fireTimer = nil
local plugin = nil
local systemIndex = nil
local originalSettings = {}  -- snapshot of settings at Begin()
local pendingSettings = {}   -- staged changes
local originalPositions = {} -- snapshot of ComponentPositions at Begin()
local pendingPositions = {}  -- staged position changes

-- [ DEEP COPY ] -------------------------------------------------------------------------------------
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do copy[k] = DeepCopy(v) end
    return copy
end

-- [ SESSION API ] -----------------------------------------------------------------------------------
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

-- [ SETTINGS ] --------------------------------------------------------------------------------------
function Transaction:Set(key, value)
    if not active then return end
    -- Snapshot original if first time touching this key
    if originalSettings[key] == nil then
        local current = plugin:GetSetting(systemIndex, key)
        originalSettings[key] = current ~= nil and DeepCopy(current) or NIL_SENTINEL
    end
    pendingSettings[key] = (value == nil) and NIL_SENTINEL or value
    self:FireChanged()
end

-- Read pending state only — no fallback to GetSetting (avoids recursion from PluginMixin:GetSetting)
function Transaction:GetPending(key)
    if not active then return nil end
    local pending = pendingSettings[key]
    if pending == NIL_SENTINEL then return nil end
    return pending
end

-- Effective read: pending overlay if set, else falls through to saved setting.
function Transaction:Get(key)
    if not active then return nil end
    local pending = pendingSettings[key]
    if pending == NIL_SENTINEL then return nil end
    if pending ~= nil then return pending end
    if plugin then return plugin:GetSetting(systemIndex, key) end
    return nil
end

-- [ POSITIONS ] -------------------------------------------------------------------------------------
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

function Transaction:StagePositionFromContainer(container)
    if not active or not container or not container.key then return end
    local preview = container.GetParent and container:GetParent()
    self:SetPosition(container.key, {
        anchorX = container.anchorX,
        anchorY = container.anchorY,
        offsetX = container.offsetX,
        offsetY = container.offsetY,
        justifyH = container.justifyH,
        selfAnchorY = container.selfAnchorY,
        posX = container.posX,
        posY = container.posY,
        -- Authored icon width (square icon previews that opt in) so the runtime can scale the offset with icon size.
        baseSize = (preview and preview.scalesTextWithSize and preview.sourceWidth) or nil,
    })
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

-- [ DISABLED COMPONENTS ] ---------------------------------------------------------------------------
function Transaction:SetDisabledComponents(keys)
    if not active then return end
    self:Set("DisabledComponents", keys)
end

function Transaction:GetDisabledComponents()
    return self:Get("DisabledComponents") or {}
end

function Transaction:ClearPositions() wipe(pendingPositions) end

-- [ ROLLBACK ] --------------------------------------------------------------------------------------
function Transaction:Rollback()
    if not active then return end
    local savedPlugin = plugin
    self:Clear()
    Orbit.EventBus:Fire("ORBIT_CANVAS_TRANSACTION_ENDED", savedPlugin, "rollback")
    -- Restore all frames to their pre-edit state (live + preview)
    if savedPlugin and savedPlugin.ApplySettings then savedPlugin:ApplySettings() end
    if savedPlugin and savedPlugin.SchedulePreviewUpdate then savedPlugin:SchedulePreviewUpdate() end
end

-- [ INTERNAL ] --------------------------------------------------------------------------------------
function Transaction:Clear()
    active = false
    if fireTimer and fireTimer.Cancel then fireTimer:Cancel() end
    fireTimer = nil
    plugin = nil
    systemIndex = nil
    wipe(originalSettings)
    wipe(pendingSettings)
    wipe(originalPositions)
    wipe(pendingPositions)
end

function Transaction:FireChanged()
    if fireTimer then return end
    local p = plugin
    fireTimer = C_Timer.NewTimer(FIRE_DEBOUNCE, function()
        fireTimer = nil
        if active and p then Orbit.EventBus:Fire("ORBIT_CANVAS_SETTINGS_CHANGED", p) end
    end)
end
