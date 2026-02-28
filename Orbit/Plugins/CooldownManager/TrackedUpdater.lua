---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils
local LCG = LibStub("LibCustomGlow-1.0", true)
local ACTIVE_GLOW_KEY = "orbitActive"
local GlowType = Constants.PandemicGlow.Type
local GlowConfig = Constants.PandemicGlow

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local TRACKED_INDEX = Constants.Cooldown.SystemIndex.Tracked
local TRACKED_PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local DESAT_CURVE = C_CurveUtil.CreateCurve()
DESAT_CURVE:AddPoint(0.0, 0)
DESAT_CURVE:AddPoint(0.001, 1)
DESAT_CURVE:AddPoint(1.0, 1)

-- [ SPELL OVERRIDE ALIAS ]--------------------------------------------------------------------------
local function GetActiveSpellID(spellID) return FindSpellOverrideByID(spellID) end

-- [ TOOLTIP PARSER ALIASES ]------------------------------------------------------------------------
local Parser = Orbit.TrackedTooltipParser
local ParseActiveDuration = function(t, id) return Parser:ParseActiveDuration(t, id) end
local ParseCooldownDuration = function(t, id) return Parser:ParseCooldownDuration(t, id) end
local BuildPhaseCurve = function(a, c) return Parser:BuildPhaseCurve(a, c) end

-- [ MODULE ]----------------------------------------------------------------------------------------
Orbit.TrackedUpdater = {}
local Updater = Orbit.TrackedUpdater

-- [ ACTIVE GLOW ]-----------------------------------------------------------------------------------
function Updater:StartActiveGlow(plugin, icon)
    if not LCG then return end
    local systemIndex = icon.systemIndex or TRACKED_INDEX
    local glowTypeId = plugin:GetSetting(systemIndex, "ActiveGlowType")
    if glowTypeId == nil then glowTypeId = GlowType.None end
    if glowTypeId == GlowType.None then return end
    local color = plugin:GetSetting(systemIndex, "ActiveGlowColor") or { r = 0.3, g = 0.8, b = 1, a = 1 }
    local ct = { color.r, color.g, color.b, color.a or 1 }
    if glowTypeId == GlowType.Pixel then
        local cfg = GlowConfig.Pixel
        LCG.PixelGlow_Start(icon, ct, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, ACTIVE_GLOW_KEY)
    elseif glowTypeId == GlowType.Proc then
        local cfg = GlowConfig.Proc
        LCG.ProcGlow_Start(icon, { color = ct, startAnim = false, duration = cfg.Duration, key = ACTIVE_GLOW_KEY })
    elseif glowTypeId == GlowType.Autocast then
        local cfg = GlowConfig.Autocast
        LCG.AutoCastGlow_Start(icon, ct, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, ACTIVE_GLOW_KEY)
    elseif glowTypeId == GlowType.Button then
        local cfg = GlowConfig.Button
        LCG.ButtonGlow_Start(icon, ct, cfg.Frequency, cfg.FrameLevel)
    end
    icon._activeGlowing = true
    icon._activeGlowType = glowTypeId
end

function Updater:StopActiveGlow(icon)
    if not LCG or not icon._activeGlowing then return end
    local t = icon._activeGlowType
    if t == GlowType.Pixel then LCG.PixelGlow_Stop(icon, ACTIVE_GLOW_KEY)
    elseif t == GlowType.Proc then LCG.ProcGlow_Stop(icon, ACTIVE_GLOW_KEY)
    elseif t == GlowType.Autocast then LCG.AutoCastGlow_Stop(icon, ACTIVE_GLOW_KEY)
    elseif t == GlowType.Button then LCG.ButtonGlow_Stop(icon) end
    icon._activeGlowing = false
    icon._activeGlowType = nil
end

-- [ ICON UPDATE ]-----------------------------------------------------------------------------------
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
            local cdInfo = C_Spell.GetSpellCooldown(activeId) or {}
            local onGCD = cdInfo.isOnGCD
            local chargeInfo = icon.isChargeSpell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(activeId)

            if chargeInfo then
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
                    icon.Icon:SetDesaturation(onGCD and 0 or durObj:EvaluateRemainingPercent(icon.desatCurve or DESAT_CURVE))
                    if icon.cdAlphaCurve then icon.Cooldown:SetAlpha(durObj:EvaluateRemainingPercent(icon.cdAlphaCurve)) end
                    local onRealCD = issecretvalue(cdInfo.startTime) or cdInfo.startTime > 0
                    if icon.activeDuration and onRealCD and not onGCD then
                        icon.ActiveCooldown:SetCooldown(cdInfo.startTime, icon.activeDuration)
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
            else
                local start, duration = C_Container.GetItemCooldown(icon.trackedId)
                if start and duration and duration > 0 then
                    icon.Cooldown:SetCooldown(start, duration)
                    if icon.activeDuration and duration > icon.activeDuration then
                        local inActivePhase = (GetTime() - start) < icon.activeDuration
                        if inActivePhase then
                            icon.Icon:SetDesaturation(0)
                            icon.Cooldown:SetAlpha(0)
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

    self:ApplyTimerTextColor(plugin, icon, durObj)
    icon:Show()
