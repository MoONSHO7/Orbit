-- [ GLOW CONTROLLER ]-----------------------------------------------------------------------------
-- Single authoritative owner for all glow operations across Orbit.
-- All consumers call this module. No other file should touch LCG directly.
local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local LCG = LibStub("LibOrbitGlow-1.0", true)

Engine.GlowController = {}
local GC = Engine.GlowController

-- [ STATE HELPERS ]----------------------------------------------------------------
local function GetState(frame)
    if not frame._orbitGlow then frame._orbitGlow = { active = {} } end
    return frame._orbitGlow
end

-- [ CORE SHOW / HIDE ]-------------------------------------------------------------
function GC:Show(frame, glowKey, typeName, options)
    if not frame or not LCG or not typeName then return end
    local state = GetState(frame)
    local entry = state.active[glowKey]
    
    if options and not options.frameLevel then 
        options.frameLevel = Constants.Levels.IconOverlay + 2 
    end
    
    local hash = Engine.GlowUtils:GetOptionsHash(options)
    if entry and entry.typeName == typeName and entry.hash == hash then return end
    if entry then LCG.Hide(frame, entry.typeName, glowKey) end
    LCG.Show(frame, typeName, options)
    state.active[glowKey] = { typeName = typeName, hash = hash }
end

function GC:Hide(frame, glowKey)
    if not frame or not LCG then return end
    local state = frame._orbitGlow
    if not state then return end
    local entry = state.active[glowKey]
    if not entry then return end
    LCG.Hide(frame, entry.typeName, glowKey)
    state.active[glowKey] = nil
end

function GC:StopAll(frame)
    if not frame or not LCG then return end
    local state = frame._orbitGlow
    if not state then return end
    for glowKey, entry in pairs(state.active) do
        LCG.Hide(frame, entry.typeName, glowKey)
    end
    wipe(state.active)
    state.suppressNative = nil
end

function GC:IsActive(frame, glowKey)
    local state = frame and frame._orbitGlow
    if not state then return false end
    return state.active[glowKey] ~= nil
end

function GC:GetActiveType(frame, glowKey)
    local state = frame and frame._orbitGlow
    if not state then return nil end
    local entry = state.active[glowKey]
    return entry and entry.typeName
end

-- [ NATIVE SUPPRESSION ]-----------------------------------------------------------
local function KillNativeAnimations(overlay)
    if overlay.animIn and overlay.animIn:IsPlaying() then overlay.animIn:Stop() end
    if overlay.animOut and overlay.animOut:IsPlaying() then overlay.animOut:Stop() end
    if overlay.ProcStartAnim and overlay.ProcStartAnim:IsPlaying() then overlay.ProcStartAnim:Stop() end
    if overlay.ProcLoopAnim and overlay.ProcLoopAnim:IsPlaying() then overlay.ProcLoopAnim:Stop() end
end

local function SuppressOverlay(overlay)
    if overlay:GetAlpha() ~= 0 then overlay:SetAlpha(0) end
    if overlay:IsShown() then overlay:Hide() end
    KillNativeAnimations(overlay)
end

local function HookNativeOverlay(overlay, conditionFunc)
    if overlay._orbitGlowHooked then return end
    hooksecurefunc(overlay, "SetAlpha", function(self, alpha)
        if alpha ~= 0 and conditionFunc() then self:SetAlpha(0) end
    end)
    hooksecurefunc(overlay, "Show", function(self)
        if conditionFunc() then self:SetAlpha(0) end
    end)
    if overlay.animIn then
        hooksecurefunc(overlay.animIn, "Play", function(self)
            if conditionFunc() then self:Stop() end
        end)
    end
    overlay._orbitGlowHooked = true
end

function GC:SuppressNative(button, suppress)
    if not button then return end
    local state = GetState(button)
    state.suppressNative = suppress or nil
    local overlay = button.overlay or button.SpellActivationAlert
    if not overlay then return end
    HookNativeOverlay(overlay, function() return state.suppressNative end)
    if suppress then SuppressOverlay(overlay) end
end

-- [ PROC GLOW ]--------------------------------------------------------------------
local PROC_KEY = "orbitProc"

function GC:ShowProc(button, optionsLookup, prefix, defaultColor)
    if not button or not LCG then return end
    local typeName, options, hash, suppress = Engine.GlowUtils:BuildOptionsFromLookup(optionsLookup, prefix, defaultColor, PROC_KEY)
    self:SuppressNative(button, suppress)
    if not typeName or not options then self:HideProc(button); return end
    self:Show(button, PROC_KEY, typeName, options)
end

function GC:HideProc(button)
    if not button then return end
    self:SuppressNative(button, false)
    self:Hide(button, PROC_KEY)
end

-- [ PANDEMIC GLOW ]----------------------------------------------------------------
local PANDEMIC_KEY = "orbitPandemic"

local function GetOrCreateWrapper(icon)
    local state = GetState(icon)
    local w = state.pandemicWrapper
    local iw, ih = icon:GetSize()
    if w then
        local ww, wh = w:GetSize()
        if ww ~= iw or wh ~= ih then
            w:SetSize(iw, ih)
            local entry = state.active[PANDEMIC_KEY]
            if entry then
                LCG.Hide(w, entry.typeName, PANDEMIC_KEY)
                state.active[PANDEMIC_KEY] = nil
            end
        end
        return w
    end
    w = CreateFrame("Frame", nil, icon)
    w:SetPoint("CENTER", icon, "CENTER")
    w:SetSize(iw, ih)
    w:SetFrameLevel(icon:GetFrameLevel())
    w:SetAlpha(0)
    state.pandemicWrapper = w
    return w
end

function GC:ShowPandemic(frame, typeName, options, alpha)
    if not frame or not LCG or not typeName then return end
    local wrapper = GetOrCreateWrapper(frame)
    wrapper:SetAlpha(alpha or 1)
    local state = GetState(frame)
    
    if options and not options.frameLevel then 
        options.frameLevel = Constants.Levels.IconOverlay + 2 
    end
    
    local hash = Engine.GlowUtils:GetOptionsHash(options)
    local entry = state.active[PANDEMIC_KEY]
    if entry and entry.typeName == typeName and entry.hash == hash then return end
    if entry then LCG.Hide(wrapper, entry.typeName, PANDEMIC_KEY) end
    LCG.Show(wrapper, typeName, options)
    state.active[PANDEMIC_KEY] = { typeName = typeName, hash = hash }
end

function GC:ShowPandemicAlpha(frame, alpha)
    if not frame then return end
    local state = frame._orbitGlow
    if not state or not state.pandemicWrapper then return end
    state.pandemicWrapper:SetAlpha(alpha or 1)
end

function GC:HidePandemic(frame)
    if not frame then return end
    local state = frame._orbitGlow
    if not state or not state.pandemicWrapper then return end
    state.pandemicWrapper:SetAlpha(0)
end

function GC:StopPandemic(frame)
    if not frame or not LCG then return end
    local state = frame._orbitGlow
    if not state then return end
    local entry = state.active[PANDEMIC_KEY]
    if entry then
        if state.pandemicWrapper then
            LCG.Hide(state.pandemicWrapper, entry.typeName, PANDEMIC_KEY)
        end
    end
    state.active[PANDEMIC_KEY] = nil
    if state.pandemicWrapper then state.pandemicWrapper:SetAlpha(0) end
end

-- [ PRELOAD ]----------------------------------------------------------------------
function GC:PreLoad(typeName, count)
    if LCG and LCG.PreLoad then LCG.PreLoad(typeName, count) end
end
