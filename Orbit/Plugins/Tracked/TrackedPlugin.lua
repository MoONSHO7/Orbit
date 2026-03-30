-- [ ORBIT TRACKED ABILITIES & BARS PLUGIN ] -----------------------------------
local _, Orbit = ...

local Constants = Orbit.Constants
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- [ CONSTANTS ] ---------------------------------------------------------------
local TRACKED = Constants.Tracked.SystemIndex.Tracked
local TRACKED_BAR = Constants.Tracked.SystemIndex.TrackedBar

-- [ SPEC-SCOPED KEYS ] --------------------------------------------------------
local SPEC_SCOPED_KEYS = {
    ["TrackedItems"] = true,
    ["TrackedBarSpell"] = true,
    ["TrackedBarChildren"] = true,
    ["Position"] = true,
    ["Anchor"] = true,
}
local function IsSpecScopedIndex(sysIdx)
    if sysIdx >= Constants.Tracked.SystemIndex.Tracked and sysIdx <= (Constants.Tracked.SystemIndex.Tracked + Constants.Tracked.MaxChildFrames - 1) then
        return true
    end
    if sysIdx >= Constants.Tracked.SystemIndex.TrackedBar and sysIdx <= (Constants.Tracked.SystemIndex.TrackedBar + Constants.Tracked.MaxBarChildren - 1) then
        return true
    end
    return false
end

