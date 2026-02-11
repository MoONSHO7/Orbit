-- KeybindSystem.lua
-- Shared keybind formatting and lookup for Orbit plugins (Action Bars, Cooldown Manager, etc.)
-- Part of OrbitEngine

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-- Create module
local KeybindSystem = {}
OrbitEngine.KeybindSystem = KeybindSystem

-- [ KEYBIND FORMATTING ]------------------------------------------------------------
-- Convert verbose keybind text to compact display (SHIFT-1 → S1)

function KeybindSystem:Format(keybind)
    if not keybind or keybind == "" then
        return nil
    end

    local raw = tostring(keybind):upper()
    raw = raw:gsub("[%c]", "")

    local rawNoSpace = raw:gsub("%s+", "")
    if rawNoSpace == "" or rawNoSpace == "UNKNOWN" or rawNoSpace == "UNBOUND" then
        return nil
    end

    -- Extract modifiers
    local mods = ""
    if rawNoSpace:find("SHIFT") or rawNoSpace:find("S%-") then
        mods = mods .. "S"
    end
    if rawNoSpace:find("CTRL") or rawNoSpace:find("C%-") then
        mods = mods .. "C"
    end
    if rawNoSpace:find("ALT") or rawNoSpace:find("A%-") then
        mods = mods .. "A"
    end

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
    token = token:gsub("S%-", "") -- Short form
    token = token:gsub("C%-", "") -- Short form
    token = token:gsub("A%-", "") -- Short form
    token = token:gsub("%s+", "")

    local t = token

    -- Mouse buttons
    if t == "MIDDLEMOUSE" then
        t = "M3"
    end
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

-- [ BUTTON KEYBIND LOOKUP ]---------------------------------------------------------

function KeybindSystem:GetForButton(button)
    if not button or not GetBindingKey then
        return nil
    end

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

-- [ KEYBIND MAP ]---------------------------------------------------------------
-- Unified map built once per cache cycle from a single scan of all action bar
-- buttons.  Both GetForSpell and GetForItem are O(1) table lookups after the
-- initial build.

local spellKeybindMap -- lazily built, nil = needs rebuild
local itemKeybindMap -- lazily built, nil = needs rebuild

local ACTION_BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
    "MultiBar8Button",
}

local function BuildKeybindMaps()
    local spells, items = {}, {}
    if not GetActionInfo then
        return spells, items
    end
    for _, prefix in ipairs(ACTION_BAR_PREFIXES) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then
                local actionSlot = button.action or (button.GetAction and button:GetAction())
                if actionSlot then
                    local actionType, id = GetActionInfo(actionSlot)
                    if id then
                        local text = KeybindSystem:GetForButton(button)
                        if text then
                            if actionType == "spell" and not spells[id] then
                                spells[id] = text
                            elseif actionType == "item" and not items[id] then
                                items[id] = text
                            end
                        end
                    end
                end
            end
        end
    end
    return spells, items
end

local function EnsureMaps()
    if not spellKeybindMap then
        spellKeybindMap, itemKeybindMap = BuildKeybindMaps()
    end
end

function KeybindSystem:InvalidateCache()
    spellKeybindMap = nil
    itemKeybindMap = nil
end

function KeybindSystem:GetForSpell(spellID)
    if not spellID then
        return nil
    end

    if issecretvalue and issecretvalue(spellID) then
        return nil
    end

    EnsureMaps()

    -- Direct match
    local key = spellKeybindMap[spellID]
    if key then
        return key
    end

    -- Try base spell (talent-modified spells)
    if C_Spell.GetBaseSpell then
        local base = C_Spell.GetBaseSpell(spellID)
        if base and base ~= spellID then
            key = spellKeybindMap[base]
            if key then
                return key
            end
        end
    end

    -- Try override spell
    if C_Spell.GetOverrideSpell then
        local override = C_Spell.GetOverrideSpell(spellID)
        if override and override ~= spellID then
            key = spellKeybindMap[override]
            if key then
                return key
            end
        end
    end

    -- Fallback: ActionButtonUtil handles macros and other edge cases
    if ActionButtonUtil and ActionButtonUtil.GetActionButtonBySpellID then
        local button = ActionButtonUtil.GetActionButtonBySpellID(spellID, false, false)
        if button then
            key = KeybindSystem:GetForButton(button)
            if key then
                spellKeybindMap[spellID] = key -- cache for next call
                return key
            end
        end
    end

    return nil
end

function KeybindSystem:GetForItem(itemID)
    if not itemID then
        return nil
    end

    if issecretvalue and issecretvalue(itemID) then
        return nil
    end

    EnsureMaps()

    return itemKeybindMap[itemID] or nil
end

-- [ EVENT REGISTRATION ]------------------------------------------------------------

local CACHE_INVALIDATION_EVENTS = {
    "UPDATE_BINDINGS",
    "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_PAGE_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
}

if Orbit.EventBus then
    for _, event in ipairs(CACHE_INVALIDATION_EVENTS) do
        Orbit.EventBus:On(event, function()
            KeybindSystem:InvalidateCache()
        end)
    end
end
