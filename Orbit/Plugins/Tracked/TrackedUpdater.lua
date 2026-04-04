---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils
local LCG = LibStub("LibOrbitGlow-1.0", true)
local ACTIVE_GLOW_KEY = "orbitActive"
local GlowType = Constants.Glow.Type

-- [ CONSTANTS ] ---------------------------------------------------------------
local TRACKED_INDEX = Constants.Tracked.SystemIndex.Tracked
local TRACKED_PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local COOLDOWN_THROTTLE = 0.1
local TALENT_REPARSE_DELAY = 0.5
local CURSOR_POLL_INTERVAL = 0.25

local DESAT_CURVE = C_CurveUtil.CreateCurve()
DESAT_CURVE:AddPoint(0.0, 0)
DESAT_CURVE:AddPoint(0.001, 1)
DESAT_CURVE:AddPoint(1.0, 1)

-- [ SPELL OVERRIDE ALIAS ] ----------------------------------------------------
local function GetActiveSpellID(spellID) return FindSpellOverrideByID(spellID) end

-- [ TOOLTIP PARSER ALIASES ] --------------------------------------------------
local Parser = Orbit.TooltipParser
local ParseActiveDuration = function(t, id) return Parser:ParseActiveDuration(t, id) end
local ParseCooldownDuration = function(t, id) return Parser:ParseCooldownDuration(t, id) end
local BuildPhaseCurve = function(a, c) return Parser:BuildPhaseCurve(a, c) end

-- [ MODULE ] ------------------------------------------------------------------
Orbit.TrackedUpdater = {}
local Updater = Orbit.TrackedUpdater

-- [ ACTIVE GLOW ] -------------------------------------------------------------
function Updater:StartActiveGlow(plugin, icon)
    if not LCG then return end
    local systemIndex = icon.systemIndex or TRACKED_INDEX
    
    local typeName, options = OrbitEngine.GlowUtils:BuildOptions(plugin, systemIndex, "ActiveGlow", { r = 0.3, g = 0.8, b = 1, a = 1 }, ACTIVE_GLOW_KEY)
    if not typeName or not options then return end
    
    LCG.Show(icon, typeName, options)
    icon._activeGlowing = true
    icon._activeGlowType = typeName
end

function Updater:StopActiveGlow(icon)
    if not LCG or not icon._activeGlowing then return end
    local t = icon._activeGlowType
    if t then
        LCG.Hide(icon, t, ACTIVE_GLOW_KEY)
    end
    icon._activeGlowing = false
    icon._activeGlowType = nil
end

