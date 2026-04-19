---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants
local GC = Orbit.Engine.GlowController
local GU = Orbit.Engine.GlowUtils

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local ESSENTIAL_INDEX = Constants.Cooldown.SystemIndex.Essential
local UTILITY_INDEX = Constants.Cooldown.SystemIndex.Utility
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon
local PANDEMIC_KEY = "orbitPandemic"

-- [ DEFERRED HIDE BATCHING ] --------------------------------------------------
-- Blizzard's ActionButtonSpellAlertManager does HideAll→Re-Show every refresh
-- cycle (hundreds/sec in raids). We defer hides by 1 frame so the re-Show
-- cancels the pending hide, eliminating flicker entirely.
local pendingProcHides = {}
local procHideScheduled = false
local pendingPandemicHides = {}
local pandemicHideScheduled = false

local function FlushProcHides()
    procHideScheduled = false
    for button in pairs(pendingProcHides) do
        GC:HideProc(button)
    end
    wipe(pendingProcHides)
end

local PANDEMIC_DEFER_INTERVAL = 0.2

local function FlushPandemicHides()
    pandemicHideScheduled = false
    for icon in pairs(pendingPandemicHides) do
        local pi = icon.PandemicIcon
        if pi and pi:IsShown() then
            -- Blizzard's ground truth says pandemic IS active — abort hide
            pendingPandemicHides[icon] = nil
        elseif GC:IsActive(icon, PANDEMIC_KEY) then
            GC:HidePandemic(icon)
            if not icon._orbitGlow then icon._orbitGlow = { active = {} } end
            icon._orbitGlow.suppressPandemic = nil
        end
    end
    wipe(pendingPandemicHides)
end

local function DeferProcHide(button)
    pendingProcHides[button] = true
    if not procHideScheduled then
        procHideScheduled = true
        C_Timer.After(0, FlushProcHides)
    end
end

local function DeferPandemicHide(icon)
    pendingPandemicHides[icon] = true
    if not pandemicHideScheduled then
        pandemicHideScheduled = true
        C_Timer.After(PANDEMIC_DEFER_INTERVAL, FlushPandemicHides)
    end
end

-- [ PROC GLOW HOOKS ] ---------------------------------------------------------
local function FindSystemIndexForButton(button)
    if button.orbitCDMSystemIndex then return button.orbitCDMSystemIndex end
    for systemIndex, data in pairs(CDM.viewerMap) do
        if data.viewer and data.viewer.GetItemFrames then
            for _, icon in ipairs(data.viewer:GetItemFrames()) do
                if icon == button then return systemIndex end
            end
        end
    end
    return nil
end

function CDM:HookProcGlow()
    if self.procGlowHooked or not ActionButtonSpellAlertManager then return end
    -- C_Timer.After(0) defers work out of Blizzard's call stack so writes don't taint upstream secrets.
    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
        local si = FindSystemIndexForButton(button)
        if not si then return end
        pendingProcHides[button] = nil
        C_Timer.After(0, function()
            if not button or pendingProcHides[button] then return end
            GC:ShowProc(button, function(k) return self:GetSetting(si, k) end, "ProcGlow", Constants.Glow.DefaultColor)
        end)
    end)
    hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, button)
        local si = FindSystemIndexForButton(button)
        if not si then return end
        DeferProcHide(button)
    end)
    self.procGlowHooked = true
end

-- [ GLOW TRANSPARENCY FIX ] ---------------------------------------------------
function CDM:FixGlowTransparency(glowFrame, alpha)
    if not glowFrame or not alpha then return end
    if glowFrame.ProcLoopAnim and glowFrame.ProcLoopAnim.alphaRepeat then
        glowFrame.ProcLoopAnim.alphaRepeat:SetFromAlpha(alpha)
        glowFrame.ProcLoopAnim.alphaRepeat:SetToAlpha(alpha)
    end
    if glowFrame.ProcStartAnim then
        for _, anim in pairs({ glowFrame.ProcStartAnim:GetAnimations() }) do
            if anim:GetObjectType() == "Alpha" then
                local order = anim:GetOrder()
                if order == 0 then anim:SetFromAlpha(alpha); anim:SetToAlpha(alpha)
                elseif order == 2 then anim:SetFromAlpha(alpha) end
            end
        end
    end
end

-- [ PANDEMIC GLOW ] -----------------------------------------------------------
local GlowType = Constants.Glow.Type

