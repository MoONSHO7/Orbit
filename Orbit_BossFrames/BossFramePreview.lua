local Orbit = Orbit
local LSM = LibStub("LibSharedMedia-3.0")

Orbit.BossFramePreviewMixin = {}
local Helpers = nil

local MAX_BOSS_FRAMES = 5
local POWER_BAR_HEIGHT_RATIO = 0.2
local DEBOUNCE_DELAY = Orbit.Constants.Timing.DefaultDebounce

local PREVIEW_DEFAULTS = {
    Width = 150,
    Height = 40,
    CastBarHeight = 14,
    HealthPercent = 75,
    PowerPercent = 50,
    CastDuration = 3,
    CastProgress = 1.5,
    DebuffSpacing = 2,
    ElementGap = 4,
    ContainerGap = 4,
    FakeCooldownElapsed = 10,
    FakeCooldownDuration = 60,
}

local SAMPLE_DEBUFF_ICONS = { 136096, 136118, 132158, 136048, 132212 }

-- [ PREVIEW LOGIC ]
function Orbit.BossFramePreviewMixin:ShowPreview()
    if InCombatLockdown() or not self.frames or not self.container then
        return
    end

    self.isPreviewActive = true

    UnregisterAttributeDriver(self.container, "state-visibility")
    self.container:Show()

    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] then
            UnregisterUnitWatch(self.frames[i])
        end
    end

    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] then
            self.frames[i].preview = true
            self.frames[i]:Show()
        end
    end
    self:PositionFrames()
    self:UpdateContainerSize()
    self:UpdateContainerSize()

    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.frames then
            self:ApplyPreviewVisuals()
        end
    end)
end

