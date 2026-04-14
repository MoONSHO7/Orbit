-- [ METATALENTS / DATA SOURCE ]---------------------------------------------------------------
-- Owns the WCL dataset binding, class/spec key cache, per-content/difficulty spec data
-- routing, and the spell-id reverse cache for the tooltip hook. All cross-file access
-- to the LoD dataset goes through this module.

local _, Orbit = ...
local MT = Orbit.MetaTalents
local C = MT.Constants

local Data = {}
MT.Data = Data

-- [ INTERNAL STATE ]--------------------------------------------------------------------------
local talentData = nil
local cachedClassKey, cachedSpecKey = nil, nil
local activeSpecData, activeSpecDataKey = nil, nil
local spellToPickRate = {}
local spellCacheDirty = true

-- [ SOURCE BINDING ]--------------------------------------------------------------------------
function Data.SetSource(src)
    talentData = src
    activeSpecData = nil
    activeSpecDataKey = nil
    spellCacheDirty = true
end

function Data.HasSource()
    return talentData ~= nil
end

-- [ PLAYER KEYS ]-----------------------------------------------------------------------------
function Data.RefreshPlayerKeys()
    local _, classFile = UnitClass("player")
    local specIndex = GetSpecialization()
    if not specIndex or not classFile then
        cachedClassKey, cachedSpecKey = nil, nil
        return
    end
    local _, specName = GetSpecializationInfo(specIndex)
    if not specName then
        cachedClassKey, cachedSpecKey = nil, nil
        return
    end
    cachedClassKey = string.lower(classFile)
    cachedSpecKey = string.lower(specName):gsub(" ", "")
end

function Data.GetClassKey() return cachedClassKey end
function Data.GetSpecKey() return cachedSpecKey end

-- [ ACTIVE SPEC DATA ]------------------------------------------------------------------------
function Data.UpdateActiveSpecData()
    if not talentData or not cachedClassKey or not cachedSpecKey then
        if activeSpecData then
            activeSpecData = nil
            activeSpecDataKey = nil
            spellCacheDirty = true
        end
        return nil
    end
    local content = MT.SelectedContent or C.DEFAULT_CONTENT
    local difficulty = MT.SelectedDifficulty or C.DEFAULT_DIFFICULTY
    local key = cachedClassKey .. "_" .. cachedSpecKey .. "_" .. content .. "_" .. difficulty
    if activeSpecDataKey == key then return activeSpecData end
    local contentData = talentData[content]
    local diffData = contentData and contentData[difficulty]
    local classData = diffData and diffData[cachedClassKey]
    activeSpecData = classData and classData[cachedSpecKey]
    activeSpecDataKey = key
    spellCacheDirty = true
    return activeSpecData
end

function Data.GetActiveSpecDataKey() return activeSpecDataKey end

function Data.LookupPickRate(entryID)
    if not cachedClassKey then Data.RefreshPlayerKeys() end
    local specData = Data.UpdateActiveSpecData()
    if not specData then return nil end
    return specData[entryID] or 0
end

-- [ SPELL ID REVERSE CACHE ]------------------------------------------------------------------
function Data.MarkSpellCacheDirty()
    spellCacheDirty = true
end

function Data.RebuildSpellCache()
    wipe(spellToPickRate)
    spellCacheDirty = false
    local specData = Data.UpdateActiveSpecData()
    if not specData then return end
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return end
    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs or not configInfo.treeIDs[1] then return end
    local nodes = C_Traits.GetTreeNodes(configInfo.treeIDs[1])
    if not nodes then return end
    for _, nodeID in ipairs(nodes) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.entryIDs then
            for _, entryID in ipairs(nodeInfo.entryIDs) do
                local pct = specData[entryID]
                if pct then
                    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                    if entryInfo and entryInfo.definitionID then
                        local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                        if defInfo and defInfo.spellID then
                            spellToPickRate[defInfo.spellID] = pct
                        end
                    end
                end
            end
        end
    end
end

function Data.GetSpellPickRate(spellID)
    if spellCacheDirty then Data.RebuildSpellCache() end
    return spellToPickRate[spellID]
end

-- [ SPEC WATCHER ]----------------------------------------------------------------------------
-- Fixed: PLAYER_ENTERING_WORLD's first arg is isInitialLogin (boolean), not a unit token.
-- The previous unified handler checked `unit == "player" or unit == nil` which never
-- matched for PLAYER_ENTERING_WORLD. Now we dispatch on the event name.
local specWatcher = CreateFrame("Frame")
specWatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
specWatcher:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 ~= "player" then return end
    Data.RefreshPlayerKeys()
    spellCacheDirty = true
    if MT.Build then MT.Build.Invalidate() end
end)
