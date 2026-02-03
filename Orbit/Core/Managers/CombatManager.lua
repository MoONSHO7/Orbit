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
    local queue = self.updateQueue
    self.updateQueue = {}
    for _, update in ipairs(queue) do
        local ok, err = pcall(function()
            if update.context then
                update.callback(update.context)
            else
                update.callback()
            end
        end)
        if not ok then
            print("Orbit: Error processing queued update:", err)
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
