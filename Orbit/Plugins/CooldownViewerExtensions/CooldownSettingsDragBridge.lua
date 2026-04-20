-- [ COOLDOWN SETTINGS DRAG BRIDGE ] -----------------------------------------------------------------
local _, Orbit = ...

Orbit.CooldownSettingsDragBridge = {}
local Bridge = Orbit.CooldownSettingsDragBridge

-- Tooltip read + GLOBAL_MOUSE_* events deliberately avoid hooksecurefunc on CooldownViewerSettingsItemMixin, which taints every panel item and propagates into CDM viewer children.
function Bridge:Install()
    if self._installed then return end
    self._installed = true

    GameTooltip:HookScript("OnUpdate", function(tt)
        local _, sid = tt:GetSpell()
        if sid then Bridge._lastTooltipSpellID = sid end
    end)
    GameTooltip:HookScript("OnHide", function() Bridge._lastTooltipSpellID = nil end)

    local f = CreateFrame("Frame")
    f:RegisterEvent("GLOBAL_MOUSE_DOWN")
    f:RegisterEvent("GLOBAL_MOUSE_UP")
    f:SetScript("OnEvent", function(_, event, button)
        if event == "GLOBAL_MOUSE_DOWN" then
            if button ~= "LeftButton" then return end
            if not CooldownViewerSettings or not CooldownViewerSettings:IsShown() then return end
            local sid = Bridge._lastTooltipSpellID
            if not sid then return end
            local p = GameTooltip:GetOwner()
            while p do
                if p == CooldownViewerSettings then Bridge._pendingSpellID = sid; return end
                p = p:GetParent()
            end
        else
            local sid = Bridge._pendingSpellID
            Bridge._pendingSpellID = nil
            if not sid then return end
            local foci = GetMouseFoci and GetMouseFoci()
            if not foci then return end
            for _, frame in ipairs(foci) do
                local handler = frame.OnCooldownSettingsDrop
                if type(handler) == "function" then handler(frame, sid); return end
            end
        end
    end)
end
