-- [ ORBIT NATIVE FRAME ]-----------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.NativeFrame = Engine.NativeFrame or {}
local NativeFrame = Engine.NativeFrame

-- [ STATE ]------------------------------------------------------------------------------------------
NativeFrame.hiddenParent = nil
NativeFrame.hidden = {}
NativeFrame.parked = {}
NativeFrame.modified = {}

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function TableCount(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function EnsureHiddenParent(self)
    if self.hiddenParent then return end
    self.hiddenParent = CreateFrame("Frame", "OrbitHiddenParent", UIParent)
    self.hiddenParent:SetAllPoints(UIParent)
    self.hiddenParent:Hide()
end

local function SafeHide(frame)
    if frame.HideBase then frame:HideBase() else pcall(frame.Hide, frame) end
end

-- [ PARK / UNPARK ]----------------------------------------------------------------------------------
function NativeFrame:Park(nativeFrame)
    if not nativeFrame or self.parked[nativeFrame] then return false end
    if InCombatLockdown() then return false end

    EnsureHiddenParent(self)

    nativeFrame:UnregisterAllEvents()
    SafeHide(nativeFrame)
    nativeFrame:SetParent(self.hiddenParent)

    if not nativeFrame._orbitParkHooked then
        local parked = self.parked
        local hiddenParent = self.hiddenParent
        hooksecurefunc(nativeFrame, "Show", function(f)
            if InCombatLockdown() then return end
            if parked[f] then SafeHide(f) end
        end)
        hooksecurefunc(nativeFrame, "SetShown", function(f, shown)
            if InCombatLockdown() then return end
            if shown and parked[f] then SafeHide(f) end
        end)
        hooksecurefunc(nativeFrame, "SetParent", function(f, parent)
            if InCombatLockdown() then return end
            if parked[f] and parent ~= hiddenParent then f:SetParent(hiddenParent) end
        end)
        nativeFrame._orbitParkHooked = true
    end

    self.parked[nativeFrame] = true
    return true
end

function NativeFrame:Unpark(nativeFrame)
    if not nativeFrame or not self.parked[nativeFrame] then return false end
    self.parked[nativeFrame] = nil
    return true
end

-- [ KEEP-ALIVE HIDE ]--------------------------------------------------------------------------------
function NativeFrame:KeepAliveHidden(nativeFrame)
    if not nativeFrame then return false end
    if InCombatLockdown() then return false end

    SafeHide(nativeFrame)

    if not nativeFrame._orbitKeepAliveHooked then
        hooksecurefunc(nativeFrame, "Show", function(f)
            if InCombatLockdown() then return end
            SafeHide(f)
        end)
        hooksecurefunc(nativeFrame, "SetShown", function(f, shown)
            if InCombatLockdown() then return end
            if shown then SafeHide(f) end
        end)
        nativeFrame._orbitKeepAliveHooked = true
    end
    return true
end

local combatExitFrame = CreateFrame("Frame")
combatExitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatExitFrame:SetScript("OnEvent", function()
    if not NativeFrame.hiddenParent then return end
    for f in pairs(NativeFrame.parked) do
        f:UnregisterAllEvents()
        if f:GetParent() ~= NativeFrame.hiddenParent then f:SetParent(NativeFrame.hiddenParent) end
        if f:IsShown() then SafeHide(f) end
    end
end)

-- [ HIDE (FULL REPARENT + EVENT TEARDOWN) ]----------------------------------------------------------
function NativeFrame:Hide(nativeFrame, options)
    if not nativeFrame then return false end
    if InCombatLockdown() then return false end
    options = options or {}

    EnsureHiddenParent(self)

    local backup = { parent = nativeFrame:GetParent(), shown = nativeFrame:IsShown() }

    nativeFrame:SetParent(self.hiddenParent)
    SafeHide(nativeFrame)

    if options.unregisterEvents ~= false then nativeFrame:UnregisterAllEvents() end

    if options.clearScripts ~= false then
        if nativeFrame:GetScript("OnEvent") then
            backup.onEvent = nativeFrame:GetScript("OnEvent")
            nativeFrame:SetScript("OnEvent", nil)
        end
        if nativeFrame:GetScript("OnUpdate") then
            backup.onUpdate = nativeFrame:GetScript("OnUpdate")
            nativeFrame:SetScript("OnUpdate", nil)
        end
    end

    self.hidden[nativeFrame] = backup
    return true
end

function NativeFrame:HideMany(frames, options)
    for _, frame in ipairs(frames) do self:Hide(frame, options) end
end

-- [ MODIFY (NON-TAINTING ALPHA / SCALE / STRATA) ]---------------------------------------------------
function NativeFrame:Modify(nativeFrame, options)
    if not nativeFrame then return nil end
    options = options or {}
    local backup = {}

    if options.scale then
        backup.scale = nativeFrame:GetScale()
        nativeFrame:SetScale(options.scale)
    end
    if options.alpha then
        backup.alpha = nativeFrame:GetAlpha()
        nativeFrame:SetAlpha(options.alpha)
    end
    if options.strata then
        backup.strata = nativeFrame:GetFrameStrata()
        nativeFrame:SetFrameStrata(options.strata)
    end

    self.modified[nativeFrame] = backup
    return backup
end

function NativeFrame:RestoreModified(nativeFrame)
    if not nativeFrame then return false end
    local backup = self.modified[nativeFrame]
    if not backup then return false end

    if backup.scale then nativeFrame:SetScale(backup.scale) end
    if backup.alpha then nativeFrame:SetAlpha(backup.alpha) end
    if backup.strata then nativeFrame:SetFrameStrata(backup.strata) end

    self.modified[nativeFrame] = nil
    return true
end

-- [ SECURE HIDE (STATE DRIVER) ]---------------------------------------------------------------------
function NativeFrame:SecureHide(nativeFrame)
    if not nativeFrame then return false end
    if InCombatLockdown() then return false end

    UnregisterStateDriver(nativeFrame, "visibility")
    RegisterStateDriver(nativeFrame, "visibility", "hide")
    return true
end

-- [ QUERIES ]----------------------------------------------------------------------------------------
function NativeFrame:IsParked(nativeFrame) return self.parked[nativeFrame] ~= nil end
function NativeFrame:IsHidden(nativeFrame) return self.hidden[nativeFrame] ~= nil end
function NativeFrame:IsModified(nativeFrame) return self.modified[nativeFrame] ~= nil end

-- [ RESTORE ]----------------------------------------------------------------------------------------
function NativeFrame:Restore(nativeFrame)
    if not nativeFrame then return false end
    if InCombatLockdown() then return false end
    local backup = self.hidden[nativeFrame]
    if not backup then return false end

    if backup.parent then nativeFrame:SetParent(backup.parent) end
    if backup.onEvent then nativeFrame:SetScript("OnEvent", backup.onEvent) end
    if backup.onUpdate then nativeFrame:SetScript("OnUpdate", backup.onUpdate) end
    if backup.shown then nativeFrame:Show() end

    self.hidden[nativeFrame] = nil
    return true
end

-- [ STATUS ]-----------------------------------------------------------------------------------------
function NativeFrame:GetStatus()
    return {
        hidden = TableCount(self.hidden),
        parked = TableCount(self.parked),
        modified = TableCount(self.modified),
    }
end
