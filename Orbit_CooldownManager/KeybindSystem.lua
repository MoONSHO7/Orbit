-- KeybindSystem.lua (Cooldown Manager)
-- Thin wrapper that delegates to OrbitEngine.KeybindSystem
-- Maintains backwards compatibility for plugin attachment

local addonName, OrbitPrivate = ...
local Orbit = _G.Orbit

-- Defer plugin lookup to avoid race condition during load
local Plugin

local function GetPlugin()
    if not Plugin then
        Plugin = Orbit:GetPlugin("Orbit_CooldownViewer")
    end
    return Plugin
end

--[ Initial Setup ]------------------------------------------------------------
-- Attach methods to Plugin after a delay to ensure Engine and Plugin are ready

local MAX_ATTACH_ATTEMPTS = 5
local ATTACH_RETRY_DELAY = 0.2
local attachAttempts = 0

local function AttachToPlugin()
    attachAttempts = attachAttempts + 1
    local plugin = GetPlugin()

    -- Wait for Engine KeybindSystem
    local KeybindSystem = Orbit.Engine and Orbit.Engine.KeybindSystem
    if not KeybindSystem then
        if attachAttempts < MAX_ATTACH_ATTEMPTS then
            C_Timer.After(ATTACH_RETRY_DELAY, AttachToPlugin)
        end
        return
    end

    if not plugin then
        if attachAttempts < MAX_ATTACH_ATTEMPTS then
            C_Timer.After(ATTACH_RETRY_DELAY, AttachToPlugin)
        else
            Orbit:Print("|cFFFF0000[KeybindSystem]|r Failed to attach - CooldownManager plugin not found after", MAX_ATTACH_ATTEMPTS, "attempts")
        end
        return
    end

    -- Attach wrapper methods that delegate to Engine
    plugin.GetSpellKeybind = function(self, spellID)
        return KeybindSystem:GetForSpell(spellID)
    end

    plugin.InvalidateKeybindCache = function(self)
        KeybindSystem:InvalidateCache()
    end

    -- Schedule layout refresh after action bars are ready
    C_Timer.After(0.5, function()
        KeybindSystem:InvalidateCache()
        if plugin.ApplyAll then
            plugin:ApplyAll()
        end
    end)
end

C_Timer.After(0.1, AttachToPlugin)