-- [ ICON UPDATE ] -------------------------------------------------------------
function Updater:UpdateTrackedIcon(plugin, icon)
    if not icon.trackedId then icon:Hide(); return end

    local systemIndex = icon.systemIndex or TRACKED_INDEX
    local showGCDSwipe = plugin:GetSetting(systemIndex, "ShowGCDSwipe") ~= false
    local showActiveDuration = plugin:GetSetting(systemIndex, "ShowActiveDuration") ~= false
    if not showActiveDuration then
        icon.activeDuration = nil
        icon.desatCurve = nil
        icon.cdAlphaCurve = nil
        if icon._activeGlowing then self:StopActiveGlow(icon) end
        icon._activeGlowExpiry = nil
        icon.ActiveCooldown:Clear()
    end

    local texture, durObj
    local IsSpellUsable = Orbit.TrackedLayout.IsGridItemUsable

    if icon.trackedType == "spell" then
        if not IsSpellKnown(icon.trackedId) and not IsPlayerSpell(icon.trackedId) then
            local activeId = GetActiveSpellID(icon.trackedId)
            if activeId == icon.trackedId or (not IsSpellKnown(activeId) and not IsPlayerSpell(activeId)) then
                icon:Hide(); return
            end
        end

        local activeId = GetActiveSpellID(icon.trackedId)
        texture = C_Spell.GetSpellTexture(activeId)
        if texture then
            icon.Icon:SetTexture(texture)
            local cdInfo = C_Spell.GetSpellCooldown(activeId)
            local onGCD = cdInfo and cdInfo.isOnGCD
            local chargeInfo = icon.isChargeSpell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(activeId)
            if chargeInfo then
                -- TODO(API): maxCharges is non-secret after hotfix; simplify issecretvalue guard
                if not issecretvalue(chargeInfo.currentCharges) then
                    icon._trackedCharges = chargeInfo.currentCharges
                    icon._knownRechargeDuration = chargeInfo.cooldownDuration
                    icon._rechargeEndsAt = (chargeInfo.cooldownStartTime > 0 and chargeInfo.cooldownDuration > 0)
                            and (chargeInfo.cooldownStartTime + chargeInfo.cooldownDuration)
                        or nil
                end
                CooldownUtils:TrackChargeCompletion(icon)
                local chargeDurObj = C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(activeId)
                if chargeDurObj then
                    icon.Cooldown:SetCooldownFromDurationObject(chargeDurObj, true)
                else
                    icon.Cooldown:Clear()
                    icon._trackedCharges = icon._maxCharges
                    icon._rechargeEndsAt = nil
                end
                local allConsumed = icon._trackedCharges and icon._trackedCharges == 0
                icon.Icon:SetDesaturation(allConsumed and 1 or 0)
                icon.Cooldown:SetAlpha(1)
                if icon.activeDuration and icon._activeGlowExpiry and GetTime() < icon._activeGlowExpiry then
                    icon.Cooldown:Clear()
                    local castTime = icon._activeGlowExpiry - icon.activeDuration
                    -- Legacy :SetCooldown required: ActiveCooldown uses computed startTime/duration, no DurationObject API exists
                    icon.ActiveCooldown:SetCooldown(castTime, icon.activeDuration)
                    if not icon._activeGlowing then self:StartActiveGlow(plugin, icon) end
                else
                    icon.ActiveCooldown:Clear()
                    if icon._activeGlowing then self:StopActiveGlow(icon) end
                    icon._activeGlowExpiry = nil
                end
            elseif onGCD and not showGCDSwipe then
                icon.Cooldown:Clear()
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(0)
            else
                durObj = C_Spell.GetSpellCooldownDuration(activeId)
                if durObj then
                    icon.Cooldown:SetCooldownFromDurationObject(durObj, true)
                    local desatPct = onGCD and 0 or durObj:EvaluateRemainingPercent(icon.desatCurve or DESAT_CURVE)
                    icon.Icon:SetDesaturation(desatPct)
                    if icon.cdAlphaCurve then icon.Cooldown:SetAlpha(durObj:EvaluateRemainingPercent(icon.cdAlphaCurve)) end
                    -- TODO(API): replace fallback with cdInfo.isActive once hotfix is live
                    local onRealCD = cdInfo and (cdInfo.isActive ~= nil and cdInfo.isActive or (issecretvalue(cdInfo.startTime) or cdInfo.startTime > 0))
                    if icon.activeDuration and onRealCD and not onGCD and icon._activeGlowExpiry then
                        local castTime = icon._activeGlowExpiry - icon.activeDuration
                        icon.ActiveCooldown:SetCooldown(castTime, icon.activeDuration)
                    else
                        icon.ActiveCooldown:Clear()
                    end
                    if LCG and icon._activeGlowExpiry then
                        if GetTime() < icon._activeGlowExpiry then
                            if not icon._activeGlowing then self:StartActiveGlow(plugin, icon) end
                        else
                            self:StopActiveGlow(icon)
                            icon._activeGlowExpiry = nil
                        end
                    end
                else
                    icon.Cooldown:Clear()
                    icon.Cooldown:SetAlpha(1)
                    icon.ActiveCooldown:Clear()
                    icon.Icon:SetDesaturation(0)
                    if icon._activeGlowing then self:StopActiveGlow(icon) end
                end
            end

            local displayCount = chargeInfo and chargeInfo.currentCharges or C_Spell.GetSpellDisplayCount(activeId)
            if displayCount then icon.CountText:SetText(displayCount); icon.CountText:Show()
            else icon.CountText:Hide() end
        end
    elseif icon.trackedType == "item" then
        local usable, noMana = C_Item.IsUsableItem(icon.trackedId)
        local isUsable = usable or noMana or C_Item.GetItemCount(icon.trackedId, false, true) > 0

        texture = C_Item.GetItemIconByID(icon.trackedId)
        if texture then
            icon.Icon:SetTexture(texture)
            if not isUsable then
                icon.Cooldown:Clear()
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(1)
                icon.CountText:SetText("0")
                icon.CountText:Show()
                if icon._activeGlowing then self:StopActiveGlow(icon) end
            elseif icon.useSpellId then
                -- Prefer item cooldown (correct for trinkets). Fall back to spell cooldown (Healthstones in combat).
                local start, duration = C_Container.GetItemCooldown(icon.trackedId)
                if start and duration and duration > 1.5 then
                    -- Legacy :SetCooldown required: C_Container.GetItemCooldown returns raw numbers, no DurationObject API exists
                    icon.Cooldown:SetCooldown(start, duration)
                    if icon.activeDuration and duration > icon.activeDuration then
                        local inActivePhase = (GetTime() - start) < icon.activeDuration
                        if inActivePhase then
                            icon.Icon:SetDesaturation(0)
                            icon.Cooldown:SetAlpha(0)
                            -- Legacy :SetCooldown required: ActiveCooldown uses item start + activeDuration, no DurationObject API
                            icon.ActiveCooldown:SetCooldown(start, icon.activeDuration)
                            if not icon._activeGlowing then self:StartActiveGlow(plugin, icon) end
                        else
                            icon.Icon:SetDesaturation(1)
                            icon.Cooldown:SetAlpha(1)
                            icon.ActiveCooldown:Clear()
                            if icon._activeGlowing then self:StopActiveGlow(icon) end
                        end
                    else
                        icon.Icon:SetDesaturation(1)
                        icon.Cooldown:SetAlpha(1)
                        icon.ActiveCooldown:Clear()
                    end
                else
                    durObj = C_Spell.GetSpellCooldownDuration(icon.useSpellId)
                    if durObj then
                        icon.Cooldown:SetCooldownFromDurationObject(durObj, true)
                        icon.Icon:SetDesaturation(durObj:EvaluateRemainingPercent(icon.desatCurve or DESAT_CURVE))
                    else
                        icon.Cooldown:Clear()
                        icon.Cooldown:SetAlpha(1)
                        icon.Icon:SetDesaturation(0)
                    end
                    icon.ActiveCooldown:Clear()
                    if icon._activeGlowing then self:StopActiveGlow(icon) end
                end
                local count = C_Item.GetItemCount(icon.trackedId, false, true)
                if count and count > 1 then icon.CountText:SetText(count); icon.CountText:Show()
                else icon.CountText:Hide() end
            else
                local start, duration = C_Container.GetItemCooldown(icon.trackedId)
                if start and duration and duration > 0 then
                    -- Legacy :SetCooldown required: C_Container.GetItemCooldown returns raw numbers, no DurationObject API exists
                    icon.Cooldown:SetCooldown(start, duration)
                    if icon.activeDuration and duration > icon.activeDuration then
                        local inActivePhase = (GetTime() - start) < icon.activeDuration
                        if inActivePhase then
                            icon.Icon:SetDesaturation(0)
                            icon.Cooldown:SetAlpha(0)
                            -- Legacy :SetCooldown required: ActiveCooldown uses item start + activeDuration, no DurationObject API
                            icon.ActiveCooldown:SetCooldown(start, icon.activeDuration)
                            if not icon._activeGlowing then self:StartActiveGlow(plugin, icon) end
                        else
                            icon.Icon:SetDesaturation(1)
                            icon.Cooldown:SetAlpha(1)
                            icon.ActiveCooldown:Clear()
                            if icon._activeGlowing then self:StopActiveGlow(icon) end
                        end
                    else
                        icon.Icon:SetDesaturation(1)
                        icon.Cooldown:SetAlpha(1)
                        icon.ActiveCooldown:Clear()
                    end
                else
                    icon.Cooldown:Clear()
                    icon.Cooldown:SetAlpha(1)
                    icon.ActiveCooldown:Clear()
                    icon.Icon:SetDesaturation(0)
                    if icon._activeGlowing then self:StopActiveGlow(icon) end
                end
                local count = C_Item.GetItemCount(icon.trackedId, false, true)
                if count and count > 1 then icon.CountText:SetText(count); icon.CountText:Show()
                else icon.CountText:Hide() end
            end
        end
    end

    if not texture then
        icon.Icon:SetTexture(TRACKED_PLACEHOLDER_ICON)
        icon.Icon:SetDesaturation(1)
        icon.Cooldown:Clear()
        icon.CountText:Hide()
    end
    icon:Show()
