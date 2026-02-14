---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon
local INACTIVE_ALPHA_DEFAULT = 60
local FLASH_DURATION = 0.15
local DESAT_INTERVAL = 0.1

local DESAT_CURVE = C_CurveUtil.CreateCurve()
DESAT_CURVE:AddPoint(0.0, 1.0)
DESAT_CURVE:AddPoint(0.001, 0.0)
DESAT_CURVE:AddPoint(1.0, 0.0)

-- [ FLASH OVERLAY ]----------------------------------------------------------------------------------
local function EnsureFlashOverlay(icon)
    if icon.orbitCDMFlash then return end
    local flash = CreateFrame("Frame", nil, icon)
    flash:SetAllPoints(icon)
    flash:SetFrameLevel(icon:GetFrameLevel() + 3)
    flash:Hide()

    local tex = flash:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetAllPoints(flash)
    tex:SetColorTexture(1, 1, 1, 0.4)

    local fadeGroup = flash:CreateAnimationGroup()
    fadeGroup:SetToFinalAlpha(true)
    local fadeOut = fadeGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(FLASH_DURATION)
    fadeOut:SetSmoothing("OUT")
    fadeGroup:SetScript("OnFinished", function() flash:Hide() end)

    icon.orbitCDMFlash = flash
    icon.orbitCDMFlashTex = tex
    icon.orbitCDMFlashFade = fadeGroup
end

local function FlashIcon(icon, color)
    if not icon.orbitCDMFlash then return end
    icon.orbitCDMFlashTex:SetColorTexture(color.r, color.g, color.b, color.a or 0.4)
    icon.orbitCDMFlash:SetAlpha(1)
    icon.orbitCDMFlash:Show()
    icon.orbitCDMFlashFade:Play()
end

local function FindIconBySpellID(spellID)
    for _, entry in pairs(VIEWER_MAP) do
        if entry.viewer then
            for _, child in ipairs({ entry.viewer:GetChildren() }) do
                local cached = child.orbitCachedSpellID
                if child:IsShown() and cached and not issecretvalue(cached) and cached == spellID then return child end
            end
        end
    end
end

hooksecurefunc("ActionButtonDown", function(id)
    local button = GetActionButtonForID(id)
    if not button or not button.action then return end
    local actionType, spellID = GetActionInfo(button.action)
    if actionType ~= "spell" or not spellID then return end
    local icon = FindIconBySpellID(spellID)
    if not icon or not icon.orbitCDMSystemIndex then return end
    FlashIcon(icon, CDM:GetSetting(icon.orbitCDMSystemIndex, "KeypressColor") or { r = 1, g = 1, b = 1, a = 0 })
end)

-- [ BUFF ICON AURA DURATION ]-----------------------------------------------------------------------
local function GetBuffIconAuraDuration(icon)
    local unit = icon.GetAuraDataUnit and icon:GetAuraDataUnit()
    if not unit then return nil end
    local auraID = icon.auraInstanceID
    if auraID == nil or issecretvalue(auraID) then return nil end
    return C_UnitAuras.GetAuraDuration(unit, auraID)
end

-- [ ANCHOR LOOKUP ]----------------------------------------------------------------------------------
local function GetAnchorInfo(anchorFrame)
    return anchorFrame and OrbitEngine.FrameAnchor and OrbitEngine.FrameAnchor.anchors[anchorFrame]
end

