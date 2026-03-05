local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

Orbit.BossFramePreviewMixin = {}
local Helpers = nil

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_BOSS_FRAMES = 5
local POWER_BAR_HEIGHT_RATIO = 0.2
local DEBOUNCE_DELAY = Orbit.Constants.Timing.DefaultDebounce

local MARKER_ICON_SIZE = 16


local PREVIEW_DEFAULTS = {
    Width = 150,
    Height = 40,
    CastBarHeight = 14,
    HealthPercent = 75,
    PowerPercent = 50,
    CastDuration = 3,
    CastProgress = 1.5,
    FakeCooldownElapsed = 10,
    FakeCooldownDuration = 60,
}

-- [ PREVIEW LOGIC ]---------------------------------------------------------------------------------
function Orbit.BossFramePreviewMixin:ShowPreview()
    if InCombatLockdown() or not self.frames or not self.container then return end
    self.isPreviewActive = true

    UnregisterAttributeDriver(self.container, "state-visibility")
    self.container:Show()

    local isCanvasMode = false
    if OrbitEngine and OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then
        for _, frame in ipairs(self.frames) do
            if OrbitEngine.CanvasMode.currentFrame == frame or OrbitEngine.CanvasMode.currentFrame == self.container then
                isCanvasMode = true
                break
            end
        end
    end

    local framesToShow = isCanvasMode and 1 or MAX_BOSS_FRAMES

    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] then
            UnregisterUnitWatch(self.frames[i])
            if i <= framesToShow then
                self.frames[i].preview = true
                self.frames[i]:Show()
            else
                self.frames[i].preview = nil
                self.frames[i]:Hide()
            end
        end
    end
    self:PositionFrames()
    self:UpdateContainerSize()

    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.frames then
            self:ApplyPreviewVisuals()
            if not isCanvasMode then self:StartPreviewAnimation() end
        end
    end)

    -- Listen for live Canvas Mode edits
    if not self._canvasSettingsCallback then
        self._canvasSettingsCallback = function(targetPlugin)
            if targetPlugin ~= self then return end
            if self.frames and self.frames[1] and self.frames[1].preview then
                self:SchedulePreviewUpdate()
            end
        end
    end
    Orbit.EventBus:On("CANVAS_SETTINGS_CHANGED", self._canvasSettingsCallback)
end