local Plugin = Orbit:RegisterPlugin("Tracked Items", "Orbit_Tracked", {
    liveToggle = true,
    canvasMode = true,
    viewerMap = {},
    IsSpecScopedIndex = function(self, sysIdx) return IsSpecScopedIndex(sysIdx) end,
    GetDefaultSettings = function()
        return {
            [TRACKED] = {
                Dimensions = { x = 40, y = 40 },
                IconSize = Constants.Cooldown.DefaultIconSize,
                IconPadding = Constants.Cooldown.DefaultPadding,
                Anchor = { target = "OrbitPlayerResources", edge = "BOTTOM", padding = 4, align = "CENTER" },
            },
            [TRACKED_BAR] = {
                Dimensions = { x = 120, y = 12 },
                Anchor = { target = "Orbit_Tracked", edge = "BOTTOM", padding = 4, align = "CENTER" },
            }
        }
    end,
    OnLoad = function(self)
        self:MigrateLegacyProfileData()
        self:SeedAllSpecSpatialData()
        self._lastSpecID = self:GetCurrentSpecID()
        self:SetupTrackedFrame()
        self:SetupTrackedBarFrame()
        self:SetupEditModeHooks()

        self.ApplyAllDebounce = (Orbit.Constants and Orbit.Constants.Timing and Orbit.Constants.Timing.DefaultDebounce) or 0.1

        Orbit.EventBus:On("ORBIT_PROFILE_CHANGED", function()
            local newSpec = self:GetCurrentSpecID()
            if self._lastSpecID and self._lastSpecID ~= newSpec then
                self:FlushTrackedSpatial(self._lastSpecID)
            end
            self._lastSpecID = newSpec
            self:SetupTrackedFrame()
            self:SetupTrackedBarFrame()
            self:ReloadTrackedForSpec()
            self:ApplyAll()
        end, self)

        Orbit.EventBus:On("PLAYER_SPECIALIZATION_CHANGED", function()
            local newSpec = self:GetCurrentSpecID()
            if self._lastSpecID == newSpec then
                return
            end
            self:FlushTrackedSpatial(self._lastSpecID)
            self._lastSpecID = newSpec
            self:SetupTrackedFrame()
            self:SetupTrackedBarFrame()
            self:ReloadTrackedForSpec()
            self:ApplyAll()
        end, self)
    end,
    ApplyAll = function(self)
        if self.trackedAnchor then self:ApplySettings(self.trackedAnchor) end
        for _, child in pairs(self.activeChildren or {}) do
            if child.frame then self:ApplySettings(child.frame) end
        end
        if self.TrackedBarAnchor then self:ApplySettings(self.TrackedBarAnchor) end
        for _, child in pairs(self.activeTrackedBarChildren or {}) do
            if child.frame then self:ApplySettings(child.frame) end
        end
    end,
    ApplySettings = function(self, frame)
        if not frame then
            self:ApplyAll()
            return
        end
        if InCombatLockdown() then return end
        if (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player")) then
            frame:Hide()
            return
        end
        
        if frame.isTrackedIcon then
            self:ApplyTrackedSettings(frame)
            return
        end
        if frame.isTrackedBarFrame then
            self:ApplyTrackedBarSettings(frame)
            return
        end
    end,
    UpdateLayout = function(self, frame)
        if not frame or not frame.systemIndex then return end
        if frame.isTrackedIcon then
            self:LayoutTrackedIcons(frame, frame.systemIndex)
        end
        if frame.isTrackedBarFrame then
            Orbit.TrackedBarLayout:LayoutTrackedBars(self)
        end
    end,
    UpdateVisuals = function(self, frame)
        if frame then self:ApplySettings(frame) end
    end,
    MigrateLegacyProfileData = function(self)
        local profiles = Orbit.db and Orbit.db.Profiles or {}
        
        -- Run migration ONCE globally via a flag
        if Orbit.db.GlobalSettings.TrackedMigrationComplete then return end
        Orbit.db.GlobalSettings.TrackedMigrationComplete = true

        -- Migrate data strictly across ALL profiles safely
        for pKey, pData in pairs(profiles) do
            local oldData = pData["Orbit_CooldownViewer"]
            if oldData then
                local newData = pData["Orbit_Tracked"] or {}
                local migratedAny = false
                
                -- Migrate Tracked System Indices
                local indicesToMigrate = {}
                indicesToMigrate[Constants.Tracked.SystemIndex.Tracked] = true
                for i = 0, Constants.Tracked.MaxChildFrames - 1 do
                    indicesToMigrate[Constants.Tracked.SystemIndex.Tracked_ChildStart + i] = true
                end
                indicesToMigrate[Constants.Tracked.SystemIndex.TrackedBar] = true
                for i = 0, Constants.Tracked.MaxBarChildren - 1 do
                    indicesToMigrate[Constants.Tracked.SystemIndex.TrackedBar_ChildStart + i] = true
                end

                for idx, _ in pairs(indicesToMigrate) do
                    if oldData[idx] ~= nil then
                        newData[idx] = Orbit.Engine.Utils:DeepCopy(oldData[idx])
                        oldData[idx] = nil -- Clean up legacy node
                        migratedAny = true
                    end
                end
                
                if migratedAny then
                    pData["Orbit_Tracked"] = newData
                end
            end
        end
        
        -- Migrate SpecData (Tracked Items / ChargeBars)
        if Orbit.db.SpecData then
            for specID, data in pairs(Orbit.db.SpecData) do
                if type(data) == "table" then
                    for systemIndex, v in pairs(data) do
                        if type(v) == "table" then
                            -- Migrate legacy ChargeBar keys
                            if v.ChargeSpell then
                                v.TrackedBarSpell = v.ChargeSpell
                                v.ChargeSpell = nil
                            end
                            if v.ChargeChildren then
                                v.TrackedBarChildren = v.ChargeChildren
                                v.ChargeChildren = nil
                            end
                        end
                    end
                end
            end
        end
    end,
})

function Plugin:GetGrowthDirection()
    return "DOWN"
end

function Plugin:GetBaseFontSize()
    return 12
end

function Plugin:GetGlobalFont()
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    if fontName and LSM then
        return LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    end
    return STANDARD_TEXT_FONT
end

function Plugin:GetComponentPositions(systemIndex)
    return self:GetSetting(systemIndex, "ComponentPositions") or {}
end

function Plugin:IsComponentDisabled(componentKey, systemIndex)
    systemIndex = systemIndex or 1
    local Txn = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode.Transaction
    local disabled = (Txn and Txn:IsActive() and Txn:GetPlugin() == self) and Txn:GetDisabledComponents() or self:GetSetting(systemIndex, "DisabledComponents") or {}
    for _, key in ipairs(disabled) do
        if key == componentKey then return true end
    end
    return false
end

function Plugin:GetCurrentSpecID()
    local specIndex = GetSpecialization()
    return specIndex and GetSpecializationInfo(specIndex)
end

function Plugin:FlushTrackedSpatial(specID)
    if not specID or not Orbit.Engine.PositionManager then return end
    if not Orbit.db.SpecData then Orbit.db.SpecData = {} end
    if not Orbit.db.SpecData[specID] then Orbit.db.SpecData[specID] = {} end
    local function Flush(frame, systemIndex)
        if not frame then return end
        local pos = Orbit.Engine.PositionManager:GetPosition(frame)
        local anch = Orbit.Engine.PositionManager:GetAnchor(frame)
        if not Orbit.db.SpecData[specID][systemIndex] then Orbit.db.SpecData[specID][systemIndex] = {} end
        if anch and anch.target then
            Orbit.db.SpecData[specID][systemIndex]["Anchor"] = anch
            Orbit.db.SpecData[specID][systemIndex]["Position"] = nil
        elseif pos and pos.point then
            Orbit.db.SpecData[specID][systemIndex]["Position"] = pos
            Orbit.db.SpecData[specID][systemIndex]["Anchor"] = false
        end
        Orbit.Engine.PositionManager:ClearFrame(frame)
    end
    if self.trackedAnchor then Flush(self.trackedAnchor, TRACKED) end
    for _, childData in pairs(self.activeChildren or {}) do
        if childData.frame then Flush(childData.frame, childData.frame.systemIndex) end
    end
    if self.TrackedBarAnchor then Flush(self.TrackedBarAnchor, TRACKED_BAR) end
    for _, childData in pairs(self.activeTrackedBarChildren or {}) do
        if childData.frame then Flush(childData.frame, childData.frame.systemIndex) end
    end
end

function Plugin:GetSpecData(systemIndex, key)
    local specID = self:GetCurrentSpecID()
    if not specID then return nil end
    local specStore = Orbit.db.SpecData and Orbit.db.SpecData[specID]
    if not specStore then return nil end
    local node = specStore[systemIndex]
    return node and node[key]
end

function Plugin:SetSpecData(systemIndex, key, value)
    local specID = self:GetCurrentSpecID()
    if not specID then return end
    if not Orbit.db.SpecData then Orbit.db.SpecData = {} end
    if not Orbit.db.SpecData[specID] then Orbit.db.SpecData[specID] = {} end
    if not Orbit.db.SpecData[specID][systemIndex] then Orbit.db.SpecData[specID][systemIndex] = {} end
    Orbit.db.SpecData[specID][systemIndex][key] = value
end

-- [ SEED SPEC SPATIAL DATA ] ----------------------------------------------------
function Plugin:SeedAllSpecSpatialData()
    local numSpecs = GetNumSpecializations()
    if not numSpecs or numSpecs == 0 then return end
    if not Orbit.db.SpecData then Orbit.db.SpecData = {} end
    
    local indices = { TRACKED }
    for s = 0, Constants.Tracked.MaxChildFrames - 1 do
        table.insert(indices, Constants.Tracked.SystemIndex.Tracked_ChildStart + s)
    end
    table.insert(indices, TRACKED_BAR)
    for s = 0, Constants.Tracked.MaxBarChildren - 1 do
        table.insert(indices, Constants.Tracked.SystemIndex.TrackedBar_ChildStart + s)
    end
    
    for i = 1, numSpecs do
        local specID = GetSpecializationInfo(i)
        if specID then
            if not Orbit.db.SpecData[specID] then Orbit.db.SpecData[specID] = {} end
            for _, sysIdx in ipairs(indices) do
                if not Orbit.db.SpecData[specID][sysIdx] then Orbit.db.SpecData[specID][sysIdx] = {} end
            end
        end
    end
end

-- [ HELPER ALIASES ] ------------------------------------------------------------
local OriginalGetSetting = Orbit.PluginMixin.GetSetting
local OriginalSetSetting = Orbit.PluginMixin.SetSetting

function Plugin:GetSetting(systemIndex, key)
    if IsSpecScopedIndex(systemIndex) and SPEC_SCOPED_KEYS[key] then
        local specVal = self:GetSpecData(systemIndex, key)
        if specVal ~= nil then return specVal end
        
        -- Prevent legacy global-profile garbage from filling empty specs
        if key == "TrackedBarSpell" or key == "TrackedItems" or key == "TrackedBarChildren" then
            return nil
        end
    end
    return OriginalGetSetting(self, systemIndex, key)
end

function Plugin:SetSetting(systemIndex, key, value)
    if IsSpecScopedIndex(systemIndex) and SPEC_SCOPED_KEYS[key] then
        self:SetSpecData(systemIndex, key, value)
        return
    end
    OriginalSetSetting(self, systemIndex, key, value)
end