-- [ PROCESS CHILDREN ]-------------------------------------------------------------------------------
function CDM:ProcessChildren(anchor)
    if not anchor then return end
    local entry = VIEWER_MAP[anchor.systemIndex]
    local blizzFrame = entry and entry.viewer
    if not blizzFrame then return end

    local systemIndex = anchor.systemIndex
    local activeChildren = {}
    local alwaysShow = (systemIndex == BUFFICON_INDEX) and self:GetSetting(systemIndex, "AlwaysShow")

    for _, child in ipairs({ blizzFrame:GetChildren() }) do
        if child.layoutIndex then
            if not child.orbitOnShowHooked then
                local plugin = self
                child:HookScript("OnShow", function(c)
                    local parent = c:GetParent()
                    local anc = parent and parent:GetParent()
                    if Orbit.Skin.Icons and Orbit.Skin.Icons.frameSettings then
                        local s = Orbit.Skin.Icons.frameSettings[parent]
                        if s then Orbit.Skin.Icons:ApplyCustom(c, s) end
                    end
                    if anc and plugin.ProcessChildren then plugin:ProcessChildren(anc) end
                end)
                child.orbitOnShowHooked = true
            end

            if not child.orbitRefreshHooked and child.RefreshData then
                local a = anchor
                hooksecurefunc(child, "RefreshData", function()
                    Orbit.Async:Debounce("CDM_Refresh_" .. systemIndex, function() CDM:ProcessChildren(a) end, Constants.Timing.KeyboardRestoreDelay)
                end)
                child.orbitRefreshHooked = true
            end

            if alwaysShow then
                self:HookAlwaysShow(child)
                if child:GetCooldownID() then
                    child:Show()
                    table.insert(activeChildren, child)
                end
            elseif child:IsShown() then
                table.insert(activeChildren, child)
            end
        end
    end

    table.sort(activeChildren, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)

    if Orbit.Skin.Icons and #activeChildren > 0 then
        local hGrowth = (systemIndex == BUFFICON_INDEX) and self:GetHorizontalGrowth(anchor) or nil
        local vGrowth = self:GetGrowthDirection(anchor)
        local parentIndex = CooldownUtils:GetInheritedParentIndex(anchor, VIEWER_MAP)
        local overrides = parentIndex and {
            aspectRatio = self:GetSetting(parentIndex, "aspectRatio"),
            size = self:GetSetting(parentIndex, "IconSize"),
            padding = self:GetSetting(parentIndex, "IconPadding"),
        } or nil
        local skinSettings = CooldownUtils:BuildSkinSettings(self, systemIndex, { verticalGrowth = vGrowth, horizontalGrowth = hGrowth, inheritOverrides = overrides })

        if not Orbit.Skin.Icons.frameSettings then Orbit.Skin.Icons.frameSettings = setmetatable({}, { __mode = "k" }) end
        Orbit.Skin.Icons.frameSettings[blizzFrame] = skinSettings

        for _, icon in ipairs(activeChildren) do
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
            self:HookGCDSwipe(icon, systemIndex)
            self:ApplyTextSettings(icon, systemIndex)
            icon.orbitCDMSystemIndex = systemIndex
            if not InCombatLockdown() and icon.GetSpellID then
                local sid = icon:GetSpellID()
                if sid and not issecretvalue(sid) then icon.orbitCachedSpellID = sid end
            end
            EnsureFlashOverlay(icon)
        end

        Orbit.Skin.Icons:ApplyManualLayout(blizzFrame, activeChildren, skinSettings)

        if not InCombatLockdown() then
            local w, h = blizzFrame:GetSize()
            if w and h and w > 0 and h > 0 then anchor:SetSize(w, h) end
            anchor.orbitRowHeight = blizzFrame.orbitRowHeight
            anchor.orbitColumnWidth = blizzFrame.orbitColumnWidth
        end
    end
end

-- [ GCD SWIPE HOOK ]--------------------------------------------------------------------------------
function CDM:HookGCDSwipe(icon, systemIndex)
    if icon.orbitGCDHooked or not icon.RefreshSpellCooldownInfo then return end
    icon.orbitSystemIndex = systemIndex
    icon.orbitPlugin = self

    hooksecurefunc(icon, "RefreshSpellCooldownInfo", function(self)
        local plugin, sysIdx = self.orbitPlugin, self.orbitSystemIndex
        if not plugin or not sysIdx then return end
        if plugin:GetSetting(sysIdx, "ShowGCDSwipe") then return end
        if self.isOnGCD and not self.wasSetFromAura then
            local cooldown = self:GetCooldownFrame()
            if cooldown then cooldown:SetDrawSwipe(false) end
        end
    end)
    icon.orbitGCDHooked = true
end

-- [ ALWAYS SHOW (BUFF ICONS) ]----------------------------------------------------------------------
function CDM:HookAlwaysShow(icon)
    if icon.orbitAlwaysShowHooked then return end
    local plugin = self
    local function onStateChange(self)
        if not plugin:GetSetting(BUFFICON_INDEX, "AlwaysShow") then
            if self.Icon then
                self.Icon:SetDesaturation(0)
                self.Icon:SetAlpha(1)
            end
            return
        end
        if not self:GetCooldownID() then return end
        self:Show()
    end
    hooksecurefunc(icon, "UpdateShownState", onStateChange)
    hooksecurefunc(icon, "RefreshData", onStateChange)
    hooksecurefunc(icon, "RefreshSpellTexture", onStateChange)
    icon.orbitAlwaysShowHooked = true
end

-- [ TIMER COLOR CURVE ]-----------------------------------------------------------------------------
local WL = OrbitEngine.WidgetLogic
local curveCache = {}

