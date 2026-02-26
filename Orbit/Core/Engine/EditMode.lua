-- [ ORBIT EDIT MODE ENGINE ]-----------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.EditMode = Engine.EditMode or {}
local EditMode = Engine.EditMode

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local EDIT_MODE_POSITION_X = 20
local EDIT_MODE_POSITION_Y = 20

-- [ API ]-------------------------------------------------------------------------------------------

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

-- [ COMBAT SAFETY: AUTO-EXIT EDIT MODE ]-----------------------------------------------------------

if EditModeManagerFrame then
    local combatExitFrame = CreateFrame("Frame")
    combatExitFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatExitFrame:SetScript("OnEvent", function()
        if EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
    end)
end

-- [ PERSISTENCE HOOKS ]-----------------------------------------------------------------------------

if EditModeManagerFrame then
    hooksecurefunc(EditModeManagerFrame, "Show", function(self)
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", EDIT_MODE_POSITION_X, EDIT_MODE_POSITION_Y)
    end)

    hooksecurefunc(EditModeManagerFrame, "OnHide", function()
        local PM = Orbit.Engine and Orbit.Engine.PositionManager
        if PM then PM:FlushToStorage() end
    end)
end