function Orbit.BossFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then
        return
    end

    local width = self:GetSetting(1, "Width") or PREVIEW_DEFAULTS.Width
    local height = self:GetSetting(1, "Height") or PREVIEW_DEFAULTS.Height
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 4

    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] and self.frames[i].preview then
            local frame = self.frames[i]
            frame:SetSize(width, height)
            if self.ApplyPreviewBackdrop then
                self:ApplyPreviewBackdrop(frame)
            end

            if frame.Health then
                frame.Health:ClearAllPoints()
                frame.Health:SetPoint("TOPLEFT", 1, -1)
                frame.Health:SetPoint("BOTTOMRIGHT", -1, height * POWER_BAR_HEIGHT_RATIO + 1)
                Orbit.Skin:SkinStatusBar(frame.Health, textureName, nil, true)
                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(PREVIEW_DEFAULTS.HealthPercent)
                if self.GetPreviewHealthColor then
                    local r, g, b = self:GetPreviewHealthColor(false, nil, 1)
                    frame.Health:SetStatusBarColor(r, g, b)
                else
                    frame.Health:SetStatusBarColor(1, 0.1, 0.1)
                end
                frame.Health:Show()
            end

            if frame.Power then
                frame.Power:ClearAllPoints()
                frame.Power:SetPoint("BOTTOMLEFT", 1, 1)
                frame.Power:SetPoint("BOTTOMRIGHT", -1, 1)
                frame.Power:SetHeight(height * POWER_BAR_HEIGHT_RATIO)
                Orbit.Skin:SkinStatusBar(frame.Power, textureName, nil, true)
                frame.Power:SetMinMaxValues(0, 100)
                frame.Power:SetValue(PREVIEW_DEFAULTS.PowerPercent)
                frame.Power:SetStatusBarColor(0, 0.5, 1)
                frame.Power:Show()
            end

            if frame.Name then
                frame.Name:SetText("Boss " .. i)
                if self.GetPreviewTextColor then
                    local r, g, b, a = self:GetPreviewTextColor(false, nil, 1)
                    frame.Name:SetTextColor(r, g, b, a)
                else
                    frame.Name:SetTextColor(1, 0.1, 0.1, 1)
                end
                frame.Name:Show()
            end

            if frame.HealthText then
                frame.HealthText:SetText(PREVIEW_DEFAULTS.HealthPercent .. "%")
                if self.GetPreviewTextColor then
                    local r, g, b, a = self:GetPreviewTextColor(false, nil, 1)
                    frame.HealthText:SetTextColor(r, g, b, a)
                else
                    frame.HealthText:SetTextColor(1, 0.1, 0.1, 1)
                end
                frame.HealthText:Show()
            end

            if frame.CastBar then
                local castBarHeight = self:GetSetting(1, "CastBarHeight") or PREVIEW_DEFAULTS.CastBarHeight
                local castBarPosition = self:GetSetting(1, "CastBarPosition") or "Below"
                local showIcon = self:GetSetting(1, "CastBarIcon")
                local iconOffset = 0
                frame.CastBar:SetSize(width, castBarHeight)
                frame.CastBar:SetStatusBarTexture(texturePath)
                frame.CastBar:SetMinMaxValues(0, PREVIEW_DEFAULTS.CastDuration)
                frame.CastBar:SetValue(PREVIEW_DEFAULTS.CastProgress)
                frame.CastBar.unit = "preview"
                self:PositionCastBar(frame.CastBar, frame, castBarPosition)

                if frame.CastBar.Icon then
                    if showIcon then
                        frame.CastBar.Icon:SetTexture(136243)
                        frame.CastBar.Icon:SetSize(castBarHeight, castBarHeight)
                        frame.CastBar.Icon:Show()
                        iconOffset = castBarHeight
                        if frame.CastBar.IconBorder then
                            frame.CastBar.IconBorder:Show()
                        end
                    else
                        frame.CastBar.Icon:Hide()
                        if frame.CastBar.IconBorder then
                            frame.CastBar.IconBorder:Hide()
                        end
                    end
                end

                local statusBarTexture = frame.CastBar:GetStatusBarTexture()
                if statusBarTexture then
                    statusBarTexture:ClearAllPoints()
                    statusBarTexture:SetPoint("TOPLEFT", frame.CastBar, "TOPLEFT", iconOffset, 0)
                    statusBarTexture:SetPoint("BOTTOMLEFT", frame.CastBar, "BOTTOMLEFT", iconOffset, 0)
                    statusBarTexture:SetPoint("TOPRIGHT", frame.CastBar, "TOPRIGHT", 0, 0)
                    statusBarTexture:SetPoint("BOTTOMRIGHT", frame.CastBar, "BOTTOMRIGHT", 0, 0)
                end
                if frame.CastBar.bg then
                    frame.CastBar.bg:ClearAllPoints()
                    frame.CastBar.bg:SetPoint("TOPLEFT", frame.CastBar, "TOPLEFT", iconOffset, 0)
                    frame.CastBar.bg:SetPoint("BOTTOMRIGHT", frame.CastBar, "BOTTOMRIGHT", 0, 0)
                end

                if frame.CastBar.Text then
                    frame.CastBar.Text:ClearAllPoints()
                    if showIcon and frame.CastBar.Icon then
                        frame.CastBar.Text:SetPoint("LEFT", frame.CastBar.Icon, "RIGHT", 4, 0)
                    else
                        frame.CastBar.Text:SetPoint("LEFT", frame.CastBar, "LEFT", 4, 0)
                    end
                    frame.CastBar.Text:SetText("Boss Ability (Preview)")
                end
                if frame.CastBar.Timer then
                    frame.CastBar.Timer:SetText(tostring(PREVIEW_DEFAULTS.CastProgress))
                end
                frame.CastBar:Show()
            end

            self:ShowPreviewDebuffs(frame, maxDebuffs)
        end
    end
end