end

-- [ TIMER TEXT COLOR ]------------------------------------------------------------------------------
function Updater:ApplyTimerTextColor(plugin, icon, durObj)
    local cooldown = icon.Cooldown
    if not cooldown then return end
    local timerText = cooldown.Text
    if not timerText then
        local regions = { cooldown:GetRegions() }
        for _, region in ipairs(regions) do
            if region:GetObjectType() == "FontString" then timerText = region; break end
        end
        cooldown.Text = timerText
    end
    if not timerText then return end

    local systemIndex = icon.systemIndex or TRACKED_INDEX
    local positions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
    local timerPos = positions["Timer"] or {}
    local overrides = timerPos.overrides or {}

    if durObj and overrides.CustomColorCurve then
        local wowColorCurve = OrbitEngine.ColorCurve:ToNativeColorCurve(overrides.CustomColorCurve)
        if wowColorCurve then
            local secretColor = durObj:EvaluateRemainingPercent(wowColorCurve)
            timerText:SetTextColor(secretColor:GetRGBA())
            return
        end
    end
    CooldownUtils:ApplyTextColor(timerText, overrides)
end

-- [ BATCH UPDATE ]----------------------------------------------------------------------------------
function Updater:UpdateTrackedIconsDisplay(plugin, anchor)
    if not anchor or not anchor.activeIcons then return end
    for _, icon in pairs(anchor.activeIcons) do
        if icon.trackedId then self:UpdateTrackedIcon(plugin, icon) end
    end
end

-- [ TICKER ]----------------------------------------------------------------------------------------
function Updater:StartTrackedUpdateTicker(plugin)
    if plugin.trackedTicker then return end
    local Layout = Orbit.TrackedLayout
    local viewerMap = plugin.viewerMap
    plugin.trackedTicker = C_Timer.NewTicker(Constants.Timing.IconMonitorInterval, function()
        local entry = viewerMap[TRACKED_INDEX]
        if entry and entry.anchor then
            if Layout:HasUsabilityChanged(entry.anchor) then
                Layout:LayoutTrackedIcons(plugin, entry.anchor, TRACKED_INDEX, plugin.IsDraggingCooldownAbility)
            end
            if entry.anchor.activeIcons then
                for _, icon in pairs(entry.anchor.activeIcons) do
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
    end)
end

-- [ TALENT REPARSE ]--------------------------------------------------------------------------------
function Updater:ReparseActiveDurations(plugin)
    local viewerMap = plugin.viewerMap
    local function ReparseAnchor(anchor, systemIndex)
        if not anchor then return end
        local tracked = plugin:GetSetting(systemIndex, plugin:GetSpecKey("TrackedItems")) or {}
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
        if changed then plugin:SetSetting(systemIndex, plugin:GetSpecKey("TrackedItems"), tracked) end
        for _, icon in pairs(anchor.activeIcons or {}) do
            local key = icon.gridX .. "," .. icon.gridY
            local data = tracked[key]
            if data then icon.activeDuration = data.activeDuration; icon.cooldownDuration = data.cooldownDuration end
            local hasActive = icon.activeDuration and icon.cooldownDuration
            icon.desatCurve = hasActive and BuildPhaseCurve(icon.activeDuration, icon.cooldownDuration) or nil
            icon.cdAlphaCurve = hasActive and BuildPhaseCurve(icon.activeDuration, icon.cooldownDuration) or nil
        end
    end
    local entry = viewerMap[TRACKED_INDEX]
    if entry and entry.anchor then ReparseAnchor(entry.anchor, TRACKED_INDEX) end
    for _, childData in pairs(plugin.activeChildren) do
        if childData.frame then ReparseAnchor(childData.frame, childData.systemIndex) end
    end
end

