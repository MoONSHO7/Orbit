local _, addonTable = ...
local Orbit = addonTable

---@class OrbitCombatManager
Orbit.CombatManager = {}
local CM = Orbit.CombatManager

CM.inCombat, CM.updateQueue = false, {}
local MAX_QUEUE_SIZE = 100 -- Prevent unbounded queue growth

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        CM.inCombat = true
        CM:OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        CM.inCombat = false
        CM:OnCombatEnd()
    end
end)

function CM:IsInCombat()
    return self.inCombat or InCombatLockdown()
end

function CM:QueueUpdate(callback, context)
    if not self:IsInCombat() then
        if context then
            callback(context)
        else
            callback()
        end
        return
    end
    if #self.updateQueue >= MAX_QUEUE_SIZE then
        -- Log only once per combat session so a flood doesn't spam the ring buffer.
        if not self._queueOverflowLogged and Orbit.ErrorHandler then
            self._queueOverflowLogged = true
            Orbit.ErrorHandler:LogError("CombatManager", "QueueUpdate", "queue size limit reached (" .. MAX_QUEUE_SIZE .. ")")
        end
        return
    end
    table.insert(self.updateQueue, { callback = callback, context = context })
end

function CM:OnCombatStart()
    if EventRegistry then
        EventRegistry:TriggerEvent("Orbit.CombatStart")
    end
end

function CM:OnCombatEnd()
    self._queueOverflowLogged = false
    local queue = self.updateQueue
    self.updateQueue = {}
    for _, update in ipairs(queue) do
        local ok, err
        if update.context then
            ok, err = pcall(update.callback, update.context)
        else
            ok, err = pcall(update.callback)
        end
        if not ok then
            Orbit:Print("|cFFFF0000CombatManager Error|r:", tostring(err))
            if Orbit.ErrorHandler then
                Orbit.ErrorHandler:LogError("CombatManager", "queued_callback", err)
            end
        end
    end
    if EventRegistry then
        EventRegistry:TriggerEvent("Orbit.CombatEnd")
    end
end

function CM:RegisterCombatCallback(onStart, onEnd)
    if onStart and EventRegistry then
        EventRegistry:RegisterCallback("Orbit.CombatStart", onStart)
    end
    if onEnd and EventRegistry then
        EventRegistry:RegisterCallback("Orbit.CombatEnd", onEnd)
    end
end
