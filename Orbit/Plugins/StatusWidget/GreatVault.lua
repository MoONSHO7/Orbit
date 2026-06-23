---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
-- The Great Vault flourish is two insecure EventToast display types (unlock / item upgrade).
local VAULT_TOAST_TYPES = {
    [Enum.EventToastDisplayType.WeeklyRewardUnlock] = true,
    [Enum.EventToastDisplayType.WeeklyRewardUpgrade] = true,
}
local UPGRADE_TYPE = Enum.EventToastDisplayType.WeeklyRewardUpgrade
-- Spell/ability learned rides the same EventToast queue (SingleLineWithIcon), keyed by eventType.
local SPELL_LEARNED = (Enum.EventToastEventType and Enum.EventToastEventType.SpellLearned) or 21

-- [ GREAT VAULT ]------------------------------------------------------------------------------------
function Plugin:SetupGreatVault()
    local mgr = EventToastManagerFrame
    if not mgr or mgr._orbitVaultHooked then return end
    if not (C_EventToastManager and C_EventToastManager.GetNextToastToDisplay and C_EventToastManager.RemoveCurrentToast) then
        return
    end
    mgr._orbitVaultHooked = true

    local plugin = self
    local orig = mgr.DisplayToast
    -- Display the front via orig(self, true) so it won't re-remove the toast we already advanced past.
    mgr.DisplayToast = function(frame, firstToast)
        local doVault = plugin:GetSetting(plugin.system, "ReplaceVaultToast")
        local doSpell = plugin:GetSetting(plugin.system, "ShowRewardToasts")
        if not (doVault or doSpell) then return orig(frame, firstToast) end
        if not firstToast then C_EventToastManager.RemoveCurrentToast() end
        local info = C_EventToastManager.GetNextToastToDisplay()
        while info and ((doVault and VAULT_TOAST_TYPES[info.displayType]) or (doSpell and info.eventType == SPELL_LEARNED)) do
            if VAULT_TOAST_TYPES[info.displayType] then
                -- info.subtitle is an item link for the Upgrade type; a FontString renders it as the item name.
                plugin:PlayVaultFlourish(info.title, info.subtitle, info.displayType == UPGRADE_TYPE)
            else
                plugin:PlayIconFlourish(info.iconFileID, plugin.FlourishColors.arcane, L.PLU_SB_V2_SPELL_F:format(info.title or ""))
            end
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
    Plugin:PlayVaultFlourish(L.PLU_SB_V2_VAULT_TEST, "")          -- unlock beat
    Plugin:PlayVaultFlourish(L.PLU_SB_V2_VAULT_TEST, "", true)    -- upgrade beat (keyhole flipbook)
end