end

-- [ BATCH UPDATE ] ------------------------------------------------------------
function Updater:UpdateTrackedIconsDisplay(plugin, anchor)
    if not anchor or not anchor.activeIcons then return end
    for _, icon in pairs(anchor.activeIcons) do
        if icon.trackedId then self:UpdateTrackedIcon(plugin, icon) end
    end
end

-- [ EVENT-DRIVEN UPDATE ] -----------------------------------------------------
function Updater:StartTrackedUpdateTicker(plugin)
    if plugin._trackedEventSetup then return end
    plugin._trackedEventSetup = true
    local Layout = Orbit.TrackedLayout
    
    local nextUpdate = 0
    local function DoUpdate()
        
        if plugin.trackedAnchor then
            if Layout:HasUsabilityChanged(plugin.trackedAnchor) then
                Layout:LayoutTrackedIcons(plugin, plugin.trackedAnchor, TRACKED_INDEX, plugin.IsDraggingCooldownAbility)
            end
            if plugin.trackedAnchor.activeIcons then
                for _, icon in pairs(plugin.trackedAnchor.activeIcons) do
                    if icon.trackedId then self:UpdateTrackedIcon(plugin, icon) end
                end
            end
        end
        for _, childData in pairs(plugin.activeChildren) do
            if childData.frame then
                if Layout:HasUsabilityChanged(childData.frame) then
                    Layout:LayoutTrackedIcons(plugin, childData.frame, childData.systemIndex, plugin.IsDraggingCooldownAbility)
                end
                if childData.frame.activeIcons then
                    for _, icon in pairs(childData.frame.activeIcons) do
                        if icon.trackedId then self:UpdateTrackedIcon(plugin, icon) end
                    end
                end
            end
        end
    end
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:SetScript("OnEvent", function()
        local now = GetTime()
        if now < nextUpdate then return end
        nextUpdate = now + COOLDOWN_THROTTLE
        DoUpdate()
    end)
    -- Visual-state poll: re-evaluate desat/alpha/glow without touching cooldown frames
    local function PollVisualState()
        local function PollAnchor(anchor)
            if not anchor or not anchor.activeIcons then return end
            for _, icon in pairs(anchor.activeIcons) do
                if icon.trackedId and icon:IsShown() and icon.trackedType == "spell" then
                    local activeId = GetActiveSpellID(icon.trackedId)
                    local durObj = C_Spell.GetSpellCooldownDuration(activeId)
                    local cdInfo = C_Spell.GetSpellCooldown(activeId)
                    local onGCD = cdInfo and cdInfo.isOnGCD
                    local isActive = icon._activeGlowExpiry and GetTime() < icon._activeGlowExpiry
                    if durObj then
                        local desat = onGCD and 0 or durObj:EvaluateRemainingPercent(icon.desatCurve or DESAT_CURVE)
                        icon.Icon:SetDesaturation(desat)
                        if icon.cdAlphaCurve then icon.Cooldown:SetAlpha(durObj:EvaluateRemainingPercent(icon.cdAlphaCurve)) end
                    else
                        icon.Icon:SetDesaturation(0)
                        icon.Cooldown:SetAlpha(1)
                        icon.ActiveCooldown:Clear()
                    end
                    if isActive then
                        if not icon._activeGlowing then Updater:StartActiveGlow(plugin, icon) end
                    else
                        if icon._activeGlowing then Updater:StopActiveGlow(icon) end
                        if icon._activeGlowExpiry then
                            icon._activeGlowExpiry = nil
                            icon.ActiveCooldown:Clear()
                        end
                    end
                end
            end
        end
        
        if plugin.trackedAnchor then PollAnchor(plugin.trackedAnchor) end
        for _, childData in pairs(plugin.activeChildren) do
            if childData.frame then PollAnchor(childData.frame) end
        end
    end
    local pollAccum = 0
    local POLL_INTERVAL = 0.3
    frame:SetScript("OnUpdate", function(_, elapsed)
        pollAccum = pollAccum + elapsed
        if pollAccum < POLL_INTERVAL then return end
        pollAccum = 0
        PollVisualState()
    end)
    plugin._trackedEventFrame = frame
