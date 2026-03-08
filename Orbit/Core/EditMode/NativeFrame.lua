-- [ ORBIT NATIVE FRAME ]----------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.NativeFrame = Engine.NativeFrame or {}
local NativeFrame = Engine.NativeFrame

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local OFFSCREEN_OFFSET = 10000

-- [ STATE ]-----------------------------------------------------------------------------------------

NativeFrame.hiddenParent = nil
NativeFrame.hidden = {}
NativeFrame.disabled = {}
NativeFrame.modified = {}
NativeFrame.protected = {}

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function TableCount(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- [ SCENARIO 1: HIDE & REPLACE ]--------------------------------------------------------------------

function NativeFrame:Hide(nativeFrame, options)
    if not nativeFrame then return false end
    options = options or {}

    if not self.hiddenParent then
        self.hiddenParent = CreateFrame("Frame", "OrbitHiddenParent", UIParent)
        self.hiddenParent:Hide()
        self.hiddenParent:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -OFFSCREEN_OFFSET, OFFSCREEN_OFFSET)
    end

    local backup = { parent = nativeFrame:GetParent(), shown = nativeFrame:IsShown(), events = {} }

    nativeFrame:SetParent(self.hiddenParent)
    nativeFrame:Hide()

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

-- [ SCENARIO 2: DISABLE ONLY ]----------------------------------------------------------------------

function NativeFrame:Disable(nativeFrame, options)
    if not nativeFrame then return false end
    options = options or {}

    local backup = { onShow = nativeFrame:GetScript("OnShow"), shown = nativeFrame:IsShown() }

    nativeFrame:Hide()
    nativeFrame:SetScript("OnShow", function(self) self:Hide() end)

    if options.unregisterEvents then
        nativeFrame:UnregisterAllEvents()
        backup.eventsUnregistered = true
    end

    self.disabled[nativeFrame] = backup
    return true
end

function NativeFrame:Enable(nativeFrame)
    if not nativeFrame then return false end
    local backup = self.disabled[nativeFrame]
    if not backup then return false end

    nativeFrame:SetScript("OnShow", backup.onShow)
    if backup.shown then nativeFrame:Show() end
    self.disabled[nativeFrame] = nil
    return true
end

-- [ SCENARIO 3: MODIFY IN-PLACE ]-------------------------------------------------------------------

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

-- [ SCENARIO 4: PROTECT ]--------------------------------------------------------------------------

function NativeFrame:Protect(nativeFrame)
    if not nativeFrame then return false end
    if self.protected and self.protected[nativeFrame] then return true end

    local backup = {
        alpha = nativeFrame:GetAlpha(),
        mouse = nativeFrame:IsMouseEnabled(),
        clamped = nativeFrame:IsClampedToScreen(),
    }

    nativeFrame:SetClampedToScreen(false)
    nativeFrame:SetClampRectInsets(0, 0, 0, 0)
    nativeFrame:ClearAllPoints()
    nativeFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -OFFSCREEN_OFFSET, OFFSCREEN_OFFSET)
    nativeFrame:SetAlpha(0)
    nativeFrame:EnableMouse(false)

    if not nativeFrame.orbitProtectedHook then
        hooksecurefunc(nativeFrame, "SetPoint", function(f)
            if InCombatLockdown() then return end
            if not f.isMovingOffscreen then
                f.isMovingOffscreen = true
                f:ClearAllPoints()
                f:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -OFFSCREEN_OFFSET, OFFSCREEN_OFFSET)
                f.isMovingOffscreen = false
            end
        end)

        hooksecurefunc(nativeFrame, "SetAlpha", function(f, a)
            if f.isSettingAlpha then return end
            if a and a ~= 0 then
                f.isSettingAlpha = true
                f:SetAlpha(0)
                f.isSettingAlpha = false
            end
        end)

        nativeFrame.orbitProtectedHook = true
    end

    self.protected[nativeFrame] = backup
    return true
end

-- [ SCENARIO 5: SECURE HIDE ]----------------------------------------------------------------------

function NativeFrame:SecureHide(nativeFrame)
    if not nativeFrame then return false end
    if InCombatLockdown() then return false end

    UnregisterStateDriver(nativeFrame, "visibility")
    RegisterStateDriver(nativeFrame, "visibility", "hide")
    return true
end

-- [ QUERIES ]---------------------------------------------------------------------------------------

function NativeFrame:IsHidden(nativeFrame) return self.hidden[nativeFrame] ~= nil end
function NativeFrame:IsDisabled(nativeFrame) return self.disabled[nativeFrame] ~= nil end
function NativeFrame:IsProtected(nativeFrame) return self.protected[nativeFrame] ~= nil end

-- [ RESTORE ]---------------------------------------------------------------------------------------

function NativeFrame:Restore(nativeFrame)
    if not nativeFrame then return false end
    local backup = self.hidden[nativeFrame]
    if not backup then return false end

    if backup.parent then nativeFrame:SetParent(backup.parent) end
    if backup.onEvent then nativeFrame:SetScript("OnEvent", backup.onEvent) end
    if backup.onUpdate then nativeFrame:SetScript("OnUpdate", backup.onUpdate) end
    if backup.shown then nativeFrame:Show() end

    self.hidden[nativeFrame] = nil
    return true
end

-- [ STATUS ]----------------------------------------------------------------------------------------

function NativeFrame:GetStatus()
    return {
        hidden = TableCount(self.hidden),
        disabled = TableCount(self.disabled),
        modified = TableCount(self.modified),
        protected = TableCount(self.protected),
    }
end
