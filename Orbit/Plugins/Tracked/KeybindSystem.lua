-- KeybindSystem.lua (Tracked + CooldownManager)
-- Thin wrapper that delegates to OrbitEngine.KeybindSystem
-- Attaches keybind methods to both Orbit_Tracked and Orbit_CooldownViewer

local addonName, OrbitPrivate = ...
local Orbit = _G.Orbit

-- [ CONSTANTS ] ---------------------------------------------------------------
local MAX_ATTACH_ATTEMPTS = 5
local ATTACH_RETRY_DELAY = 0.2
local PLUGIN_IDS = { "Orbit_Tracked", "Orbit_CooldownViewer" }

-- [ ATTACHMENT ] --------------------------------------------------------------
local attachAttempts = 0

local function AttachKeybindMethods(plugin, KeybindSystem)
    plugin.GetSpellKeybind = function(self, spellID)
        return KeybindSystem:GetForSpell(spellID)
    end
    plugin.GetItemKeybind = function(self, itemID)
        return KeybindSystem:GetForItem(itemID)
    end
    plugin.InvalidateKeybindCache = function(self)
        KeybindSystem:InvalidateCache()
    end
end

local function AttachToPlugins()
    attachAttempts = attachAttempts + 1

    local KeybindSystem = Orbit.Engine and Orbit.Engine.KeybindSystem
    if not KeybindSystem then
        if attachAttempts < MAX_ATTACH_ATTEMPTS then
            C_Timer.After(ATTACH_RETRY_DELAY, AttachToPlugins)
        end
        return
    end

    local allFound = true
    for _, id in ipairs(PLUGIN_IDS) do
        local plugin = Orbit:GetPlugin(id)
        if plugin then
            AttachKeybindMethods(plugin, KeybindSystem)
        else
            allFound = false
        end
    end

    if not allFound and attachAttempts < MAX_ATTACH_ATTEMPTS then
        C_Timer.After(ATTACH_RETRY_DELAY, AttachToPlugins)
        return
    end

    -- Schedule layout refresh after action bars are ready
    C_Timer.After(0.5, function()
        KeybindSystem:InvalidateCache()
        for _, id in ipairs(PLUGIN_IDS) do
            local plugin = Orbit:GetPlugin(id)
            if plugin and plugin.ApplyAll then
                plugin:ApplyAll()
            end
        end
    end)
end

C_Timer.After(0.1, AttachToPlugins)
