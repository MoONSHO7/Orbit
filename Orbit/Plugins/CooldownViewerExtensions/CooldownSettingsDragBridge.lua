-- [ COOLDOWN SETTINGS DRAG BRIDGE ] -----------------------------------------------------------------
-- Blizzard's CooldownViewerSettings icons use an internal reorder drag
-- (BeginOrderChange) that never populates the cursor, so GetCursorInfo returns
-- nil and the normal Orbit cursor-based drop path can't see them. This bridge
-- hooks the settings-item OnDragStart to stash a pending cooldownID, then on
-- GLOBAL_MOUSE_UP walks the mouse-focus stack for any Orbit frame that
-- declares :OnCooldownSettingsDrop(cooldownID). Blizzard's reorder UX is left
-- completely untouched — if the mouseup lands inside the settings panel,
-- nothing in the focus stack will match and the bridge quietly clears state
-- while BeginOrderChange handles its own commit.
local _, Orbit = ...

-- [ MODULE ] ----------------------------------------------------------------------------------------
Orbit.CooldownSettingsDragBridge = {}
local Bridge = Orbit.CooldownSettingsDragBridge

-- [ STATE ] -----------------------------------------------------------------------------------------
Bridge._pendingCooldownID = nil
Bridge._hooked = false

-- [ PUBLIC ACCESSOR ] -------------------------------------------------------------------------------
-- Consumers (e.g. a container's visibility ticker) can call this to mirror the
-- "is the cursor holding a cooldown" check used for drop-zone hints.
function Bridge:GetPendingCooldownID()
    return self._pendingCooldownID
end

function Bridge:IsPending()
    return self._pendingCooldownID ~= nil
end

-- [ HOOK INSTALLATION ] -----------------------------------------------------------------------------
-- Must be called after Blizzard_CooldownViewer is loaded. The extensions plugin
-- already owns that ADDON_LOADED hook; it calls Install() from there.
function Bridge:Install()
    if self._hooked then return end
    if not CooldownViewerSettingsItemMixin then return end
    self._hooked = true

    hooksecurefunc(CooldownViewerSettingsItemMixin, "OnDragStart", function(item)
        if item:IsEmptyCategory() then return end
        local cooldownID = item:GetCooldownID()
        if not cooldownID then return end
        Bridge._pendingCooldownID = cooldownID
    end)

    local f = CreateFrame("Frame")
    f:RegisterEvent("GLOBAL_MOUSE_UP")
    f:SetScript("OnEvent", function()
        local cooldownID = Bridge._pendingCooldownID
        if not cooldownID then return end
        Bridge._pendingCooldownID = nil
        Bridge:DispatchDrop(cooldownID)
    end)
    self._eventFrame = f
end

-- [ DROP DISPATCH ] ---------------------------------------------------------------------------------
-- Walks the current mouse-focus stack from innermost to outermost. First frame
-- that exposes OnCooldownSettingsDrop wins. Returning early on first match
-- mirrors Blizzard's own drop-target resolution.
function Bridge:DispatchDrop(cooldownID)
    local foci = GetMouseFoci and GetMouseFoci() or nil
    if not foci then return end
    for _, frame in ipairs(foci) do
        local handler = frame.OnCooldownSettingsDrop
        if type(handler) == "function" then
            handler(frame, cooldownID)
            return
        end
    end
end