function Orbit.BossFramePreviewMixin:ShowPreviewDebuffs(frame, numDebuffsToShow)
    local position = self:GetSetting(1, "DebuffPosition")
    if position == "Disabled" then
        if frame.debuffContainer then
            frame.debuffContainer:Hide()
            frame.debuffContainer:SetSize(0, 0)
        end
        return
    end

    local isHorizontal = (position == "Above" or position == "Below")
    local frameHeight, frameWidth = frame:GetHeight(), frame:GetWidth()
    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 4
    local numDebuffs = math.min(numDebuffsToShow, maxDebuffs, #SAMPLE_DEBUFF_ICONS)
    local spacing = PREVIEW_DEFAULTS.DebuffSpacing
    if numDebuffs == 0 then
        return
    end
    if not Helpers then
        Helpers = Orbit.BossFrameHelpers
    end
    local iconSize, xOffsetStep = Helpers:CalculateDebuffLayout(isHorizontal, frameWidth, frameHeight, maxDebuffs, spacing)
    if not frame.previewDebuffs then
        frame.previewDebuffs = {}
    end
    for _, icon in ipairs(frame.previewDebuffs) do
        icon:Hide()
    end

    if not frame.debuffContainer then
        frame.debuffContainer = CreateFrame("Frame", nil, frame)
    else
        frame.debuffContainer:SetParent(frame)
    end
    frame.debuffContainer:SetFrameStrata("MEDIUM")
    frame.debuffContainer:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Highlight)
    frame.debuffContainer:Show()

    local castBarPos = self:GetSetting(1, "CastBarPosition")
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or PREVIEW_DEFAULTS.CastBarHeight
    Helpers:PositionDebuffContainer(frame.debuffContainer, frame, position, numDebuffs, iconSize, spacing, castBarPos, castBarHeight)

    local globalBorder = Orbit.db.GlobalSettings.BorderSize
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = true }
    local currentX = 0
    for i = 1, numDebuffs do
        local icon = frame.previewDebuffs[i]
        if not icon then
            icon = CreateFrame("Button", nil, frame.debuffContainer, "BackdropTemplate")
            icon.Icon = icon:CreateTexture(nil, "ARTWORK")
            icon.Icon:SetAllPoints()
            icon.icon = icon.Icon
            icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
            icon.Cooldown:SetAllPoints()
            icon.Cooldown:SetHideCountdownNumbers(false)
            icon.cooldown = icon.Cooldown
            frame.previewDebuffs[i] = icon
        end
        icon:SetSize(iconSize, iconSize)
        currentX = Helpers:PositionDebuffIcon(icon, frame.debuffContainer, isHorizontal, position, currentX, iconSize, xOffsetStep, spacing)
        local iconIndex = ((i - 1) % #SAMPLE_DEBUFF_ICONS) + 1
        icon.Icon:SetTexture(SAMPLE_DEBUFF_ICONS[iconIndex])
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
        end
        icon.Cooldown:SetCooldown(GetTime() - PREVIEW_DEFAULTS.FakeCooldownElapsed, PREVIEW_DEFAULTS.FakeCooldownDuration)
        icon.Cooldown:Show()
        icon:Show()
    end
    if not InCombatLockdown() then
        self:PositionFrames()
    end
end

function Orbit.BossFramePreviewMixin:HidePreview()
    if InCombatLockdown() or not self.frames then
        return
    end
    self.isPreviewActive = false
    local visibilityDriver = "[@boss1,exists] show; [@boss2,exists] show; [@boss3,exists] show; [@boss4,exists] show; [@boss5,exists] show; hide"
    RegisterAttributeDriver(self.container, "state-visibility", visibilityDriver)

    for i, frame in ipairs(self.frames) do
        frame.preview = nil
        frame:SetAlpha(1)
        RegisterUnitWatch(frame)
        if frame.previewDebuffs then
            for _, icon in ipairs(frame.previewDebuffs) do
                icon:Hide()
                icon:ClearAllPoints()
            end
            wipe(frame.previewDebuffs)
        end
        if frame.CastBar then
            frame.CastBar:Hide()
        end
    end
    self:UpdateContainerSize()
end

function Orbit.BossFramePreviewMixin:SchedulePreviewUpdate()
    if not self._previewVisualsScheduled then
        self._previewVisualsScheduled = true
        C_Timer.After(DEBOUNCE_DELAY, function()
            self._previewVisualsScheduled = false
            if self.frames then
                self:ApplyPreviewVisuals()
            end
        end)
    end
end
