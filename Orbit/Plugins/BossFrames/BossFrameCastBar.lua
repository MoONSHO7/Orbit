-- [ BOSS FRAME CAST BAR ]--------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

Orbit.BossFrameCastBar = {}
local CB = Orbit.BossFrameCastBar

local Pixel = Orbit.Engine.Pixel
local CAST_BAR_WIDTH = 150
local CAST_BAR_HEIGHT = 14
local CAST_BAR_ICON_SIZE = 14

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
    -- Container holds the icon + bar with a single unified border (matches Skin.CastBar pattern)
    local container = CreateFrame("Frame", "OrbitBoss" .. bossIndex .. "CastBarContainer", parent)
    container:SetSize(CAST_BAR_WIDTH + CAST_BAR_ICON_SIZE, CAST_BAR_HEIGHT)
    container:Hide()

    -- Background on container (fills behind both icon and bar uniformly, matching Skin.CastBar pattern)
    container.bg = container:CreateTexture(nil, "BACKGROUND")
    container.bg:SetAllPoints()
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(container, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)

    -- Icon: anchored to the left edge of the container (positioned by UpdateBarInsets)
    container.Icon = container:CreateTexture(nil, "ARTWORK", nil, Orbit.Constants.Layers.Icon)
    container.Icon:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Icon)
    container.Icon:SetSize(CAST_BAR_ICON_SIZE, CAST_BAR_ICON_SIZE)
    container.Icon:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    container.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    -- StatusBar: fills the space to the right of the icon (positioned by UpdateBarInsets)
    local bar = CreateFrame("StatusBar", "OrbitBoss" .. bossIndex .. "CastBar", container)
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", CAST_BAR_ICON_SIZE, 0)
    bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    bar:SetStatusBarColor(1, 0.7, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetClipsChildren(true)

    -- Single unified border on container (wraps icon + bar together)
    container.SetBorder = function(self, size)
        Orbit.Skin:SkinBorder(self, self, size)
        -- BackdropTemplate has a default opaque background; clear it so the icon area stays transparent
        if self._borderFrame then self._borderFrame:SetBackdropColor(0, 0, 0, 0) end
        if self._edgeBorderOverlay then self._edgeBorderOverlay:SetBackdropColor(0, 0, 0, 0) end
        self:UpdateBarInsets()
    end
    container.SetBorderHidden = Orbit.Skin.DefaultSetBorderHidden

    -- UpdateBarInsets: positions bar content to the right of the icon (matches Skin.CastBar pattern)
    container.UpdateBarInsets = function(self)
        local height = self:GetHeight()
        local scale = self:GetEffectiveScale()
        local showIcon = self.Icon and self.Icon:IsShown()
        local iconSize = showIcon and Pixel:Snap(height, scale) or 0
        if self.Icon then
            self.Icon:ClearAllPoints()
            self.Icon:SetSize(iconSize, iconSize)
            self.Icon:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        end
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", self, "TOPLEFT", iconSize, 0)
        bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
    end

    container:SetBorder(1)
    container:HookScript("OnSizeChanged", function(self) self:UpdateBarInsets() end)

    -- Protected overlay: mirrors bar for non-interruptible color
    bar.protectedOverlay = CreateFrame("StatusBar", nil, bar)
    bar.protectedOverlay:SetAllPoints(bar)
    bar.protectedOverlay:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    bar.protectedOverlay:SetMinMaxValues(0, 1)
    bar.protectedOverlay:SetValue(0)
    bar.protectedOverlay:SetFrameLevel(bar:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
    bar.protectedOverlay:SetAlpha(0)

    -- Text overlay
    local textOverlay = CreateFrame("Frame", nil, bar)
    textOverlay:SetAllPoints()
    textOverlay:SetFrameLevel(bar:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
    textOverlay:EnableMouse(false)

    container.Text = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    container.Text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    container.Text:SetJustifyH("LEFT")
    Orbit.Skin:ApplyFontShadow(container.Text)

    container.Timer = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    container.Timer:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    container.Timer:SetJustifyH("RIGHT")
    Orbit.Skin:ApplyFontShadow(container.Timer)

    -- Store references on container for external access
    container.Bar = bar
    container.protectedOverlay = bar.protectedOverlay
    container.bossIndex = bossIndex
    container.unit = "boss" .. bossIndex
    container.plugin = plugin
    return container
end

-- [ STANDALONE EVENT-DRIVEN CAST BAR ]--------------------------------------------------------------
local TIMER_THROTTLE_INTERVAL = 1 / 30
local INTERRUPT_FLASH_DURATION = Orbit.Constants.Timing.FlashDuration

local function ApplyIconLayout(castBar, plugin)
    if castBar.Icon then castBar.Icon:Show() end
    if castBar.UpdateBarInsets then castBar:UpdateBarInsets() end
    local showText = plugin:GetSetting(1, "CastBarText")
    local textDisabled = plugin.IsComponentDisabled and plugin:IsComponentDisabled("CastBar.Text")
    if castBar.Text then
        castBar.Text:ClearAllPoints()
        if showText and not textDisabled then
            castBar.Text:Show()
            castBar.Text:SetPoint("LEFT", castBar.Bar, "LEFT", 4, 0)
        else
            castBar.Text:Hide()
        end
    end
    local showTimer = plugin:GetSetting(1, "CastBarTimer")
    local timerDisabled = plugin.IsComponentDisabled and plugin:IsComponentDisabled("CastBar.Timer")
    if castBar.Timer then castBar.Timer:SetShown(showTimer and not timerDisabled) end
end

function CB:SetupHooks(castBar, unit)
    local plugin = castBar.plugin
    castBar.casting = false
    castBar.channeling = false
    castBar.durationObj = nil
    castBar.timerThrottle = 0
    castBar.castTimestamp = 0

    -- Cast: query the unit directly for cast info, drive bar via SetTimerDuration
    local function Cast()
        if plugin.IsComponentDisabled and plugin:IsComponentDisabled("CastBar") then return end
        local name, text, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
        local isChanneled = false
        if not name then
            name, text, texture, _, _, _, notInterruptible = UnitChannelInfo(unit)
            if name then isChanneled = true end
        end
        if not name then
            castBar.casting = false
            castBar.channeling = false
            castBar.durationObj = nil
            if castBar.protectedOverlay then castBar.protectedOverlay:SetAlpha(0) end
            castBar:Hide()
            return
        end
        local getDurationFn = isChanneled and UnitChannelDuration or UnitCastingDuration
        local durationObj
        if type(getDurationFn) == "function" then
            local ok, dur = pcall(getDurationFn, unit)
            if ok then durationObj = dur end
        end
        if not durationObj then
            castBar.casting = false
            castBar.channeling = false
            castBar.durationObj = nil
            castBar:Hide()
            return
        end
        castBar.casting = not isChanneled
        castBar.channeling = isChanneled
        castBar.castTimestamp = GetTime()
        castBar.durationObj = durationObj
        castBar.timerThrottle = 0
        local direction = isChanneled and 1 or 0
        local bar = castBar.Bar
        if bar and bar.SetTimerDuration then
            pcall(bar.SetTimerDuration, bar, durationObj, 0, direction)
        end
        -- Protected overlay for non-interruptible casts
        local overlay = castBar.protectedOverlay
        if overlay then
            if overlay.SetTimerDuration then
                pcall(overlay.SetTimerDuration, overlay, durationObj, 0, direction)
            end
            if name then
                if type(overlay.SetAlphaFromBoolean) == "function" then
                    overlay:SetAlphaFromBoolean(notInterruptible, 1, 0)
                else
                    pcall(overlay.SetAlpha, overlay, 1)
                end
            else
                overlay:SetAlpha(0)
            end
        end
        local color = ResolveCastBarColor(plugin)
        castBar.Bar:SetStatusBarColor(color.r, color.g, color.b)
        if overlay then
            local pColor = ResolveNonInterruptibleColor(plugin)
            overlay:SetStatusBarColor(pColor.r, pColor.g, pColor.b)
            local textureName = plugin:GetSetting(1, "Texture") or plugin:GetPlayerSetting("Texture")
            if textureName then
                local texPath = LSM:Fetch("statusbar", textureName)
                if texPath then overlay:SetStatusBarTexture(texPath) end
            end
        end
        -- Icon
        ApplyIconLayout(castBar, plugin)
        if castBar.Icon and castBar.Icon:IsShown() then
            pcall(function() castBar.Icon:SetTexture(texture or 136116) end)
        end
        -- Text
        if castBar.Text and castBar.Text:IsShown() then
            pcall(function() castBar.Text:SetText(name) end)
        end
        castBar:Show()
    end

    local function StopCast()
        castBar.casting = false
        castBar.channeling = false
        castBar.durationObj = nil
        if castBar.protectedOverlay then castBar.protectedOverlay:SetAlpha(0) end
        castBar:Hide()
    end

    -- Register cast events directly on the castBar frame
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)

    local dispatch = {
        UNIT_SPELLCAST_START = Cast,
        UNIT_SPELLCAST_CHANNEL_START = Cast,
        UNIT_SPELLCAST_DELAYED = Cast,
        UNIT_SPELLCAST_CHANNEL_UPDATE = Cast,
        UNIT_SPELLCAST_STOP = StopCast,
        UNIT_SPELLCAST_CHANNEL_STOP = StopCast,
        UNIT_SPELLCAST_INTERRUPTED = StopCast,
        UNIT_SPELLCAST_FAILED = function()
            if UnitChannelInfo(unit) or UnitCastingInfo(unit) then return end
            local failTimestamp = castBar.castTimestamp
            castBar.casting = false
            castBar.channeling = false
            castBar.durationObj = nil
            castBar.Bar:SetStatusBarColor(1, 0, 0)
            if castBar.protectedOverlay then castBar.protectedOverlay:SetAlpha(0) end
            C_Timer.After(INTERRUPT_FLASH_DURATION, function()
                if castBar.castTimestamp == failTimestamp and not castBar.casting and not castBar.channeling then
                    StopCast()
                end
            end)
        end,
        UNIT_SPELLCAST_INTERRUPTIBLE = function()
            local color = ResolveCastBarColor(plugin)
            castBar.Bar:SetStatusBarColor(color.r, color.g, color.b)
            if castBar.protectedOverlay then
                local n, _, _, _, _, _, _, ni = UnitCastingInfo(unit)
                if not n then _, _, _, _, _, _, ni = UnitChannelInfo(unit) end
                if n and type(castBar.protectedOverlay.SetAlphaFromBoolean) == "function" then
                    castBar.protectedOverlay:SetAlphaFromBoolean(ni, 1, 0)
                else
                    castBar.protectedOverlay:SetAlpha(0)
                end
            end
        end,
        UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function()
            if castBar.protectedOverlay then
                local n, _, _, _, _, _, _, ni = UnitCastingInfo(unit)
                if not n then _, _, _, _, _, _, ni = UnitChannelInfo(unit) end
                if n and type(castBar.protectedOverlay.SetAlphaFromBoolean) == "function" then
                    castBar.protectedOverlay:SetAlphaFromBoolean(ni, 1, 0)
                elseif n then
                    pcall(castBar.protectedOverlay.SetAlpha, castBar.protectedOverlay, 1)
                end
            end
        end,
    }

    castBar:SetScript("OnEvent", function(_, event)
        local handler = dispatch[event]
        if handler then handler() end
    end)

    -- OnUpdate: timer text only (bar progress is engine-driven via SetTimerDuration)
    castBar:SetScript("OnUpdate", function(self, elapsed)
        if not self:IsShown() or (not self.casting and not self.channeling) then return end
        self.timerThrottle = (self.timerThrottle or 0) + elapsed
        if self.timerThrottle < TIMER_THROTTLE_INTERVAL then return end
        self.timerThrottle = 0
        if not self.Timer or not self.Timer:IsShown() then return end
        if not self.durationObj then return end
        local getter = self.durationObj.GetRemainingDuration or self.durationObj.GetRemaining
        if not getter then return end
        local ok, remaining = pcall(getter, self.durationObj)
        if ok then pcall(self.Timer.SetFormattedText, self.Timer, "%.1f", remaining) end
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
