-- [ NPC AUTOMATION ]---------------------------------------------------------------------------------
-- Auto gossip / sell-junk / repair at NPCs. Events always registered; settings read at fire-time.
local _, Orbit = ...
local L = Orbit.L

Orbit.NpcAutomation = {}

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function GetAccountSetting(key, default)
    local v = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings[key]
    if v == nil then return default end
    return v
end

-- Status Widget renders the summary via an ORBIT_NPC_REPAIRED listener (it formats the cost); chat is the fallback when it's disabled. EventBus keeps QoL depending only on Core, never on the plugin.
local function ReportRepair(cost, fromGuild)
    if Orbit:IsPluginEnabled("Status Widget") then
        Orbit.EventBus:Fire("ORBIT_NPC_REPAIRED", cost)
        return
    end
    local source = fromGuild and L.PLU_NPC_REPAIR_GUILD or L.PLU_NPC_REPAIR_SELF
    Orbit:Print(L.MSG_NPC_REPAIRED_F:format(GetCoinTextureString(cost), source))
end

-- Guild funds only when they cover the full bill; otherwise own funds. Merchant interaction is out of combat, so these economy values are plain numbers.
local function DoAutoRepair()
    if not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end
    if CanGuildBankRepair() then
        local allowance = GetGuildBankWithdrawMoney()
        local guildMoney = GetGuildBankMoney()
        if allowance == -1 then allowance = guildMoney else allowance = math.min(allowance, guildMoney) end
        if allowance >= cost then
            RepairAllItems(true)
            ReportRepair(cost, true)
            return
        end
    end
    if GetMoney() < cost then return end
    RepairAllItems(false)
    ReportRepair(cost, false)
end

-- Skip the dialog only when the NPC offers exactly one gossip option and has no quests, so quest auto-handling is never bypassed.
local function DoAutoGossip()
    if #C_GossipInfo.GetAvailableQuests() > 0 or #C_GossipInfo.GetActiveQuests() > 0 then return end
    local options = C_GossipInfo.GetOptions()
    if #options == 1 and options[1].gossipOptionID then
        C_GossipInfo.SelectOption(options[1].gossipOptionID)
    end
end

-- [ EVENT HANDLER ]----------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("GOSSIP_SHOW")

frame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        if GetAccountSetting("AutoSellJunk", false) and C_MerchantFrame.GetNumJunkItems() > 0 then
            C_MerchantFrame.SellAllJunkItems()
        end
        if GetAccountSetting("AutoRepair", false) then
            DoAutoRepair()
        end
    elseif event == "GOSSIP_SHOW" then
        if GetAccountSetting("AutomateGossip", false) then
            DoAutoGossip()
        end
    end
end)
