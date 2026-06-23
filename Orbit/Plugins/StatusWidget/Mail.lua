---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ MAIL ]-------------------------------------------------------------------------------------------
local function CollectSenders()
    if not GetLatestThreeSenders then return "" end
    local names = {}
    for _, name in ipairs({ GetLatestThreeSenders() }) do
        if name and name ~= "" then names[#names + 1] = name end
    end
    return table.concat(names, ", ")
end

function Plugin:SetupMail()
    Orbit.EventBus:On("UPDATE_PENDING_MAIL", function() self:OnMailUpdate() end, self)
    self._hadMail = HasNewMail and HasNewMail() or false
end

function Plugin:OnMailUpdate()
    local hasMail = HasNewMail and HasNewMail() or false
    if hasMail and not self._hadMail and self:GetSetting(self.system, "ShowMailToast") then
        local senders = CollectSenders()
        self:PlayMailFlourish(L.PLU_SB_V2_MAIL_NEW, senders ~= "" and L.PLU_SB_V2_MAIL_FROM_F:format(senders) or nil)
    end
    self._hadMail = hasMail
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
SLASH_ORBITMAIL1 = "/orbitmail"
SlashCmdList["ORBITMAIL"] = function()
    Plugin:PlayMailFlourish(L.PLU_SB_V2_MAIL_NEW, L.PLU_SB_V2_MAIL_FROM_F:format("Postmaster"))
end
