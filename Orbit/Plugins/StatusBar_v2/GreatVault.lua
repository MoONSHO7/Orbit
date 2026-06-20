---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Bar v2")

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
-- The Great Vault flourish is two insecure EventToast display types (unlock / item upgrade).
local VAULT_TOAST_TYPES = {
    [Enum.EventToastDisplayType.WeeklyRewardUnlock] = true,
    [Enum.EventToastDisplayType.WeeklyRewardUpgrade] = true,
}

-- [ GREAT VAULT ]------------------------------------------------------------------------------------
-- Replace Blizzard's Great Vault toast with our own center flourish. We drain the vault toasts off the
-- EventToastManager queue before they animate; every other toast (level-up, scenario, M+) passes through.
function Plugin:SetupGreatVault()
    local mgr = EventToastManagerFrame
    if not mgr or mgr._orbitVaultHooked then return end
    if not (C_EventToastManager and C_EventToastManager.GetNextToastToDisplay and C_EventToastManager.RemoveCurrentToast) then
        return
    end
    mgr._orbitVaultHooked = true

    local plugin = self
    local orig = mgr.DisplayToast
    -- Replace the insecure instance method: when enabled, replicate orig's advance-remove, drain any
    -- vault toasts (firing our flourish), then display the front via orig(self, true) so it won't re-remove.
    mgr.DisplayToast = function(frame, firstToast)
        if not plugin:GetSetting(plugin.system, "ReplaceVaultToast") then
            return orig(frame, firstToast)
        end
        if not firstToast then C_EventToastManager.RemoveCurrentToast() end
        local info = C_EventToastManager.GetNextToastToDisplay()
        while info and VAULT_TOAST_TYPES[info.displayType] do
            -- info.subtitle is an item link for the Upgrade type; a FontString renders it as the item name.
            plugin:PlayVaultFlourish(info.title, info.subtitle)
            C_EventToastManager.RemoveCurrentToast()
            info = C_EventToastManager.GetNextToastToDisplay()
        end
        return orig(frame, true)
    end
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
-- Dev affordance: fire the flourish on demand with representative text.
SLASH_ORBITVAULT1 = "/orbitvault"
SlashCmdList["ORBITVAULT"] = function()
    Plugin:PlayVaultFlourish(L.PLU_SB_V2_VAULT_TEST, "")
end