function Orbit.BossFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then return end
    if not Helpers then Helpers = Orbit.BossFrameHelpers end

    local width = self:GetSetting(1, "Width") or PREVIEW_DEFAULTS.Width
    local height = self:GetSetting(1, "Height") or PREVIEW_DEFAULTS.Height
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
    local borderSize = self:GetSetting(1, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(self.container:GetEffectiveScale() or 1)

    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] and self.frames[i].preview then
            local frame = self.frames[i]
            frame:SetSize(width, height)

            local Txn = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.Transaction
            local txnActive = Txn and Txn:IsActive() and Txn:GetPlugin() == self
            local componentPositions = txnActive and Txn:GetPositions() or self:GetSetting(1, "ComponentPositions") or {}

            self:UpdateFrameLayout(frame, borderSize, { powerBarRatio = POWER_BAR_HEIGHT_RATIO })

            if self.ApplyPreviewBackdrop then self:ApplyPreviewBackdrop(frame) end

            if frame.Health then
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
                Orbit.Skin:SkinStatusBar(frame.Power, textureName, nil, true)
                frame.Power:SetMinMaxValues(0, 100)
                frame.Power:SetValue(PREVIEW_DEFAULTS.PowerPercent)
                frame.Power:SetStatusBarColor(0, 0.5, 1)
                local globalSettings = Orbit.db.GlobalSettings or {}
                Orbit.Skin:ApplyGradientBackground(frame.Power, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)
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

            if self.ApplyTextStyling then self:ApplyTextStyling(frame) end

            if frame.Name and componentPositions.Name and componentPositions.Name.overrides then
                OrbitEngine.OverrideUtils.ApplyOverrides(frame.Name, componentPositions.Name.overrides)
            end
            if frame.HealthText and componentPositions.HealthText and componentPositions.HealthText.overrides then
                OrbitEngine.OverrideUtils.ApplyOverrides(frame.HealthText, componentPositions.HealthText.overrides)
            end

            if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end

            if frame.CastBar then
                local castBarDisabled = self.IsComponentDisabled and self:IsComponentDisabled("CastBar")
                if castBarDisabled then
                    frame.CastBar:Hide()
                else
                    frame.CastBar:SetMinMaxValues(0, PREVIEW_DEFAULTS.CastDuration)
                    frame.CastBar:SetValue(PREVIEW_DEFAULTS.CastProgress)
                    if frame.CastBar.Text then
                        local textDisabled = self.IsComponentDisabled and self:IsComponentDisabled("CastBar.Text")
                        frame.CastBar.Text:SetShown(not textDisabled)
                        if not textDisabled then frame.CastBar.Text:SetText("Boss Ability (Preview)") end
                    end
                    if frame.CastBar.Timer then
                        local timerDisabled = self.IsComponentDisabled and self:IsComponentDisabled("CastBar.Timer")
                        frame.CastBar.Timer:SetShown(not timerDisabled)
                        if not timerDisabled then frame.CastBar.Timer:SetText(tostring(PREVIEW_DEFAULTS.CastProgress)) end
                    end
                    local cbColor = OrbitEngine.ColorCurve:GetFirstColorFromCurve(self:GetSetting(1, "CastBarColorCurve"))
                        or self:GetSetting(1, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
                    frame.CastBar:SetStatusBarColor(cbColor.r, cbColor.g, cbColor.b)
                    frame.CastBar:Show()
                end
            end

            if not Orbit.PreviewAnimator:IsRunning() then
                self:ShowPreviewAuras(frame)
            end

            if frame.MarkerIcon then
                Orbit.StatusIconMixin:ApplyMarkerSprite(frame.MarkerIcon, 8)
                frame.MarkerIcon:Show()
                if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end
            end
        end
    end
end

-- [ PREVIEW AURAS ]---------------------------------------------------------------------------------

local BOSS_PREVIEW_DEBUFF_CFG = {
    helpers = function() return Orbit.BossFrameHelpers end,
    defaultAnchorX = "LEFT", defaultJustifyH = "LEFT",
    defaultMax = 4,
}
local BOSS_PREVIEW_BUFF_CFG = {
    helpers = function() return Orbit.BossFrameHelpers end,
    defaultAnchorX = "RIGHT", defaultJustifyH = "RIGHT",
    defaultMax = 3,
}

function Orbit.BossFramePreviewMixin:ShowPreviewAuras(frame)
    Orbit.AuraPreview:ShowFrameAuras(self, frame, BOSS_PREVIEW_DEBUFF_CFG, BOSS_PREVIEW_BUFF_CFG)
end

-- [ HIDE PREVIEW ]----------------------------------------------------------------------------------
function Orbit.BossFramePreviewMixin:HidePreview()
    if InCombatLockdown() or not self.frames then return end
    self.isPreviewActive = false

    -- Stop animation
    Orbit.PreviewAnimator:Stop(self)
    Orbit.PreviewAnimator:StopAuras(self)
    Orbit.PreviewAnimator:StopHealerAuras(self)

    -- Stop listening for Canvas Mode edits
    if self._canvasSettingsCallback then
        Orbit.EventBus:Off("CANVAS_SETTINGS_CHANGED", self._canvasSettingsCallback)
    end
    local visibilityDriver = "[@boss1,exists] show; [@boss2,exists] show; [@boss3,exists] show; [@boss4,exists] show; [@boss5,exists] show; hide"
    RegisterAttributeDriver(self.container, "state-visibility", visibilityDriver)

    for _, frame in ipairs(self.frames) do
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
        if frame.previewBuffs then
            for _, icon in ipairs(frame.previewBuffs) do
                icon:Hide()
                icon:ClearAllPoints()
            end
            wipe(frame.previewBuffs)
        end
        if frame.CastBar then frame.CastBar:Hide() end
        if frame.MarkerIcon then frame.MarkerIcon:Hide() end
        if frame.HealthDamageBar then frame.HealthDamageBar:Show() end
        if frame.HealthDamageTexture then frame.HealthDamageTexture:Show() end
    end
    self:UpdateContainerSize()
end

function Orbit.BossFramePreviewMixin:SchedulePreviewUpdate()
    if not self._previewVisualsScheduled then
        self._previewVisualsScheduled = true
        C_Timer.After(DEBOUNCE_DELAY, function()
            self._previewVisualsScheduled = false
            if self.frames then self:ApplyPreviewVisuals() end
        end)
    end
end

function Orbit.BossFramePreviewMixin:StartPreviewAnimation()
    if not self.frames then return end
    local animFrames, animCfg = {}, {}
    local auraFrames, auraCfg = {}, {}
    local healerFrames, healerCfg = {}, {}
    local isDisabled = self.IsComponentDisabled and function(k) return self:IsComponentDisabled(k) end or function() return false end
    local buffsEnabled = not isDisabled("Buffs")
    local debuffsEnabled = not isDisabled("Debuffs")
    local getHelpers = function() return Orbit.BossFrameHelpers end
    for i = 1, MAX_BOSS_FRAMES do
        local frame = self.frames[i]
        if frame and frame.preview and frame:IsShown() then
            animFrames[#animFrames + 1] = frame
            animCfg[#animCfg + 1] = { baseHealth = PREVIEW_DEFAULTS.HealthPercent / 100 }
            if buffsEnabled or debuffsEnabled then
                local plugin = self
                auraFrames[#auraFrames + 1] = frame
                auraCfg[#auraCfg + 1] = {
                    initAuras = function(f) return Orbit.AuraPreview:InitAnimatedAuras(plugin, f, getHelpers) end,
                }
            end
            healerFrames[#healerFrames + 1] = frame
            healerCfg[#healerCfg + 1] = {
                healerSlots = {},
                defensiveDisabled = isDisabled("DefensiveIcon"),
                ccDisabled = isDisabled("CrowdControlIcon"),
            }
        end
    end
    if #animFrames > 0 then Orbit.PreviewAnimator:Start(self, animFrames, animCfg) end
    if #auraFrames > 0 then Orbit.PreviewAnimator:StartAuras(self, auraFrames, auraCfg) end
    if #healerFrames > 0 then Orbit.PreviewAnimator:StartHealerAuras(self, healerFrames, healerCfg) end
end
