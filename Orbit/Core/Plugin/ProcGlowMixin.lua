-- [ ORBIT PROC GLOW MIXIN ]--------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local LCG = LibStub("LibOrbitGlow-1.0", true)
local GLOW_KEY = "orbitProc"

Orbit.ProcGlowMixin = {}

function Orbit.ProcGlowMixin:ApplyProcGlow(button, optionsLookup, prefix, defaultColor)
    if not button or not LCG then return end
    
    local nativeOverlay = button.overlay or button.SpellActivationAlert
    if nativeOverlay and not button.orbitAlphaHooked then
        Engine.GlowUtils:LockNativeAlpha(nativeOverlay, function()
            return button.orbitSuppressNativeGlow
        end)
        button.orbitAlphaHooked = true
    end
    
    local typeName, options, hash, suppress = Engine.GlowUtils:BuildOptionsFromLookup(optionsLookup, prefix, defaultColor, GLOW_KEY)
    
    button.orbitSuppressNativeGlow = suppress
    
    local overlay = button.overlay or button.SpellActivationAlert
    if suppress and overlay then
        Engine.GlowUtils:ForceUpdateNativeAlpha(overlay, function() return true end)
    end
    
    if not typeName or not options then 
        self:ClearProcGlow(button)
        return 
    end
    
    -- Hash check (not just type name): re-fire even on same glow type when option payload (color, size) changed.
    if button.orbitProcGlowActive == typeName and button.orbitProcGlowHash == hash then
        return
    end
    
    if button.orbitProcGlowActive then
        self:ClearProcGlow(button)
    end
    
    LCG.Show(button, typeName, options)
    
    button.orbitProcGlowActive = typeName
    button.orbitProcGlowHash = hash
end

function Orbit.ProcGlowMixin:ClearProcGlow(button)
    if not button or not LCG then return end
    
    button.orbitSuppressNativeGlow = nil
    if button.orbitProcGlowActive then
        LCG.Hide(button, button.orbitProcGlowActive, GLOW_KEY)
        button.orbitProcGlowActive = nil
        button.orbitProcGlowHash = nil
    end
end
