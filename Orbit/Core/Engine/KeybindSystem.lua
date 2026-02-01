-- KeybindSystem.lua
-- Shared keybind formatting and lookup for Orbit plugins (Action Bars, Cooldown Manager, etc.)
-- Part of OrbitEngine

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-- Create module
local KeybindSystem = {}
OrbitEngine.KeybindSystem = KeybindSystem

--[ KEYBIND FORMATTING ]-----------------------------------------------------------
-- Convert verbose keybind text to compact display (SHIFT-1 → S1)

function KeybindSystem:Format(keybind)
    if not keybind or keybind == "" then return nil end
    
    local raw = tostring(keybind):upper()
    raw = raw:gsub("[%c]", "")
    
    local rawNoSpace = raw:gsub("%s+", "")
    if rawNoSpace == "" or rawNoSpace == "UNKNOWN" or rawNoSpace == "UNBOUND" then
        return nil
    end
    
    -- Extract modifiers
    local mods = ""
    if rawNoSpace:find("SHIFT") or rawNoSpace:find("S%-") then mods = mods .. "S" end
    if rawNoSpace:find("CTRL") or rawNoSpace:find("C%-") then mods = mods .. "C" end
    if rawNoSpace:find("ALT") or rawNoSpace:find("A%-") then mods = mods .. "A" end
    
    -- Handle mouse wheel
    if rawNoSpace:find("MOUSEWHEELUP") then
        return mods ~= "" and (mods .. "WU") or "WU"
    end
    if rawNoSpace:find("MOUSEWHEELDOWN") then
        return mods ~= "" and (mods .. "WD") or "WD"
    end
    
    -- Strip modifiers for processing
    local token = raw
    token = token:gsub("SHIFT%-", "")
    token = token:gsub("CTRL%-", "")
    token = token:gsub("ALT%-", "")
    token = token:gsub("S%-", "")  -- Short form
    token = token:gsub("C%-", "")  -- Short form
    token = token:gsub("A%-", "")  -- Short form
    token = token:gsub("%s+", "")
    
    local t = token
    
    -- Mouse buttons
    if t == "MIDDLEMOUSE" then t = "M3" end
    t = t:gsub("^BUTTON(%d+)$", "M%1")
    t = t:gsub("^MOUSEBUTTON(%d+)$", "M%1")
    
    -- Numpad
    t = t:gsub("NUMPADPLUS", "N+")
    t = t:gsub("NUMPADMINUS", "N-")
    t = t:gsub("^NUMPAD", "N")
    
    -- Special keys
    t = t:gsub("SPACE", "SP")
    t = t:gsub("ESCAPE", "ESC")
    t = t:gsub("DELETE", "DEL")
    t = t:gsub("BACKSPACE", "BS")
    
    -- Combine modifiers with key
    local out = mods ~= "" and (mods .. t) or t
    -- Cap at 4 characters for display
    return #out > 4 and out:sub(1, 4) or out
end

--[ BUTTON KEYBIND LOOKUP ]--------------------------------------------------------

function KeybindSystem:GetForButton(button)
    if not button or not GetBindingKey then return nil end
    
    -- Try bindingAction first
    if button.bindingAction then
        local key = GetBindingKey(button.bindingAction)
        if key then
            local text = GetBindingText(key, 1)
            if text and text ~= "" then 
                return self:Format(text)
            end
        end
    end
    
    -- Try button name click binding
    if button.GetName then
        local name = button:GetName()
        if name then
            local key = GetBindingKey("CLICK " .. name .. ":LeftButton")
            if key then
                local text = GetBindingText(key, 1)
                if text and text ~= "" then 
                    return self:Format(text)
                end
            end
        end
    end
    
    return nil
end

--[ SPELL KEYBIND LOOKUP ]---------------------------------------------------------
-- Cached spell→keybind lookup for Cooldown Manager

local spellToKeybind = {}
local lastCacheUpdate = 0
local CACHE_INTERVAL = 0.5

local function LookupKeybind(spellID)
    if not spellID then return nil end
    
    -- Method 1: ActionButtonUtil (fastest, handles most cases)
    if ActionButtonUtil and ActionButtonUtil.GetActionButtonBySpellID then
        local button = ActionButtonUtil.GetActionButtonBySpellID(spellID, false, false)
        if button then
            local text = KeybindSystem:GetForButton(button)
            if text then return text end
        end
    end
    
    -- Method 2: C_ActionBar.FindSpellActionButtons
    if C_ActionBar.FindSpellActionButtons then
        local slots = C_ActionBar.FindSpellActionButtons(spellID)
        if slots and slots[1] then
            local slot = slots[1]
            local buttons = NUM_ACTIONBAR_BUTTONS or 12
            local index = ((slot - 1) % buttons) + 1
            local key = GetBindingKey("ACTIONBUTTON" .. index)
            if key then
                local text = GetBindingText(key, 1)
                if text and text ~= "" then 
                    return KeybindSystem:Format(text)
                end
            end
        end
    end
    
    return nil
end

function KeybindSystem:InvalidateCache()
    wipe(spellToKeybind)
    lastCacheUpdate = 0
end

local function EnsureCacheFresh()
    local now = GetTime()
    if now - lastCacheUpdate < CACHE_INTERVAL then
        return
    end
    lastCacheUpdate = now
end

function KeybindSystem:GetForSpell(spellID)
    if not spellID then return nil end
    
    if issecretvalue and issecretvalue(spellID) then
        return nil
    end
    
    EnsureCacheFresh()
    
    -- Check cache first
    local cached = spellToKeybind[spellID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    
    -- Lookup and cache
    local key = LookupKeybind(spellID)
    
    -- Try base spell if not found (for talent-modified spells)
    if not key and C_Spell.GetBaseSpell then
        local base = C_Spell.GetBaseSpell(spellID)
        if base and base ~= spellID then
            key = LookupKeybind(base)
        end
    end
    
    -- Try override spell
    if not key and C_Spell.GetOverrideSpell then
        local override = C_Spell.GetOverrideSpell(spellID)
        if override and override ~= spellID then
            key = LookupKeybind(override)
        end
    end
    
    -- Cache result (use false for "no binding" to distinguish from uncached)
    spellToKeybind[spellID] = key or false
    
    return key
end

--[ EVENT REGISTRATION ]-----------------------------------------------------------

if Orbit.EventBus then
    Orbit.EventBus:On("UPDATE_BINDINGS", function() KeybindSystem:InvalidateCache() end)
    Orbit.EventBus:On("ACTIONBAR_SLOT_CHANGED", function() KeybindSystem:InvalidateCache() end)
    Orbit.EventBus:On("ACTIONBAR_PAGE_CHANGED", function() KeybindSystem:InvalidateCache() end)
    Orbit.EventBus:On("PLAYER_TALENT_UPDATE", function() KeybindSystem:InvalidateCache() end)
    Orbit.EventBus:On("PLAYER_SPECIALIZATION_CHANGED", function() KeybindSystem:InvalidateCache() end)
    Orbit.EventBus:On("SPELLS_CHANGED", function() KeybindSystem:InvalidateCache() end)
end
