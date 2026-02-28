-- [ BOSS FRAME CAST BAR ]--------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

Orbit.BossFrameCastBar = {}
local CB = Orbit.BossFrameCastBar

local function ResolveCastBarColor(plugin)
    return OrbitEngine.ColorCurve:GetFirstColorFromCurve(plugin:GetSetting(1, "CastBarColorCurve"))
        or plugin:GetSetting(1, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
end

local function ResolveNonInterruptibleColor(plugin)
    return OrbitEngine.ColorCurve:GetFirstColorFromCurve(plugin:GetSetting(1, "NonInterruptibleColorCurve"))
        or plugin:GetSetting(1, "NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
end

CB.ResolveCastBarColor = ResolveCastBarColor
CB.ResolveNonInterruptibleColor = ResolveNonInterruptibleColor

function CB:Create(parent, bossIndex, plugin)
    local bar = CreateFrame("StatusBar", "OrbitBoss" .. bossIndex .. "CastBar", parent)
    bar:SetSize(150, 14)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    bar:SetStatusBarColor(1, 0.7, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(bar, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)

    bar.SetBorder = function(self, size) Orbit.Skin:SkinBorder(self, self, size, nil, true) end
    bar:SetBorder(1)

    bar.Icon = bar:CreateTexture(nil, "ARTWORK", nil, Orbit.Constants.Layers.Icon)
    bar.Icon:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Icon)
    bar.Icon:SetSize(14, 14)
    bar.Icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    bar.Icon:Hide()

    bar.IconBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.IconBorder:SetAllPoints(bar.Icon)
    bar.IconBorder:SetFrameLevel(bar:GetFrameLevel() + Orbit.Constants.Levels.Border)
    Orbit.Skin:SkinBorder(bar, bar.IconBorder, 1, { r = 0, g = 0, b = 0, a = 1 }, true)
    bar.IconBorder:Hide()

    bar.TextOverlay = CreateFrame("Frame", nil, bar)
    bar.TextOverlay:SetAllPoints()
    bar.TextOverlay:SetFrameLevel(bar:GetFrameLevel() + (Orbit.Constants.Levels.Border or 3) + 1)
    bar.TextOverlay:EnableMouse(false)

    bar.Text = bar.TextOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.Text:SetJustifyH("LEFT")
    bar.Text:SetShadowColor(0, 0, 0, 1)
    bar.Text:SetShadowOffset(1, -1)

    bar.Timer = bar.TextOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Timer:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.Timer:SetJustifyH("RIGHT")
    bar.Timer:SetShadowColor(0, 0, 0, 1)
    bar.Timer:SetShadowOffset(1, -1)

    bar.bossIndex = bossIndex
    bar.unit = "boss" .. bossIndex
    bar.plugin = plugin
    return bar
end

function CB:SetupHooks(castBar, unit)
    local nativeSpellbar = _G["Boss" .. castBar.bossIndex .. "TargetFrameSpellBar"]
    if not nativeSpellbar then return end
    local plugin = castBar.plugin
    local TIMER_THROTTLE_INTERVAL = 1 / 30

    nativeSpellbar:HookScript("OnShow", function(nativeBar)
        if not castBar then return end
        local showIcon = plugin:GetSetting(1, "CastBarIcon")
        local castBarHeight = castBar:GetHeight()
        local iconOffset = 0
        local iconTexture
        if nativeBar.Icon then iconTexture = nativeBar.Icon:GetTexture() end
        if not iconTexture and C_Spell.GetSpellTexture and nativeBar.spellID then iconTexture = C_Spell.GetSpellTexture(nativeBar.spellID) end
        if castBar.Icon then
            if showIcon then
                castBar.Icon:SetTexture(iconTexture or 136243)
                castBar.Icon:SetSize(castBarHeight, castBarHeight)
                castBar.Icon:Show()
                iconOffset = castBarHeight
                if castBar.IconBorder then castBar.IconBorder:Show() end
                if castBar.Borders and castBar.Borders.Left then castBar.Borders.Left:Hide() end
            else
                castBar.Icon:Hide()
                if castBar.IconBorder then castBar.IconBorder:Hide() end
                if castBar.Borders and castBar.Borders.Left then castBar.Borders.Left:Show() end
            end
        end
        local statusBarTexture = castBar:GetStatusBarTexture()
        if statusBarTexture then
            statusBarTexture:ClearAllPoints()
            statusBarTexture:SetPoint("TOPLEFT", castBar, "TOPLEFT", iconOffset, 0)
            statusBarTexture:SetPoint("BOTTOMLEFT", castBar, "BOTTOMLEFT", iconOffset, 0)
            statusBarTexture:SetPoint("TOPRIGHT", castBar, "TOPRIGHT", 0, 0)
            statusBarTexture:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
        end
        if castBar.bg then
            castBar.bg:ClearAllPoints()
            castBar.bg:SetPoint("TOPLEFT", castBar, "TOPLEFT", iconOffset, 0)
            castBar.bg:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
        end
        local showText = plugin:GetSetting(1, "CastBarText")
        local textDisabled = plugin.IsComponentDisabled and plugin:IsComponentDisabled("CastBar.Text")
        if castBar.Text then
            castBar.Text:ClearAllPoints()
            if showText and not textDisabled then
                castBar.Text:Show()
                if showIcon and castBar.Icon then castBar.Text:SetPoint("LEFT", castBar.Icon, "RIGHT", 4, 0)
                else castBar.Text:SetPoint("LEFT", castBar, "LEFT", 4, 0) end
                if nativeBar.Text then castBar.Text:SetText(nativeBar.Text:GetText() or "Casting...") end
            else castBar.Text:Hide() end
        end
        local showTimer = plugin:GetSetting(1, "CastBarTimer")
        local timerDisabled = plugin.IsComponentDisabled and plugin:IsComponentDisabled("CastBar.Timer")
        if castBar.Timer then castBar.Timer:SetShown(showTimer and not timerDisabled) end
        local min, max = nativeBar:GetMinMaxValues()
        if min and max then castBar:SetMinMaxValues(min, max); castBar:SetValue(nativeBar:GetValue() or 0) end
        local color = nativeBar.notInterruptible and ResolveNonInterruptibleColor(plugin) or ResolveCastBarColor(plugin)
        castBar:SetStatusBarColor(color.r, color.g, color.b)
        if plugin.IsComponentDisabled and plugin:IsComponentDisabled("CastBar") then return end
        castBar:Show()
    end)

    nativeSpellbar:HookScript("OnHide", function() if castBar then castBar:Hide() end end)

    local timerThrottle = 0
    nativeSpellbar:HookScript("OnUpdate", function(nativeBar, elapsed)
        if not castBar or not castBar:IsShown() then return end
        local progress = nativeBar:GetValue()
        local min, max = nativeBar:GetMinMaxValues()
        if not progress or not max then return end
        castBar:SetMinMaxValues(min, max)
        castBar:SetValue(progress)
        timerThrottle = timerThrottle + elapsed
        if timerThrottle < TIMER_THROTTLE_INTERVAL then return end
        timerThrottle = 0
        if not castBar.Timer or not castBar.Timer:IsShown() then return end
        local getDurationFn = nativeBar.channeling and UnitChannelDuration or UnitCastingDuration
        if not getDurationFn then return end
        local ok, dur = pcall(getDurationFn, unit)
        if not ok or not dur then return end
        local getter = dur.GetRemainingDuration or dur.GetRemaining
        if not getter then return end
        local okR, remaining = pcall(getter, dur)
        if okR and remaining then castBar.Timer:SetFormattedText("%.1f", remaining) end
    end)

    nativeSpellbar:HookScript("OnEvent", function(nativeBar, event, eventUnit)
        if eventUnit ~= unit or not castBar or not castBar:IsShown() then return end
        if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            castBar:SetStatusBarColor(1, 0, 0)
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            local color = ResolveNonInterruptibleColor(plugin)
            castBar:SetStatusBarColor(color.r, color.g, color.b)
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            local color = ResolveCastBarColor(plugin)
            castBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    end)
end

function CB:Position(castBar, parent, plugin)
    if not castBar or not parent then return end
    local componentPositions = plugin:GetSetting(1, "ComponentPositions") or {}
    local castData = componentPositions.CastBar
    castBar:ClearAllPoints()
    if castData and castData.anchorY then
        local anchorX = castData.anchorX or "CENTER"
        local anchorY = castData.anchorY or "BOTTOM"
        local offsetX = castData.offsetX or 0
        local offsetY = castData.offsetY or 0
        local justifyH = castData.justifyH or "CENTER"
        local anchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)
        local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(false, false, anchorY, justifyH)
        if anchorX == "RIGHT" then offsetX = -offsetX end
        if anchorY == "TOP" then offsetY = -offsetY end
        castBar:SetPoint(selfAnchor, parent, anchorPoint, offsetX, offsetY)
    else
        castBar:SetPoint("TOP", parent, "BOTTOM", 0, -2)
    end
end
