---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon
local BUFFBAR_INDEX = Constants.Cooldown.SystemIndex.BuffBar
local INACTIVE_ALPHA_DEFAULT = 60
local FLASH_DURATION = 0.15
local BUFFBAR_MIN_WIDTH = 40
local BUFFBAR_MAX_COLORS = 5
local BUFFBAR_DEFAULT_COLORS = {
    { r = 0.3, g = 0.7, b = 1, a = 1 },
    { r = 0.4, g = 0.9, b = 0.4, a = 1 },
    { r = 1, g = 0.7, b = 0.3, a = 1 },
    { r = 0.9, g = 0.4, b = 0.9, a = 1 },
    { r = 1, g = 0.4, b = 0.4, a = 1 },
}
local BUFFBAR_TEXT_PADDING = 5
local BUFFBAR_ICON_TRIM = 0.07

-- Reusable child buffer alias
local PackChildren = function(...) return CooldownUtils:PackChildren(...) end
local _activeChildBuf = {}

local DESAT_CURVE = C_CurveUtil.CreateCurve()
DESAT_CURVE:AddPoint(0.0, 0.0)
DESAT_CURVE:AddPoint(0.001, 0.0)
DESAT_CURVE:AddPoint(1.0, 0.0)

-- Forward declarations for functions used in ProcessChildren but defined later
local GetNativeTimerCurveForSystem
local ApplyTimerColor
local ApplyBuffIconDesaturation
local ApplyBuffBarSkin

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
            for _, child in ipairs(PackChildren(entry.viewer:GetChildren())) do
                local cached = child.orbitCachedSpellID
                if child:IsShown() and cached and not issecretvalue(cached) and cached == spellID then
                    return child
                end
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
local function GetAnchorInfo(anchorFrame) return anchorFrame and OrbitEngine.FrameAnchor and OrbitEngine.FrameAnchor.anchors[anchorFrame] end

-- [ LIVE CANVAS PREVIEW ]----------------------------------------------------------------------------
Orbit.EventBus:On("CANVAS_SETTINGS_CHANGED", function(changedPlugin)
    if changedPlugin == CDM and CDM.buffBarAnchor then CDM:ProcessChildren(CDM.buffBarAnchor) end
end)

