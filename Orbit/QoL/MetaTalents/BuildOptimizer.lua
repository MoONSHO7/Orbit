-- [ METATALENTS / BUILD OPTIMIZER ]-----------------------------------------------------------
-- Budget-aware greedy loadout algorithm. Scores every visible node by WCL pick rate,
-- sorts descending, then greedily fills within the per-currency point budget.
-- Produces three parallel results: the import entries array (fed to ImportLoadout), a
-- per-entryID "meta set" flag table (consumed by the tree overlay's red/green glow), and
-- a per-nodeID descriptor table used by the Apply button match check — the latter fixes
-- a tiered-node false-negative where all tier entryIDs ended up in metaSet but activeEntry
-- only ever holds one entry.

local _, Orbit = ...
local MT = Orbit.MetaTalents
local C = MT.Constants
local Data = MT.Data

local Build = {}
MT.Build = Build

-- [ INTERNAL CACHE ]--------------------------------------------------------------------------
local metaEntriesCache = nil
local metaSetCache = nil
local metaNodesCache = nil
local lastCacheKey = nil

function Build.Invalidate()
    metaEntriesCache = nil
    metaSetCache = nil
    metaNodesCache = nil
    lastCacheKey = nil
end

-- [ HERO BRANCH DETECTION ]-------------------------------------------------------------------
-- Only considers visible SubTreeSelection nodes so a sub-70 character never gets a
-- phantom activeSubTreeID set from WCL data for a hero tree they cannot access.
local function DetectActiveSubTreeID(configID, treeNodes, specData)
    for _, nodeID in ipairs(treeNodes) do
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.isVisible and info.type == Enum.TraitNodeType.SubTreeSelection and info.entryIDs then
            local bestEntry, bestRate = nil, 0
            for _, eID in ipairs(info.entryIDs) do
                local rate = specData[eID] or 0
                if rate > bestRate then bestEntry, bestRate = eID, rate end
            end
            if not bestEntry and info.activeEntry then bestEntry = info.activeEntry.entryID end
            if bestEntry then
                local eInfo = C_Traits.GetEntryInfo(configID, bestEntry)
                if eInfo and eInfo.subTreeID then return eInfo.subTreeID end
            end
        end
    end
    return nil
end

-- [ CANDIDATE SCORING ]-----------------------------------------------------------------------
local function ScoreCandidates(configID, treeNodes, specData, activeSubTreeID)
    local candidates = {}
    for _, nodeID in ipairs(treeNodes) do
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.entryIDs and #info.entryIDs > 0 and info.isVisible
            and not (info.subTreeID and activeSubTreeID and info.subTreeID ~= activeSubTreeID) then
            local bestEntry, bestRate = nil, 0
            for _, eID in ipairs(info.entryIDs) do
                local rate = specData[eID] or 0
                if rate > bestRate then bestEntry, bestRate = eID, rate end
            end
            if not bestEntry then bestEntry = info.entryIDs[1] end
            local isFree, costPerRank, currencyID = false, 0, nil
            local nodeCosts = C_Traits.GetNodeCost(configID, nodeID)
            if not nodeCosts or #nodeCosts == 0 or nodeCosts[1].amount == 0 then
                isFree = true
            elseif info.ranksPurchased == 0 and info.activeRank > 0 and (info.ranksIncreased or 0) == 0 then
                isFree = true
            else
                costPerRank = nodeCosts[1].amount
                currencyID = nodeCosts[1].ID
            end
            candidates[#candidates + 1] = {
                nodeID = nodeID, info = info,
                bestEntry = bestEntry, bestRate = bestRate,
                isFree = isFree, costPerRank = costPerRank, currencyID = currencyID,
                isHeroBranch = info.subTreeID and info.subTreeID == activeSubTreeID,
            }
        end
    end
    table.sort(candidates, function(a, b) return a.bestRate > b.bestRate end)
    return candidates
end

-- [ BUDGET SNAPSHOT ]-------------------------------------------------------------------------
-- Fixed: treat maxQuantity == 0 as a legitimate budget (e.g. hero currency pre-level-70).
-- The previous `ci.maxQuantity or (ci.quantity + ci.spent)` would substitute the fallback
-- on a falsy zero, which could disagree with the real max.
local function ReadBudgets(configID, treeID)
    local currencyInfo = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
    local budgets = {}
    for _, ci in ipairs(currencyInfo) do
        local max = ci.maxQuantity
        if max == nil then max = (ci.quantity or 0) + (ci.spent or 0) end
        budgets[ci.traitCurrencyID] = max
    end
    return budgets
end

-- [ IMPORT ENTRY BUILDER ]--------------------------------------------------------------------
-- metaNodes is keyed by nodeID with { entryID, ranks, tiered, choice } — one entry per
-- node. This is what UpdateApplyButtonState iterates, avoiding the tiered false-negative.
local function AddEntry(cand, configID, importEntries, metaSet, metaNodes)
    local info = cand.info
    local isChoice = info.type == Enum.TraitNodeType.Selection or info.type == Enum.TraitNodeType.SubTreeSelection
    local isTiered = info.type == Enum.TraitNodeType.Tiered
    local maxRanks = info.maxRanks or 1
    metaSet[cand.bestEntry] = true
    metaNodes[cand.nodeID] = { entryID = cand.bestEntry, ranks = maxRanks, tiered = isTiered, choice = isChoice }
    if isTiered then
        local remaining = maxRanks
        for _, eID in ipairs(info.entryIDs) do
            if remaining <= 0 then break end
            local eInfo = C_Traits.GetEntryInfo(configID, eID)
            local r = math.min(remaining, eInfo and eInfo.maxRanks or 1)
            importEntries[#importEntries + 1] = { nodeID = cand.nodeID, ranksGranted = 0, ranksPurchased = r, selectionEntryID = eID }
            metaSet[eID] = true
            remaining = remaining - r
        end
    elseif isChoice then
        importEntries[#importEntries + 1] = { nodeID = cand.nodeID, ranksGranted = 0, ranksPurchased = 1, selectionEntryID = cand.bestEntry }
    else
        importEntries[#importEntries + 1] = { nodeID = cand.nodeID, ranksGranted = 0, ranksPurchased = maxRanks, selectionEntryID = cand.bestEntry }
    end
end

-- [ GREEDY FILL ]-----------------------------------------------------------------------------
-- Fixed: hero branch nodes now share the budget-sufficiency gate used by paid nodes, so a
-- future data shape where hero and class trees share a currency can't overspend. Hero
-- nodes still bypass the MIN_PICK_RATE floor (they are prioritized) and still fall through
-- the paid path's "include when budget unknown" branch to preserve the always-include intent.
local function BuildOptimalEntries(configID, treeID, specData)
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    if not treeNodes then return {}, {}, {} end
    local activeSubTreeID = DetectActiveSubTreeID(configID, treeNodes, specData)
    local candidates = ScoreCandidates(configID, treeNodes, specData, activeSubTreeID)
    local budgets = ReadBudgets(configID, treeID)
    local importEntries, metaSet, metaNodes = {}, {}, {}

    for _, cand in ipairs(candidates) do
        if cand.bestEntry then
            if cand.isFree then
                AddEntry(cand, configID, importEntries, metaSet, metaNodes)
            else
                local isChoice = cand.info.type == Enum.TraitNodeType.Selection or cand.info.type == Enum.TraitNodeType.SubTreeSelection
                local purchaseRanks = isChoice and 1 or (cand.info.maxRanks or 1)
                local totalCost = cand.costPerRank * purchaseRanks
                local cID = cand.currencyID
                local include = false
                if not cID or not budgets[cID] then
                    include = cand.isHeroBranch
                elseif budgets[cID] >= totalCost then
                    if cand.isHeroBranch or cand.bestRate >= C.MIN_PICK_RATE then
                        include = true
                    end
                end
                if include then
                    if cID and budgets[cID] then budgets[cID] = budgets[cID] - totalCost end
                    AddEntry(cand, configID, importEntries, metaSet, metaNodes)
                end
            end
        end
    end
    return importEntries, metaSet, metaNodes
end

-- [ CACHED COMPUTE ]--------------------------------------------------------------------------
function Build.Compute()
    local specData = Data.UpdateActiveSpecData()
    if not specData then return nil, nil, nil end
    local currentKey = Data.GetActiveSpecDataKey()
    if metaEntriesCache and lastCacheKey == currentKey then
        return metaEntriesCache, metaSetCache, metaNodesCache
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil, nil, nil end
    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs or not configInfo.treeIDs[1] then return nil, nil, nil end
    metaEntriesCache, metaSetCache, metaNodesCache = BuildOptimalEntries(configID, configInfo.treeIDs[1], specData)
    lastCacheKey = currentKey
    return metaEntriesCache, metaSetCache, metaNodesCache
end

function Build.GetMetaSet()
    local _, metaSet = Build.Compute()
    return metaSet
end

function Build.GetMetaNodes()
    local _, _, metaNodes = Build.Compute()
    return metaNodes
end
