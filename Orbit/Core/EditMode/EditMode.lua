-- [ ORBIT EDIT MODE ENGINE ] ------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.EditMode = Engine.EditMode or {}
local EditMode = Engine.EditMode

-- [ API ]--------------------------------------------------------------------------------------------
function EditMode:RegisterEnterCallback(callback, owner)
    if not EventRegistry then return end
    EventRegistry:RegisterCallback("EditMode.Enter", callback, owner)
end

function EditMode:RegisterExitCallback(callback, owner)
    if not EventRegistry then return end
    EventRegistry:RegisterCallback("EditMode.Exit", callback, owner)
end

function EditMode:RegisterCallbacks(callbacks, owner)
    if not EventRegistry then return end
    if callbacks.Enter then self:RegisterEnterCallback(callbacks.Enter, owner) end
    if callbacks.Exit then self:RegisterExitCallback(callbacks.Exit, owner) end
end

function EditMode:UnregisterCallbacks(owner)
    if not EventRegistry then return end
    EventRegistry:UnregisterCallback("EditMode.Enter", owner)
    EventRegistry:UnregisterCallback("EditMode.Exit", owner)
end

-- [ COMBAT SAFETY: AUTO-EXIT EDIT MODE ] ------------------------------------------------------------
if EditModeManagerFrame then
    local combatExitFrame = CreateFrame("Frame")
    combatExitFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatExitFrame:SetScript("OnEvent", function()
        if EditModeManagerFrame:IsShown() then securecall("HideUIPanel", EditModeManagerFrame) end
    end)
end

-- [ PERSISTENCE HOOKS ]------------------------------------------------------------------------------
if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        local PM = Orbit.Engine and Orbit.Engine.PositionManager
        if PM then PM:FlushToStorage() end
        if Orbit.AuraPreview then Orbit.AuraPreview:ReleaseIconProvider() end
    end, Orbit)
end