-- [ PROCESS CHILDREN ]-------------------------------------------------------------------------------
function CDM:ProcessChildren(anchor)
    if not anchor then return end
    local entry = VIEWER_MAP[anchor.systemIndex]
    local blizzFrame = entry and entry.viewer
    if not blizzFrame then return end

    local systemIndex = anchor.systemIndex
    wipe(_activeChildBuf)
    local activeChildren = _activeChildBuf
    local alwaysShow = (systemIndex == BUFFICON_INDEX) and self:GetSetting(systemIndex, "AlwaysShow")

    for _, child in ipairs(PackChildren(blizzFrame:GetChildren())) do
        if child.layoutIndex then
            if not child.orbitOnShowHooked then
                local plugin = self
                child:HookScript("OnShow", function(c)
                    local parent = c:GetParent()
                    local anc = parent and parent:GetParent()
                    if Orbit.Skin.Icons.frameSettings then
                        local s = Orbit.Skin.Icons.frameSettings[parent]
                        if s then
                            Orbit.Skin.Icons:ApplyCustom(c, s)
                        end
                    end
                    if anc and plugin.ProcessChildren then
                        plugin:ProcessChildren(anc)
                    end
                end)
                child.orbitOnShowHooked = true
            end

            if not child.orbitRefreshHooked and child.RefreshData then
                local a = anchor
                hooksecurefunc(child, "RefreshData", function()
                    Orbit.Async:Debounce("CDM_Refresh_" .. systemIndex, function()
                        CDM:ProcessChildren(a)
                    end, Constants.Timing.KeyboardRestoreDelay)
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

    if #activeChildren > 0 then
        local hGrowth = (systemIndex == BUFFICON_INDEX or systemIndex == BUFFBAR_INDEX) and self:GetHorizontalGrowth(anchor) or nil
        local vGrowth = self:GetGrowthDirection(anchor)
        local parentIndex = CooldownUtils:GetInheritedParentIndex(anchor, VIEWER_MAP)
        local overrides = parentIndex
                and {
                    aspectRatio = self:GetSetting(parentIndex, "aspectRatio"),
                    size = self:GetSetting(parentIndex, "IconSize"),
                    padding = self:GetSetting(parentIndex, "IconPadding"),
                }
            or nil
        local skinSettings =
            CooldownUtils:BuildSkinSettings(self, systemIndex, { verticalGrowth = vGrowth, horizontalGrowth = hGrowth, inheritOverrides = overrides })

        if not Orbit.Skin.Icons.frameSettings then
            Orbit.Skin.Icons.frameSettings = setmetatable({}, { __mode = "k" })
        end
        Orbit.Skin.Icons.frameSettings[blizzFrame] = skinSettings

        local curve = (systemIndex == BUFFICON_INDEX) and GetNativeTimerCurveForSystem(BUFFICON_INDEX) or nil
        local alwaysShow = self:GetSetting(systemIndex, "AlwaysShow")
        local inactiveAlpha = alwaysShow and (self:GetSetting(systemIndex, "InactiveAlpha") or INACTIVE_ALPHA_DEFAULT) / 100 or nil
        local hideBorders = alwaysShow and self:GetSetting(systemIndex, "HideBorders")
        local isBuffBar = (systemIndex == BUFFBAR_INDEX)
        if isBuffBar then
            skinSettings.buffBarHeight = self:GetSetting(systemIndex, "Height") or 20
            skinSettings.buffBarWidth = self:GetSetting(systemIndex, "Width") or 200
            skinSettings.buffBarSpacing = self:GetSetting(systemIndex, "Spacing") or 2
        end
        for barIdx, icon in ipairs(activeChildren) do
            if isBuffBar then
                ApplyBuffBarSkin(icon, skinSettings, barIdx)
            elseif not icon.orbitSkinApplied then
                Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
                icon.orbitSkinApplied = true
            end
            self:HookGCDSwipe(icon, systemIndex)
            if not isBuffBar then self:ApplyTextSettings(icon, systemIndex) end
            icon.orbitCDMSystemIndex = systemIndex
            local cd = icon.Cooldown or (icon.GetCooldownFrame and icon:GetCooldownFrame())
            if cd then
                local ac, cc = skinSettings.activeSwipeColor, skinSettings.cooldownSwipeColor
                local isAura = icon.wasSetFromAura == true
                local c = isAura and ac or cc
                local ds = cd.orbitDesiredSwipe or {}; cd.orbitDesiredSwipe = ds
                ds.activeR, ds.activeG, ds.activeB, ds.activeA = ac.r, ac.g, ac.b, ac.a
                ds.cooldownR, ds.cooldownG, ds.cooldownB, ds.cooldownA = cc.r, cc.g, cc.b, cc.a
                ds.r, ds.g, ds.b, ds.a = c.r, c.g, c.b, c.a
                cd.orbitUpdating = true
                cd:SetSwipeColor(c.r, c.g, c.b, c.a)
                cd:SetReverse(isAura)
                cd.orbitUpdating = false
            end
            if not InCombatLockdown() and icon.GetSpellID then
                local sid = icon:GetSpellID()
                if sid and not issecretvalue(sid) then
                    icon.orbitCachedSpellID = sid
                end
            end
            EnsureFlashOverlay(icon)
            if curve then ApplyTimerColor(icon, curve) end
            if inactiveAlpha then ApplyBuffIconDesaturation(icon, inactiveAlpha, hideBorders) end
        end

        if isBuffBar then
            -- Stack bars vertically with spacing, pixel-perfect dimensions
            local Pixel = OrbitEngine.Pixel
            local anchorFrame = entry.anchor
            local scale = anchorFrame:GetEffectiveScale()
            local spacing = Pixel:Multiple(skinSettings.buffBarSpacing or 2, scale)
            local barH = Pixel:Snap(skinSettings.buffBarHeight or 20, scale)
            local settingW = Pixel:Snap(math.max(skinSettings.buffBarWidth or 200, BUFFBAR_MIN_WIDTH), scale)
            -- When docked, anchor width is authoritative (syncDimensions from parent); when undocked, use setting width
            local isDocked = GetAnchorInfo(anchorFrame) ~= nil
            local barW = isDocked and anchorFrame:GetWidth() or math.max(anchorFrame:GetWidth(), settingW)
            local vGrowth = self:GetGrowthDirection(anchorFrame)
            local totalH = (#activeChildren * barH) + (math.max(#activeChildren - 1, 0) * spacing)
            blizzFrame:SetSize(barW, math.max(totalH, barH))
            for i, item in ipairs(activeChildren) do
                item:ClearAllPoints()
                local yOff = Pixel:Snap((i - 1) * (barH + spacing), scale)
                if vGrowth == "UP" then
                    item:SetPoint("BOTTOMLEFT", blizzFrame, "BOTTOMLEFT", 0, yOff)
                    item:SetPoint("BOTTOMRIGHT", blizzFrame, "BOTTOMRIGHT", 0, yOff)
                else
                    item:SetPoint("TOPLEFT", blizzFrame, "TOPLEFT", 0, -yOff)
                    item:SetPoint("TOPRIGHT", blizzFrame, "TOPRIGHT", 0, -yOff)
                end
                item:SetHeight(barH)
            end
        else
            Orbit.Skin.IconLayout:ApplyManualLayout(blizzFrame, activeChildren, skinSettings)
        end

        if not InCombatLockdown() then
            local anchorFrame = entry.anchor
            local w, h = blizzFrame:GetSize()
            -- BuffIcons: lock anchor width to total configured spells, not active count
            if systemIndex == BUFFICON_INDEX then
                local totalConfigured = 0
                for _, child in ipairs(PackChildren(blizzFrame:GetChildren())) do
                    if child.layoutIndex and child.GetCooldownID and child:GetCooldownID() then totalConfigured = totalConfigured + 1 end
                end
                if totalConfigured > 0 then
                    local limit = tonumber(skinSettings.limit) or 10
                    local scale = anchorFrame:GetEffectiveScale()
                    local iconW = OrbitEngine.Pixel:Snap((skinSettings.baseIconSize or Constants.Skin.DefaultIconSize) * ((skinSettings.size or 100) / 100), scale)
                    local pad = OrbitEngine.Pixel:Snap(tonumber(skinSettings.padding) or 0, scale)
                    local cols = math.min(totalConfigured, limit)
                    w = (cols * iconW) + ((cols - 1) * pad)
                end
            end
            if isBuffBar then
                -- Only sync height — width owned by anchor system (syncDimensions)
                if h and h > 0 then anchorFrame:SetHeight(h) end
                -- When undocked, set width from CDM setting; when docked, width is owned by parent sync
                if not GetAnchorInfo(anchorFrame) then
                    local sW = OrbitEngine.Pixel:Snap(math.max(skinSettings.buffBarWidth or 200, BUFFBAR_MIN_WIDTH), anchorFrame:GetEffectiveScale())
                    if anchorFrame:GetWidth() < sW then anchorFrame:SetWidth(sW) end
                end
            elseif w and h and w > 0 and h > 0 then
                anchorFrame:SetSize(w, h)
            end
            anchorFrame.orbitRowHeight = blizzFrame.orbitRowHeight
            anchorFrame.orbitColumnWidth = blizzFrame.orbitColumnWidth
        end
    end
end

-- [ PRE-SIZE ANCHORS ]------------------------------------------------------------------------------
-- Pre-sizes all viewer anchors to their max configured width so they don't need to resize during combat.
function CDM:PreSizeAnchors()
    if InCombatLockdown() then return end
    for systemIndex, entry in pairs(VIEWER_MAP) do
        local viewer = entry.viewer
        local anchor = entry.anchor
        if not viewer or not anchor then break end
        local skinSettings = CooldownUtils:BuildSkinSettings(self, systemIndex, {
            inheritOverrides = CooldownUtils:IsInheritingLayout(self, anchor, VIEWER_MAP)
                and CooldownUtils:BuildSkinSettings(self, CooldownUtils:GetInheritedParentIndex(anchor, VIEWER_MAP)) or nil,
        })
        local totalConfigured = 0
        for _, child in ipairs(PackChildren(viewer:GetChildren())) do
            if child.layoutIndex then totalConfigured = totalConfigured + 1 end
        end
        if totalConfigured > 0 and systemIndex ~= BUFFBAR_INDEX then
            local limit = tonumber(skinSettings.limit) or 10
            local scale = anchor:GetEffectiveScale()
            local baseSize = skinSettings.baseIconSize or Constants.Skin.DefaultIconSize
            local iconW, iconH = CooldownUtils:CalculateIconDimensions(self, systemIndex, skinSettings)
            local pad = OrbitEngine.Pixel:Snap(tonumber(skinSettings.padding) or 0, scale)
            local cols = math.min(totalConfigured, limit)
            local w = (cols * iconW) + ((cols - 1) * pad)
            if w > anchor:GetWidth() then anchor:SetSize(w, iconH) end
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
        local cooldown = self:GetCooldownFrame()
        if cooldown then
            local isAura = self.wasSetFromAura == true
            cooldown:SetReverse(isAura)
            local ds = cooldown.orbitDesiredSwipe
            if ds then
                local r = isAura and ds.activeR or ds.cooldownR
                if r then
                    local g, b, a = isAura and ds.activeG or ds.cooldownG, isAura and ds.activeB or ds.cooldownB, isAura and ds.activeA or ds.cooldownA
                    ds.r, ds.g, ds.b, ds.a = r, g, b, a
                    cooldown.orbitUpdating = true; cooldown:SetSwipeColor(r, g, b, a); cooldown.orbitUpdating = false
                end
            end
            if not plugin:GetSetting(sysIdx, "ShowGCDSwipe") and self.isOnGCD and not isAura then cooldown:SetDrawSwipe(false) end
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
        if not self:GetCooldownID() then
            return
        end
        self:Show()
    end
    hooksecurefunc(icon, "UpdateShownState", onStateChange)
    hooksecurefunc(icon, "RefreshData", onStateChange)
    hooksecurefunc(icon, "RefreshSpellTexture", onStateChange)
    icon.orbitAlwaysShowHooked = true
end

-- [ TIMER COLOR CURVE ]-----------------------------------------------------------------------------
local SB = OrbitEngine.SchemaBuilder
local curveCache = {}

GetNativeTimerCurveForSystem = function(systemIndex)
    local positions = CDM:GetComponentPositions(systemIndex)
    local timerOverrides = positions and positions["Timer"] and positions["Timer"].overrides
    local curveData = timerOverrides and timerOverrides["CustomColorCurve"]
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    local cached = curveCache[systemIndex]
    if cached and cached.data == curveData then return cached.curve end
    local curve = OrbitEngine.ColorCurve:ToNativeColorCurve(curveData)
    curveCache[systemIndex] = { data = curveData, curve = curve }
    return curve
end

local function FindFontString(cd)
    if not cd then return nil end
    for _, region in ipairs(PackChildren(cd:GetRegions())) do
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

local function EnsureTimerColorHook(fs)
    if fs._orbitColorHooked then return end
    fs._orbitColorHooked = true
    hooksecurefunc(fs, "SetTextColor", function(self)
        if self._orbitSettingColor then return end
        local c = self._orbitCurveColor
        if not c then return end
        self._orbitSettingColor = true
        self:SetTextColor(c[1], c[2], c[3], c[4])
        self._orbitSettingColor = false
    end)
end

local function SetCachedColor(fs, r, g, b, a)
    EnsureTimerColorHook(fs)
    local c = fs._orbitCurveColor
    if not c then c = { 0, 0, 0, 1 }; fs._orbitCurveColor = c end
    c[1], c[2], c[3], c[4] = r, g, b, a
    fs._orbitSettingColor = true
    fs:SetTextColor(r, g, b, a)
    fs._orbitSettingColor = false
end

local function EnsureBarColorHook(bar)
    if bar._orbitBarColorHooked then return end
    bar._orbitBarColorHooked = true
    hooksecurefunc(bar, "SetStatusBarColor", function(self)
        if self._orbitSettingColor then return end
        local c = self._orbitBarColor
        if not c then return end
        self._orbitSettingColor = true
        self:SetStatusBarColor(c[1], c[2], c[3], c[4])
        self._orbitSettingColor = false
    end)
end

local function SetBarColor(bar, r, g, b, a)
    EnsureBarColorHook(bar)
    local c = bar._orbitBarColor
    if not c then c = { 0, 0, 0, 1 }; bar._orbitBarColor = c end
    c[1], c[2], c[3], c[4] = r, g, b, a
    bar._orbitSettingColor = true
    bar:SetStatusBarColor(r, g, b, a)
    bar._orbitSettingColor = false
end

ApplyTimerColor = function(icon, curve)
    local timerFS, activeFS = GetTimerFontStrings(icon)
    if not timerFS and not activeFS then return end
    local durObj = GetBuffIconAuraDuration(icon)
    if not durObj then
        if timerFS then timerFS._orbitCurveColor = nil end
        if activeFS then activeFS._orbitCurveColor = nil end
        return
    end
    local color = durObj:EvaluateRemainingPercent(curve)
    if not color then return end
    local r, g, b, a = color:GetRGBA()
    if timerFS then SetCachedColor(timerFS, r, g, b, a) end
    if activeFS then SetCachedColor(activeFS, r, g, b, a) end
end

-- [ BUFF ICON DESATURATION ]------------------------------------------------------------------------
ApplyBuffIconDesaturation = function(icon, inactiveAlpha, hideBorders)
    if not icon.Icon then return end
    local durObj = GetBuffIconAuraDuration(icon)
    local borderFrame = hideBorders and Orbit.Skin.Icons.borderCache and Orbit.Skin.Icons.borderCache[icon]
    if durObj then
        icon.Icon:SetDesaturation(durObj:EvaluateRemainingPercent(DESAT_CURVE))
        icon.Icon:SetAlpha(1)
        if borderFrame then borderFrame:SetAlpha(1) end
    else
        icon.Icon:SetDesaturation(1)
        icon.Icon:SetAlpha(inactiveAlpha)
        if borderFrame then borderFrame:SetAlpha(0) end
    end
end

-- [ BUFF BAR SKINNING ]-----------------------------------------------------------------------------
ApplyBuffBarSkin = function(item, skinSettings, barIndex)
    local bar = item.Bar
    if not bar then return end
    local globals = Orbit.db.GlobalSettings
    local borderSize = globals.BorderSize or 1
    local textureName = globals.Texture
    local fontPath = CDM:GetGlobalFont()
    local baseFontSize = CDM:GetBaseFontSize()

    -- Icon size follows bar height from settings (skinning runs before layout anchoring)
    local barHeight = skinSettings.buffBarHeight or 20
    local iconFrame = item.Icon
    local Pixel = OrbitEngine.Pixel
    local scale = item:GetEffectiveScale()
    local iconSize = Pixel:Snap(barHeight, scale)
    if iconFrame then
        iconFrame:SetSize(iconSize, iconSize)
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("LEFT", item, "LEFT", 0, 0)
    end

    -- Position bar after icon
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", item, "TOPLEFT", iconSize, 0)
    bar:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)

    -- Resolve Canvas Mode positions (Transaction-aware for live preview)
    local compPositions = CDM:GetComponentPositions(BUFFBAR_INDEX)
    local OU = OrbitEngine.OverrideUtils

    -- StatusBar texture + overlay (global texture setting)
    Orbit.Skin:SkinStatusBar(bar, textureName)

    -- Per-bar color (cycles through BarColor1–BarColor5, same hook pattern as timer text)
    local colorIdx = ((barIndex - 1) % BUFFBAR_MAX_COLORS) + 1
    local colorCurve = CDM:GetSetting(BUFFBAR_INDEX, "BarColor" .. colorIdx)
    local barColor = colorCurve and OrbitEngine.ColorCurve:GetFirstColorFromCurve(colorCurve)
    if not barColor then barColor = BUFFBAR_DEFAULT_COLORS[colorIdx] end
    SetBarColor(bar, barColor.r, barColor.g, barColor.b, barColor.a or 1)

    -- Background
    if not bar.orbitBG then
        bar.orbitBG = bar:CreateTexture(nil, "BACKGROUND")
        bar.orbitBG:SetAllPoints(bar)
    end
    local bg = Constants.Colors.Background
    bar.orbitBG:SetColorTexture(bg.r, bg.g, bg.b, bg.a)

    -- Global backdrop gradient
    local backdropCurve = globals.BackdropColourCurve
    if backdropCurve then
        Orbit.Skin:ApplyGradientBackground(bar, backdropCurve, bg)
    end

    -- Border (global border size)
    if not bar.orbitBorder then
        bar.orbitBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        bar.orbitBorder:SetAllPoints(bar)
        bar.orbitBorder:SetFrameLevel(bar:GetFrameLevel() + 1)
    end
    Orbit.Skin:SkinBorder(bar, bar.orbitBorder, borderSize, { r = 0, g = 0, b = 0, a = 1 }, true)

     -- Hide Blizzard bar chrome
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if bar.Pip then bar.Pip:SetAlpha(0) end

    -- Reparent text to border frame so it renders above backdrop
    if bar.orbitBorder then
        if bar.Name then bar.Name:SetParent(bar.orbitBorder) end
        if bar.Duration then bar.Duration:SetParent(bar.orbitBorder) end
    end

    -- Text styling (global font + adaptive size from bar height)
    local textSize = Orbit.Skin:GetAdaptiveTextSize(barHeight, 8, 14, 0.55)
    local textPad = Pixel:Multiple(BUFFBAR_TEXT_PADDING, scale)
    local textSettings = { textSize = textSize, font = globals.Font, textColor = { r = 1, g = 1, b = 1, a = 1 } }
    if bar.Name then Orbit.Skin:SkinText(bar.Name, textSettings) end
    if bar.Duration then Orbit.Skin:SkinText(bar.Duration, textSettings) end

    -- Apply Canvas Mode text component positions and overrides
    local nameData = compPositions and compPositions["BuffBarName"]
    local timerData = compPositions and compPositions["BuffBarTimer"]
    local nameDisabled = CDM:IsComponentDisabled("BuffBarName", BUFFBAR_INDEX)
    local timerDisabled = CDM:IsComponentDisabled("BuffBarTimer", BUFFBAR_INDEX)
    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition

    if bar.Name then
        bar.Name:SetShown(not nameDisabled)
        if not nameDisabled then
            if not (ApplyTextPosition and nameData and ApplyTextPosition(bar.Name, item, nameData)) then
                bar.Name:ClearAllPoints()
                bar.Name:SetPoint("LEFT", bar, "LEFT", textPad, 0)
                bar.Name:SetPoint("RIGHT", bar.Duration or bar, "LEFT", -textPad, 0)
                bar.Name:SetJustifyH("LEFT")
            end
            if OU and nameData and nameData.overrides then OU.ApplyOverrides(bar.Name, nameData.overrides) end
        end
    end
    if bar.Duration then
        bar.Duration:SetShown(not timerDisabled)
        if not timerDisabled then
            if not (ApplyTextPosition and timerData and ApplyTextPosition(bar.Duration, item, timerData)) then
                bar.Duration:ClearAllPoints()
                bar.Duration:SetPoint("RIGHT", bar, "RIGHT", -textPad, 0)
                bar.Duration:SetJustifyH("RIGHT")
            end
            if OU and timerData and timerData.overrides then OU.ApplyOverrides(bar.Duration, timerData.overrides) end
        end
    end

    -- Icon styling (trim texcoords, square, remove mask)
    if iconFrame then
        local iconTex = iconFrame.Icon
        if iconTex and iconTex.SetTexCoord then
            iconTex:SetTexCoord(BUFFBAR_ICON_TRIM, 1 - BUFFBAR_ICON_TRIM, BUFFBAR_ICON_TRIM, 1 - BUFFBAR_ICON_TRIM)
            if not iconFrame.orbitMaskRemoved then
                for _, region in ipairs({ iconFrame:GetRegions() }) do
                    if region:IsObjectType("MaskTexture") and iconTex.RemoveMaskTexture then
                        iconTex:RemoveMaskTexture(region)
                        region:Hide()
                    end
                end
                iconFrame.orbitMaskRemoved = true
            end
        end
        -- Icon border (global border size)
        if not iconFrame.orbitBorder then
            iconFrame.orbitBorder = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
            iconFrame.orbitBorder:SetAllPoints(iconFrame)
            iconFrame.orbitBorder:SetFrameLevel(iconFrame:GetFrameLevel() + 2)
        end
        Orbit.Skin:SkinBorder(iconFrame, iconFrame.orbitBorder, borderSize, { r = 0, g = 0, b = 0, a = 1 }, true)
        -- Hide Blizzard icon overlay atlas
        if not iconFrame.orbitOverlayHidden then
            for _, region in ipairs({ iconFrame:GetRegions() }) do
                if region:IsObjectType("Texture") and region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
                    region:SetAlpha(0)
                end
            end
            iconFrame.orbitOverlayHidden = true
        end
    end

    -- Hide Blizzard debuff border
    if item.DebuffBorder then item.DebuffBorder:SetAlpha(0); item.DebuffBorder:Hide() end
end


-- [ GROWTH DIRECTION ]------------------------------------------------------------------------------
function CDM:GetGrowthDirection(anchorFrame) local info = GetAnchorInfo(anchorFrame); return info and info.edge == "TOP" and "UP" or "DOWN" end

function CDM:GetHorizontalGrowth(anchorFrame)
    local info = GetAnchorInfo(anchorFrame)
    if not info then return "CENTER" end
    if info.edge == "LEFT" or info.align == "LEFT" then return "RIGHT" end
    if info.edge == "RIGHT" or info.align == "RIGHT" then return "LEFT" end
    return "CENTER"
end

-- [ ASSISTED COMBAT HIGHLIGHT ]---------------------------------------------------------------------
do
    local FLIPBOOK_SCALE = 1.4
    local HIGHLIGHT_PADDING = 6
    local highlightedIcons = {}

    local function GetIconSpellID(icon)
        if icon.orbitCachedSpellID then return icon.orbitCachedSpellID end
        if icon.trackedType == "spell" then return icon.trackedId end
        if icon.GetSpellID then
            local sid = icon:GetSpellID()
            if sid and not issecretvalue(sid) then
                return sid
            end
        end
        return nil
    end

    local function SetHighlightShown(icon, shown)
        local frame = icon.AssistedCombatHighlightFrame
        if shown then
            if not frame then
                frame = CreateFrame("Frame", nil, icon, "ActionBarButtonAssistedCombatHighlightTemplate")
                icon.AssistedCombatHighlightFrame = frame
                frame:SetPoint("CENTER")
                frame.Flipbook.Anim:Play()
                frame.Flipbook.Anim:Stop()
            end
            local w, h = icon:GetSize()
            local pw, ph = w + HIGHLIGHT_PADDING, h + HIGHLIGHT_PADDING
            frame:SetSize(pw, ph)
            frame.Flipbook:SetSize(pw * FLIPBOOK_SCALE, ph * FLIPBOOK_SCALE)
            frame:SetFrameLevel(icon:GetFrameLevel() + 10)
            frame:Show()
            if UnitAffectingCombat("player") then
                frame.Flipbook.Anim:Play()
            else
                frame.Flipbook.Anim:Stop()
            end
        elseif frame then
            frame:Hide()
        end
    end

    local function ClearAll()
        for icon in pairs(highlightedIcons) do SetHighlightShown(icon, false) end
        wipe(highlightedIcons)
    end

    local function IsEnabledForSystem(systemIndex) return CDM:GetSetting(systemIndex, "AssistedHighlight") ~= false end

    local function UpdateHighlights()
        if not AssistedCombatManager or not AssistedCombatManager:IsAssistedHighlightActive() then
            ClearAll()
            return
        end
        local nextSpell = AssistedCombatManager.lastNextCastSpellID
        ClearAll()
        if not nextSpell then return end

        for systemIndex, entry in pairs(VIEWER_MAP) do
            if IsEnabledForSystem(systemIndex) then
                if entry.viewer then
                    for _, child in ipairs(PackChildren(entry.viewer:GetChildren())) do
                        if child:IsShown() and GetIconSpellID(child) == nextSpell then
                            SetHighlightShown(child, true)
                            highlightedIcons[child] = true
                        end
                    end
                end
                if entry.anchor and entry.anchor.activeIcons then
                    for _, icon in pairs(entry.anchor.activeIcons) do
                        if icon:IsShown() and GetIconSpellID(icon) == nextSpell then
                            SetHighlightShown(icon, true)
                            highlightedIcons[icon] = true
                        end
                    end
                end
            end
        end

        for _, childData in pairs(CDM.activeChildren or {}) do
            if childData.frame and childData.frame.activeIcons then
                local csi = childData.frame.systemIndex
                if not csi or IsEnabledForSystem(csi) then
                    for _, icon in pairs(childData.frame.activeIcons) do
                        if icon:IsShown() and GetIconSpellID(icon) == nextSpell then
                            SetHighlightShown(icon, true)
                            highlightedIcons[icon] = true
                        end
                    end
                end
            end
        end
    end

    local function SyncFromCVar()
        local enabled = AssistedCombatManager and AssistedCombatManager:IsAssistedHighlightActive() or false
        for systemIndex in pairs(VIEWER_MAP) do
            CDM:SetSetting(systemIndex, "AssistedHighlight", enabled)
        end
        UpdateHighlights()
    end

    CDM.UpdateAssistedHighlights = UpdateHighlights

    EventRegistry:RegisterCallback("AssistedCombatManager.OnAssistedHighlightSpellChange", UpdateHighlights, CDM)
    EventRegistry:RegisterCallback("AssistedCombatManager.OnSetUseAssistedHighlight", SyncFromCVar, CDM)
    EventRegistry:RegisterFrameEventAndCallback("PLAYER_REGEN_ENABLED", UpdateHighlights, "OrbitCDM_AssistedRegen")
    EventRegistry:RegisterFrameEventAndCallback("PLAYER_REGEN_DISABLED", UpdateHighlights, "OrbitCDM_AssistedRegen")
end