local function SuppressPandemicIcon(icon)
    local pi = icon.PandemicIcon
    if not pi then return end
    local state = icon._orbitGlow
    local suppress = state and state.suppressPandemic
    if not suppress then return end
    if not pi._orbitGlowHooked then
        hooksecurefunc(pi, "SetAlpha", function(self, a)
            local s = icon._orbitGlow
            if a ~= 0 and s and s.suppressPandemic then self:SetAlpha(0) end
        end)
        hooksecurefunc(pi, "Show", function(self)
            local s = icon._orbitGlow
            if s and s.suppressPandemic then self:SetAlpha(0) end
        end)
        pi._orbitGlowHooked = true
    end
    if pi:GetAlpha() ~= 0 then pi:SetAlpha(0) end
end

local function SetPandemicSuppress(icon, suppress)
    if not icon._orbitGlow then icon._orbitGlow = { active = {} } end
    icon._orbitGlow.suppressPandemic = suppress or nil
end

local HookPandemicIcon
HookPandemicIcon = function(icon, plugin, systemIndex)
    if icon._orbitPandemicHooked then return end
    if not icon.ShowPandemicStateFrame then return end
    icon._orbitPandemicHooked = true
    local function OnPandemicShow(self)
        pendingPandemicHides[self] = nil
        local glowType = plugin:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
        SetPandemicSuppress(self, true)
        SuppressPandemicIcon(self)
        if glowType == GlowType.None then
            GC:StopPandemic(self)
            return
        end
        if not GC:IsActive(self, PANDEMIC_KEY) then
            local typeName, options = GU:BuildOptions(plugin, systemIndex, "PandemicGlow", Constants.Glow.DefaultColor, PANDEMIC_KEY)
            if typeName and options then
                options.frameLevel = Constants.Levels.IconGlow
                GC:ShowPandemic(self, typeName, options, 1)
            end
        else
            GC:ShowPandemicAlpha(self, 1)
        end
    end
    local function OnPandemicHide(self)
        if GC:IsActive(self, PANDEMIC_KEY) then
            DeferPandemicHide(self)
        end
    end
    -- Defer glow work via C_Timer.After(0) to escape Blizzard's call stack. SuppressPandemicIcon stays inline — child-only write, must beat first paint.
    hooksecurefunc(icon, "ShowPandemicStateFrame", function(self)
        SuppressPandemicIcon(self)
        C_Timer.After(0, function()
            if not self then return end
            OnPandemicShow(self)
        end)
    end)
    hooksecurefunc(icon, "HidePandemicStateFrame", function(self)
        C_Timer.After(0, function()
            if not self then return end
            OnPandemicHide(self)
        end)
    end)
    hooksecurefunc(icon, "Hide", function(self)
        pendingPandemicHides[self] = nil
        C_Timer.After(0, function()
            if not self then return end
            GC:StopPandemic(self)
            SetPandemicSuppress(self, nil)
        end)
    end)
end

function CDM:CheckPandemicFrames(viewer, systemIndex)
    if not viewer then return end
    local icons = viewer.GetItemFrames and viewer:GetItemFrames()
    if not icons then return end
    local glowType = self:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
    local typeName, options, hash = GU:BuildOptions(self, systemIndex, "PandemicGlow", Constants.Glow.DefaultColor, PANDEMIC_KEY)
    for _, icon in ipairs(icons) do
        HookPandemicIcon(icon, self, systemIndex)
        local activeType = GC:GetActiveType(icon, PANDEMIC_KEY)
        if activeType and (activeType ~= typeName or (icon._orbitGlow and icon._orbitGlow.active[PANDEMIC_KEY] and icon._orbitGlow.active[PANDEMIC_KEY].hash ~= hash)) then
            GC:StopPandemic(icon)
        end
        if icon.PandemicIcon and icon.PandemicIcon:IsShown() then
            SetPandemicSuppress(icon, true)
            SuppressPandemicIcon(icon)
            if glowType ~= GlowType.None and typeName and options then
                options.frameLevel = Constants.Levels.IconGlow
                GC:ShowPandemic(icon, typeName, options, 1)
            end
        end
    end
end

function CDM:ClearAllPandemicGlows()
    wipe(pendingPandemicHides)
    for _, entry in pairs(CDM.viewerMap) do
        if entry.viewer and entry.viewer.GetItemFrames then
            local icons = entry.viewer:GetItemFrames()
            if icons then
                for _, icon in ipairs(icons) do
                    GC:StopPandemic(icon)
                    SetPandemicSuppress(icon, nil)
                end
            end
        end
    end
end