end

-- [ TALENT REPARSE ] ----------------------------------------------------------
function Updater:ReparseActiveDurations(plugin)
    
    local function ReparseAnchor(anchor, systemIndex)
        if not anchor then return end
        local tracked = plugin:GetSetting(systemIndex, "TrackedItems") or {}
        local changed = false
        for key, data in pairs(tracked) do
            if data.id then
                local parseId = (data.type == "spell") and GetActiveSpellID(data.id) or data.id
                local newActDur = ParseActiveDuration(data.type, parseId)
                local newCdDur = ParseCooldownDuration(data.type, parseId)
                if newActDur ~= data.activeDuration or newCdDur ~= data.cooldownDuration then
                    data.activeDuration = newActDur
                    data.cooldownDuration = newCdDur
                    changed = true
                end
            end
        end
        if changed then plugin:SetSetting(systemIndex, "TrackedItems", tracked) end
        for _, icon in pairs(anchor.activeIcons or {}) do
            local key = icon.gridX .. "," .. icon.gridY
            local data = tracked[key]
            if data then icon.activeDuration = data.activeDuration; icon.cooldownDuration = data.cooldownDuration end
            local hasActive = icon.activeDuration and icon.cooldownDuration
            icon.desatCurve = hasActive and BuildPhaseCurve(icon.activeDuration, icon.cooldownDuration) or nil
            icon.cdAlphaCurve = hasActive and BuildPhaseCurve(icon.activeDuration, icon.cooldownDuration) or nil
        end
    end
    
    if plugin.trackedAnchor then ReparseAnchor(plugin.trackedAnchor, TRACKED_INDEX) end
    for _, childData in pairs(plugin.activeChildren) do
        if childData.frame then ReparseAnchor(childData.frame, childData.systemIndex) end
    end
