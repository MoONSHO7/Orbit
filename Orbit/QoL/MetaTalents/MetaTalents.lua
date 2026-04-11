-- [ METATALENTS / ORCHESTRATOR ]----------------------------------------------------------------
-- Public entry point for the MetaTalents feature. Loads the LoD data addon, binds it into the
-- Data module, then chains the Blizzard_SharedTalentUI and Blizzard_PlayerSpells load hooks
-- in the same order as the original monolith. All feature logic lives in sibling modules —
-- this file is just lifecycle, wiring, and the auto-enable-on-login flow.

local _, Orbit = ...
local L = Orbit.L
local MT = Orbit.MetaTalents
local C = MT.Constants
local Data = MT.Data
local Overlay = MT.Overlay
local Apply = MT.Apply
local Dropdowns = MT.Dropdowns
local CastBarSkin = MT.CastBarSkin
local Layout = MT.TreeLayout

-- [ TALENT TREE HOOK PIPELINE ]----------------------------------------------------------------
local function HookTalentTree()
    if MT._hooked then return end
    EventUtil.ContinueOnAddOnLoaded("Blizzard_SharedTalentUI", function()
        if MT._hooked then return end
        MT._hooked = true

        hooksecurefunc(TalentButtonArtMixin, "UpdateStateBorder", Overlay.ApplyHeatmap)

        EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", function()
            if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame then
                hooksecurefunc(PlayerSpellsFrame.TalentsFrame, "UpdateTreeCurrencyInfo", function()
                    for button in PlayerSpellsFrame.TalentsFrame:EnumerateAllTalentButtons() do
                        Overlay.ApplyHeatmap(button)
                    end
                end)
            end

            CastBarSkin.Apply()
        end)

        Layout.HookSpendText()
        Dropdowns.Setup()
        Layout.HookApplyPosition(Dropdowns.Setup)
        Layout.HookCapstoneTrack()
    end)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------
function MT:Enable()
    if self._active then return end
    C_AddOns.EnableAddOn(C.LOD_ADDON)
    local loaded, reason = C_AddOns.LoadAddOn(C.LOD_ADDON)
    if not loaded then
        print("|cffff0000[Orbit]|r " .. L.MSG_META_DATA_MISSING_F:format(tostring(reason)))
        return
    end
    local talentData = Orbit.Data and Orbit.Data.TalentMeta
    if not talentData then
        print("|cffff0000[Orbit]|r " .. L.MSG_META_EMPTY)
        return
    end
    Data.SetSource(talentData)
    Data.RefreshPlayerKeys()
    self._active = true
    Overlay.HookTooltips()
    HookTalentTree()
end

function MT:Disable()
    self._active = false
    C_AddOns.DisableAddOn(C.LOD_ADDON)
end

-- [ AUTO-ENABLE ON LOGIN ]---------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(C.LOGIN_DELAY, function()
        local db = Orbit.db and Orbit.db.AccountSettings
        if db and (db.MetaTalentsTooltip or db.MetaTalentsTree) then
            MT:Enable()
        else
            C_AddOns.DisableAddOn(C.LOD_ADDON)
        end
    end)
    loader:UnregisterAllEvents()
end)