function Updater:RegisterTalentWatcher(plugin)
    if plugin.talentWatcherSetup then return end
    plugin.talentWatcherSetup = true
    local TALENT_REPARSE_DELAY = 0.5
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    frame:SetScript("OnEvent", function()
        C_Timer.After(TALENT_REPARSE_DELAY, function()
            if InCombatLockdown() then return end
            self:ReparseActiveDurations(plugin)
            plugin:RefreshChargeMaxCharges()
            self:RefreshAllTrackedLayouts(plugin)
        end)
    end)
end

function Updater:RefreshAllTrackedLayouts(plugin)
    local viewerMap = plugin.viewerMap
    local entry = viewerMap[TRACKED_INDEX]
    if entry and entry.anchor then plugin:LoadTrackedItems(entry.anchor, TRACKED_INDEX) end
    for _, childData in pairs(plugin.activeChildren) do
        if childData.frame then plugin:LoadTrackedItems(childData.frame, childData.systemIndex) end
    end
end

function Updater:ReloadTrackedForSpec(plugin)
    local viewerMap = plugin.viewerMap
    local entry = viewerMap[TRACKED_INDEX]
    if entry and entry.anchor then
        plugin:LoadTrackedItems(entry.anchor, TRACKED_INDEX)
        plugin:ClearStaleTrackedSpatial(entry.anchor, TRACKED_INDEX)
    end
    for _, childData in pairs(plugin.activeChildren) do
        if childData.frame then
            plugin:LoadTrackedItems(childData.frame, childData.frame.systemIndex)
            plugin:ClearStaleTrackedSpatial(childData.frame, childData.frame.systemIndex)
        end
    end
    plugin:ReloadChargeBarsForSpec()
end

-- [ SPELL CAST WATCHER ]----------------------------------------------------------------------------
function Updater:RegisterSpellCastWatcher(plugin)
    if plugin.spellCastWatcherSetup then return end
    plugin.spellCastWatcherSetup = true
    local viewerMap = plugin.viewerMap
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:SetScript("OnEvent", function(_, _, unit, _, spellId)
        if unit ~= "player" then return end
        local function CheckAnchor(anchor)
            if not anchor or not anchor.activeIcons then return end
            for _, icon in pairs(anchor.activeIcons) do
                if icon.trackedType == "spell" and icon.trackedId == spellId then
                    if icon.activeDuration then icon._activeGlowExpiry = GetTime() + icon.activeDuration end
                    if icon.isChargeSpell then CooldownUtils:OnChargeCast(icon) end
                end
            end
        end
        local entry = viewerMap[TRACKED_INDEX]
        if entry and entry.anchor then CheckAnchor(entry.anchor) end
        for _, childData in pairs(plugin.activeChildren) do
            if childData.frame then CheckAnchor(childData.frame) end
        end
    end)
end

-- [ CURSOR WATCHER ]--------------------------------------------------------------------------------
function Updater:SetTrackedClickEnabled(plugin, enabled)
    local viewerMap = plugin.viewerMap
    local entry = viewerMap[TRACKED_INDEX]
    if entry and entry.anchor then
        entry.anchor.orbitClickThrough = not enabled
        entry.anchor:EnableMouse(enabled)
        for _, icon in pairs(entry.anchor.activeIcons or {}) do
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
    local viewerMap = plugin.viewerMap
    local Layout = Orbit.TrackedLayout
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function()
        local cursorType = GetCursorInfo()
        local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
        local isShift = IsShiftKeyDown()
        if InCombatLockdown() then return end
        if cursorType == lastCursor and isEditMode == lastEditMode and isShift == lastShift then return end
        lastCursor = cursorType
        lastEditMode = isEditMode
        lastShift = isShift
        Orbit.OOCFadeMixin:RefreshAll()
        local isDroppable = plugin.IsDraggingCooldownAbility and plugin.IsDraggingCooldownAbility()
        self:SetTrackedClickEnabled(plugin, isDroppable or isShift or isEditMode)
        plugin:SetChargeClickEnabled(isDroppable or isShift or isEditMode)
        local entry = viewerMap[TRACKED_INDEX]
        if entry and entry.anchor then
            Layout:LayoutTrackedIcons(plugin, entry.anchor, TRACKED_INDEX, plugin.IsDraggingCooldownAbility)
            if isDroppable then entry.anchor.DropHighlight:Show() else entry.anchor.DropHighlight:Hide() end
        end
        for _, childData in pairs(plugin.activeChildren) do
            if childData.frame then
                Layout:LayoutTrackedIcons(plugin, childData.frame, childData.systemIndex, plugin.IsDraggingCooldownAbility)
                if isDroppable then childData.frame.DropHighlight:Show() else childData.frame.DropHighlight:Hide() end
            end
        end
    end)
end