local function GetNativeTimerCurveForSystem(systemIndex)
    local positions = CDM:GetSetting(systemIndex, "ComponentPositions")
    local timerOverrides = positions and positions["Timer"] and positions["Timer"].overrides
    local curveData = timerOverrides and timerOverrides["CustomColorCurve"]
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    local cached = curveCache[systemIndex]
    if cached and cached.data == curveData then return cached.curve end
    local curve = WL:ToNativeColorCurve(curveData)
    curveCache[systemIndex] = { data = curveData, curve = curve }
    return curve
end

local function FindFontString(cd)
    if not cd then return nil end
    for _, region in ipairs({ cd:GetRegions() }) do
        if region:GetObjectType() == "FontString" then return region end
    end
    return nil
end

local function GetTimerFontStrings(icon)
    if not icon.orbitTimerFS then
        icon.orbitTimerFS = FindFontString(icon.Cooldown or (icon.GetCooldownFrame and icon:GetCooldownFrame()))
    end
    if not icon.orbitActiveFS then
        icon.orbitActiveFS = FindFontString(icon.ActiveCooldown)
    end
    return icon.orbitTimerFS, icon.orbitActiveFS
end

local function GetDurationObject(icon, systemIndex)
    if systemIndex == BUFFICON_INDEX then return GetBuffIconAuraDuration(icon) end
    local spellID = icon.cooldownID or (icon.trackedType == "spell" and icon.trackedId)
    if spellID then return C_Spell.GetSpellCooldownDuration(spellID) end
    return nil
end

local function ApplyTimerColor(icon, curve, systemIndex)
    local timerFS, activeFS = GetTimerFontStrings(icon)
    if not timerFS and not activeFS then return end
    local durObj = GetDurationObject(icon, systemIndex)
    if not durObj then return end
    local color = durObj:EvaluateRemainingPercent(curve)
    if not color then return end
    local r, g, b, a = color:GetRGBA()
    if timerFS then timerFS:SetTextColor(r, g, b, a) end
    if activeFS then activeFS:SetTextColor(r, g, b, a) end
end

-- [ BUFF ICON DESATURATION ]------------------------------------------------------------------------
local function ApplyBuffIconDesaturation(icon, inactiveAlpha)
    if not icon.Icon then return end
    local durObj = GetBuffIconAuraDuration(icon)
    if durObj then
        icon.Icon:SetDesaturation(durObj:EvaluateRemainingPercent(DESAT_CURVE))
        icon.Icon:SetAlpha(1)
    else
        icon.Icon:SetDesaturation(1)
        icon.Icon:SetAlpha(inactiveAlpha)
    end
end

do
    local driverFrame = CreateFrame("Frame")
    local desatAccum = 0
    driverFrame:SetScript("OnUpdate", function(_, elapsed)
        desatAccum = desatAccum + elapsed
        local checkDesat = desatAccum >= DESAT_INTERVAL
        if checkDesat then desatAccum = 0 end

        for systemIndex, entry in pairs(VIEWER_MAP) do
            local curve = GetNativeTimerCurveForSystem(systemIndex)
            local needsDesat = checkDesat and systemIndex == BUFFICON_INDEX
                and CDM:GetSetting(BUFFICON_INDEX, "AlwaysShow")

            if entry.viewer and (curve or needsDesat) then
                local inactiveAlpha = needsDesat and (CDM:GetSetting(BUFFICON_INDEX, "InactiveAlpha") or INACTIVE_ALPHA_DEFAULT) / 100 or nil
                for _, child in ipairs({ entry.viewer:GetChildren() }) do
                    if child.layoutIndex and child:IsShown() and child:GetCooldownID() then
                        if curve then ApplyTimerColor(child, curve, systemIndex) end
                        if inactiveAlpha then ApplyBuffIconDesaturation(child, inactiveAlpha) end
                    end
                end
            end

            if curve and entry.anchor and entry.anchor.activeIcons then
                for _, icon in pairs(entry.anchor.activeIcons) do
                    if icon:IsShown() then ApplyTimerColor(icon, curve, systemIndex) end
                end
            end
        end
    end)
end

-- [ GROWTH DIRECTION ]------------------------------------------------------------------------------
function CDM:GetGrowthDirection(anchorFrame)
    local info = GetAnchorInfo(anchorFrame)
    return info and info.edge == "TOP" and "UP" or "DOWN"
end

function CDM:GetHorizontalGrowth(anchorFrame)
    local info = GetAnchorInfo(anchorFrame)
    if not info then return "CENTER" end
    if info.edge == "LEFT" or info.align == "LEFT" then return "RIGHT" end
    if info.edge == "RIGHT" or info.align == "RIGHT" then return "LEFT" end
    return "CENTER"
end