end

-- RegisterTalentWatcher: talent events handled by RegisterSpellCastWatcher (TRAIT_CONFIG_UPDATED)

function Updater:RefreshAllTrackedLayouts(plugin)
    if plugin.trackedAnchor then plugin:LoadTrackedItems(plugin.trackedAnchor, TRACKED_INDEX) end
    for _, childData in pairs(plugin.activeChildren) do
        if childData.frame then plugin:LoadTrackedItems(childData.frame, childData.systemIndex) end
    end
end

function Updater:ReloadTrackedForSpec(plugin)
    local function ReloadAnchor(anchor, systemIndex)
        if not anchor then return end
        anchor:ClearAllPoints()
        plugin:LoadTrackedItems(anchor, systemIndex)
        if OrbitEngine.PositionManager then OrbitEngine.PositionManager:ClearFrame(anchor) end
        OrbitEngine.Frame:RestorePosition(anchor, plugin, systemIndex)
        plugin:ClearStaleTrackedSpatial(anchor, systemIndex)
        plugin:RefreshTrackedAnchorState(anchor)
    end
    if plugin.trackedAnchor then
        ReloadAnchor(plugin.trackedAnchor, TRACKED_INDEX)
    end
    for _, childData in pairs(plugin.activeChildren) do
        if childData.frame then
            ReloadAnchor(childData.frame, childData.frame.systemIndex)
        end
    end
    plugin:ReloadTrackedBarsForSpec()
end
function Updater:RegisterSpellCastWatcher(plugin)
    if plugin.spellCastWatcherSetup then return end
    plugin.spellCastWatcherSetup = true

    
    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:SetScript("OnEvent", function(_, event, unit, _, spellId)
        if event == "TRAIT_CONFIG_UPDATED" then
            C_Timer.After(TALENT_REPARSE_DELAY, function()
                if InCombatLockdown() then return end
                self:ReparseActiveDurations(plugin)
                plugin:RefreshTrackedBarMaxCharges()
                self:RefreshAllTrackedLayouts(plugin)
            end)
            return
        end
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            self:OnTrackedEquipmentChanged(plugin)
            return
        end
        if unit ~= "player" then return end
        local function CheckAnchor(anchor)
            if not anchor or not anchor.activeIcons then return end
            for _, icon in pairs(anchor.activeIcons) do
                local isMatch = (icon.trackedType == "spell" and icon.trackedId == spellId)
                    or (icon.trackedType == "item" and icon.useSpellId == spellId)
                if isMatch then
                    if icon.activeDuration then
                        icon._activeGlowExpiry = GetTime() + icon.activeDuration
                        local expectedId = icon.trackedId
                        C_Timer.After(icon.activeDuration, function()
                            if icon.trackedId ~= expectedId then return end
                            if icon._activeGlowing then self:StopActiveGlow(icon) end
                            icon._activeGlowExpiry = nil
                        end)
                    end
                    if icon.isChargeSpell then CooldownUtils:OnChargeCast(icon) end
                end
            end
        end
        
        if plugin.trackedAnchor then CheckAnchor(plugin.trackedAnchor) end
        for _, childData in pairs(plugin.activeChildren) do
            if childData.frame then CheckAnchor(childData.frame) end
        end
    end)
