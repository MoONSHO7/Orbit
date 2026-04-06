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
    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
        local si = FindSystemIndexForButton(button)
        if not si then return end
        GC:ShowProc(button, function(k) return self:GetSetting(si, k) end, "ProcGlow", Constants.Glow.DefaultColor)
    end)
    hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, button)
        local si = FindSystemIndexForButton(button)
        if not si then return end
        GC:HideProc(button)
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
            GC:HidePandemic(self)
            SetPandemicSuppress(self, nil)
        end
    end
    hooksecurefunc(icon, "ShowPandemicStateFrame", function(self)
        SuppressPandemicIcon(self)
        OnPandemicShow(self)
    end)
    hooksecurefunc(icon, "HidePandemicStateFrame", function(self)
        OnPandemicHide(self)
    end)
    hooksecurefunc(icon, "Hide", function(self)
        GC:StopPandemic(self)
        SetPandemicSuppress(self, nil)
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
