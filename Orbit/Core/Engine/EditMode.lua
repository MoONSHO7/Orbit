-- [ ORBIT EDIT MODE ENGINE ]-----------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.EditMode = Engine.EditMode or {}
local EditMode = Engine.EditMode

-- [ GUARD AND DEFER LOGIC ]------------------------------------------------------------------------

local function GuardAndDefer(callback)
    if InCombatLockdown() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(s)
            s:UnregisterAllEvents()
            callback()
        end)
    else
        callback()
    end
end

-- [ API ]-------------------------------------------------------------------------------------------

function EditMode:RegisterEnterCallback(callback, owner)
    if not EventRegistry then
        return
    end

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        GuardAndDefer(callback)
    end, owner)
end

function EditMode:RegisterExitCallback(callback, owner)
    if not EventRegistry then
        return
    end

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        GuardAndDefer(callback)
    end, owner)
end

function EditMode:RegisterCallbacks(callbacks, owner)
    if not EventRegistry then
        return
    end

    if callbacks.Enter then
        self:RegisterEnterCallback(callbacks.Enter, owner)
    end

    if callbacks.Exit then
        self:RegisterExitCallback(callbacks.Exit, owner)
    end
end

-- [ COMBAT SAFETY: AUTO-EXIT EDIT MODE ]-----------------------------------------------------------
-- If combat starts while Edit Mode is active, immediately exit to restore functional UI.
-- This prevents the "freeze" where previews persist and real frames are hidden.

if EditModeManagerFrame then
    local combatExitFrame = CreateFrame("Frame")
    combatExitFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatExitFrame:SetScript("OnEvent", function()
        if EditModeManagerFrame:IsShown() then
            HideUIPanel(EditModeManagerFrame)
        end
    end)
end

-- [ PERSISTENCE HOOKS ]-----------------------------------------------------------------------------

if EditModeManagerFrame then
    -- Anchor HUD Edit Mode window to bottom left
    hooksecurefunc(EditModeManagerFrame, "Show", function(self)
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 20)
    end)

    hooksecurefunc(EditModeManagerFrame, "OnHide", function()
        -- Commit ephemeral positions to SavedVariables on exit
        -- NOTE: We resolve PositionManager at RUNTIME, not at hook registration time,
        -- because PositionManager.lua loads after EditMode.lua in the TOC.
        local PM = Orbit.Engine and Orbit.Engine.PositionManager
        if PM then
            PM:FlushToStorage()
        end
    end)
end