end

-- [ EQUIPMENT CHANGE HANDLER ] ------------------------------------------------
function Updater:OnTrackedEquipmentChanged(plugin)
    local function UpdateAnchor(anchor, systemIndex)
        if not anchor then return end
        local tracked = plugin:GetSetting(systemIndex, "TrackedItems") or {}
        local changed = false
        for key, data in pairs(tracked) do
            if data.slotId then
                local newItemId = GetInventoryItemID("player", data.slotId)
                if newItemId and newItemId ~= data.id then
                    data.id = newItemId
                    data.useSpellId = select(2, GetItemSpell(newItemId)) or nil
                    local parseId = data.id
                    data.activeDuration = Orbit.TooltipParser:ParseActiveDuration("item", parseId)
                    data.cooldownDuration = Orbit.TooltipParser:ParseCooldownDuration("item", parseId)
                    changed = true
                elseif not newItemId then
                    tracked[key] = nil
                    changed = true
                end
            end
        end
        if changed then
            plugin:SetSetting(systemIndex, "TrackedItems", tracked)
            plugin:LoadTrackedItems(anchor, systemIndex)
        end
    end
    
    
    if plugin.trackedAnchor then UpdateAnchor(plugin.trackedAnchor, TRACKED_INDEX) end
    for _, childData in pairs(plugin.activeChildren) do
        if childData.frame then UpdateAnchor(childData.frame, childData.frame.systemIndex) end
    end
end

-- [ CURSOR WATCHER ] ----------------------------------------------------------
function Updater:SetTrackedClickEnabled(plugin, enabled)
    
    
    if plugin.trackedAnchor then
        plugin.trackedAnchor.orbitClickThrough = not enabled
        plugin.trackedAnchor:EnableMouse(enabled)
        for _, icon in pairs(plugin.trackedAnchor.activeIcons or {}) do
            icon.orbitClickThrough = not enabled
            icon:EnableMouse(enabled)
        end
    end
    for _, childData in pairs(plugin.activeChildren) do
        if childData.frame then
            childData.frame.orbitClickThrough = not enabled
            childData.frame:EnableMouse(enabled)
            for _, icon in pairs(childData.frame.activeIcons or {}) do
                icon.orbitClickThrough = not enabled
                icon:EnableMouse(enabled)
            end
        end
    end
end

function Updater:RegisterCursorWatcher(plugin)
    local lastCursor = nil
    local lastEditMode = nil
    local lastShift = nil
    
    local Layout = Orbit.TrackedLayout
    local accum = 0
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(_, elapsed)
        accum = accum + elapsed
        if accum < CURSOR_POLL_INTERVAL then return end
        accum = 0
        local cursorType = GetCursorInfo()
        local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
        local isShift = IsShiftKeyDown()
        if InCombatLockdown() then return end
        if cursorType == lastCursor and isEditMode == lastEditMode and isShift == lastShift then return end
        lastCursor = cursorType
        lastEditMode = isEditMode
        lastShift = isShift
        if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
        local isDroppable = plugin.IsDraggingCooldownAbility and plugin.IsDraggingCooldownAbility()
        self:SetTrackedClickEnabled(plugin, isDroppable or isShift or isEditMode)
        plugin:SetTrackedBarClickEnabled(isDroppable or isShift or isEditMode)
        if Orbit.ViewerInjection then Orbit.ViewerInjection:SetClickEnabled(isDroppable or isShift or isEditMode) end
        
        if plugin.trackedAnchor then
            Layout:LayoutTrackedIcons(plugin, plugin.trackedAnchor, TRACKED_INDEX, plugin.IsDraggingCooldownAbility)
            if isDroppable then plugin.trackedAnchor.DropHighlight:Show() else plugin.trackedAnchor.DropHighlight:Hide() end
        end
        for _, childData in pairs(plugin.activeChildren) do
            if childData.frame then
                Layout:LayoutTrackedIcons(plugin, childData.frame, childData.systemIndex, plugin.IsDraggingCooldownAbility)
                if isDroppable then childData.frame.DropHighlight:Show() else childData.frame.DropHighlight:Hide() end
            end
        end
        -- Tracked bar cursor updates (merged from separate watcher)
        plugin:UpdateAllSeedVisibility()
        plugin:RefreshAllTrackedBarControlVisibility()
    end)
end
