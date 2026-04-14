-- [ METATALENTS / APPLY BUILD ]----------------------------------------------------------------
-- Owns the "Apply Orbit Loadout" button: the import action itself, the match-state evaluator
-- that drives the pressed/desaturated look, and the debounced event watcher that keeps it in
-- sync with config changes. Two non-obvious fixes live here:
--  1. Level gate (MIN_APPLY_LEVEL): importing a full loadout under level 81 is meaningless —
--     hero trees aren't unlocked, the capstone row isn't available, and the greedy fill would
--     overshoot the real point budget. Below 81 the button reads "Level 81+" and is disabled.
--  2. Tiered-node match check: we iterate Build.GetMetaNodes() (one descriptor per nodeID)
--     instead of walking metaSet by entryID. Tiered nodes put *every* tier entryID in metaSet
--     but only one entryID is ever the live activeEntry, so the old entry-walker would always
--     report "not matched" for any tiered node and leave the button perpetually enabled.

local _, Orbit = ...
local L = Orbit.L
local MT = Orbit.MetaTalents
local C = MT.Constants
local Data = MT.Data
local Build = MT.Build

local DISABLED_ALPHA = 0.4

local Apply = {}
MT.Apply = Apply

local STATE_DEBOUNCE = C.STATE_DEBOUNCE

-- [ APPLY META BUILD ]-------------------------------------------------------------------------
function Apply.ApplyMetaBuild()
    if UnitLevel("player") < C.MIN_APPLY_LEVEL then
        print("|cffff0000[Orbit]|r " .. L.MSG_META_APPLY_LEVEL_F:format(C.MIN_APPLY_LEVEL))
        return
    end
    if not Data.HasSource() then return end
    if not Data.GetClassKey() then Data.RefreshPlayerKeys() end
    if not Data.GetClassKey() or not Data.GetSpecKey() then return end
    local specData = Data.UpdateActiveSpecData()
    if not specData then
        print("|cffff0000[Orbit]|r " .. L.MSG_META_NO_DATA)
        return
    end

    local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talentsFrame then return end

    local configID = talentsFrame:GetConfigID()
    local treeInfo = talentsFrame:GetTreeInfo()
    if not configID or not treeInfo then return end

    local entries = Build.Compute()
    if not entries or #entries == 0 then
        print("|cffff0000[Orbit]|r " .. L.MSG_META_NO_NODES)
        return
    end

    local specID = PlayerUtil.GetCurrentSpecID()
    local oldMetaIDs, oldMetaSet = {}, {}
    local existingIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if existingIDs then
        for _, id in ipairs(existingIDs) do
            local cInfo = C_Traits.GetConfigInfo(id)
            if cInfo and cInfo.name == C.CONFIG_NAME then
                oldMetaIDs[#oldMetaIDs + 1] = id
                oldMetaSet[id] = true
            end
        end
    end

    local success, errorString = C_ClassTalents.ImportLoadout(configID, entries, C.CONFIG_NAME)
    if not success then
        print("|cffff0000[Orbit]|r " .. L.MSG_META_IMPORT_FAILED_F:format(tostring(errorString)))
        return
    end

    talentsFrame:OnTraitConfigCreateStarted(true)
    local newConfigIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if newConfigIDs then
        for _, id in ipairs(newConfigIDs) do
            local cInfo = C_Traits.GetConfigInfo(id)
            if cInfo and cInfo.name == C.CONFIG_NAME and not oldMetaSet[id] then
                C_ClassTalents.SetUsesSharedActionBars(id, true)
                talentsFrame:SetSelectedSavedConfigID(id, true)
                break
            end
        end
    end
    for _, oldID in ipairs(oldMetaIDs) do
        C_ClassTalents.DeleteConfig(oldID)
    end
    print("|cff00ff00[Orbit]|r " .. L.MSG_META_APPLIED)
end

-- [ APPLY BUTTON MATCH STATE ]-----------------------------------------------------------------
-- Iterates Build.GetMetaNodes() keyed by nodeID — one descriptor per node — so tiered nodes
-- get exactly one match check instead of one per tier entry. The live config is "matched"
-- only when every meta node's activeEntry/activeRank agrees with the descriptor.
local lastMatchState = nil

local function EvaluateMatch(configID, metaNodes)
    for nodeID, desc in pairs(metaNodes) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if not nodeInfo then return false end
        if desc.tiered then
            if (nodeInfo.activeRank or 0) < (desc.ranks or 1) then return false end
        else
            local activeEntry = nodeInfo.activeEntry
            if not activeEntry or activeEntry.entryID ~= desc.entryID then return false end
            if (nodeInfo.activeRank or 0) < 1 then return false end
        end
    end
    return true
end

function Apply.UpdateApplyButtonState()
    local btn = MT._applyBtn
    if not btn then return end

    if UnitLevel("player") < C.MIN_APPLY_LEVEL then
        if btn._belowLevel then return end
        btn._belowLevel = true
        btn._isApplied = false
        lastMatchState = nil
        local tex = btn:GetNormalTexture()
        if tex then tex:SetDesaturated(true) end
        btn:SetAlpha(DISABLED_ALPHA)
        return
    end
    if btn._belowLevel then
        btn._belowLevel = false
        lastMatchState = nil
    end

    if not Data.HasSource() then return end
    if not Data.GetClassKey() then Data.RefreshPlayerKeys() end
    local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talentsFrame then return end
    local configID = talentsFrame:GetConfigID()
    local treeInfo = talentsFrame:GetTreeInfo()
    if not configID or not treeInfo then return end

    local metaNodes = Build.GetMetaNodes()
    if not metaNodes or not next(metaNodes) then return end

    local allMatch = EvaluateMatch(configID, metaNodes)
    if lastMatchState == allMatch then return end
    lastMatchState = allMatch
    btn._isApplied = allMatch
    local tex = btn:GetNormalTexture()
    if tex then tex:SetDesaturated(allMatch) end
    btn:SetAlpha(allMatch and 0.4 or 1.0)
end

-- Compatibility alias — Dropdowns.RefreshMetaUI and legacy callers use this entry point.
MT.UpdateApplyButtonState = Apply.UpdateApplyButtonState

-- [ STATE WATCHER ]----------------------------------------------------------------------------
-- Debounced so that a burst of TRAIT_CONFIG_* events coalesces into a single state pass.
-- PLAYER_LEVEL_UP is registered so the below-level branch flips to enabled the moment the
-- player dings 81, without requiring a talent frame reopen.
local pendingUpdate = false
local stateWatcher = CreateFrame("Frame")
stateWatcher:RegisterEvent("TRAIT_CONFIG_CREATED")
stateWatcher:RegisterEvent("TRAIT_CONFIG_DELETED")
stateWatcher:RegisterEvent("TRAIT_CONFIG_UPDATED")
stateWatcher:RegisterEvent("SELECTED_LOADOUT_CHANGED")
stateWatcher:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
stateWatcher:RegisterEvent("PLAYER_LEVEL_UP")
stateWatcher:SetScript("OnEvent", function()
    if pendingUpdate then return end
    pendingUpdate = true
    C_Timer.After(STATE_DEBOUNCE, function()
        pendingUpdate = false
        Apply.UpdateApplyButtonState()
    end)
end)
