local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

Orbit.BossFramePreviewMixin = {}
local Helpers = nil

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_BOSS_FRAMES = 5
local POWER_BAR_HEIGHT_RATIO = 0.2
local DEBOUNCE_DELAY = Orbit.Constants.Timing.DefaultDebounce
local DEFAULT_DEBUFF_ICON_SIZE = 25
local DEFAULT_BUFF_ICON_SIZE = 20
local MARKER_ICON_SIZE = 16
local AURA_SPACING = 1

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

local SAMPLE_DEBUFF_ICONS = { 136096, 136118, 132158, 136048, 132212 }
local SAMPLE_BUFF_ICONS = { 135907, 136048, 136041, 135944, 135987 }

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
        if self.frames then self:ApplyPreviewVisuals() end
    end)
end

function Orbit.BossFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then return end
    if not Helpers then Helpers = Orbit.BossFrameHelpers end

    local width = self:GetSetting(1, "Width") or PREVIEW_DEFAULTS.Width
    local height = self:GetSetting(1, "Height") or PREVIEW_DEFAULTS.Height
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
    local borderSize = self:GetSetting(1, "BorderSize") or (Orbit.Engine.Pixel and Orbit.Engine.Pixel:Multiple(1, self.container:GetEffectiveScale() or 1) or 1)

    local componentPositions = self:GetSetting(1, "ComponentPositions") or {}
    local debuffData = componentPositions.Debuffs or {}
    local debuffOverrides = debuffData.overrides or {}
    local maxDebuffs = debuffOverrides.MaxIcons or 4

    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] and self.frames[i].preview then
            local frame = self.frames[i]
            frame:SetSize(width, height)

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
                if frame.HealthDamageBar then frame.HealthDamageBar:Hide() end
                if frame.HealthDamageTexture then frame.HealthDamageTexture:Hide() end
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
                    local cbColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(self:GetSetting(1, "CastBarColorCurve"))
                        or self:GetSetting(1, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
                    frame.CastBar:SetStatusBarColor(cbColor.r, cbColor.g, cbColor.b)
                    frame.CastBar:Show()
                end
            end

            self:ShowPreviewDebuffs(frame, maxDebuffs)

            local buffData = componentPositions.Buffs or {}
            local buffOverrides = buffData.overrides or {}
            local maxBuffs = buffOverrides.MaxIcons or 3
            self:ShowPreviewBuffs(frame, maxBuffs)

            if frame.MarkerIcon then
                local RAID_TARGET_TEXTURE_COLUMNS, RAID_TARGET_TEXTURE_ROWS = 4, 4
                local col = (8 - 1) % RAID_TARGET_TEXTURE_COLUMNS
                local row = math.floor((8 - 1) / RAID_TARGET_TEXTURE_COLUMNS)
                local w, h = 1 / RAID_TARGET_TEXTURE_COLUMNS, 1 / RAID_TARGET_TEXTURE_ROWS
                frame.MarkerIcon:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
                frame.MarkerIcon:Show()
                if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end
            end
        end
    end
end

-- [ PREVIEW DEBUFFS ]-------------------------------------------------------------------------------
function Orbit.BossFramePreviewMixin:ShowPreviewDebuffs(frame, numDebuffsToShow)
    local componentPositions = self:GetSetting(1, "ComponentPositions") or {}
    local debuffData = componentPositions.Debuffs or {}
    local debuffOverrides = debuffData.overrides or {}

    local debuffDisabled = self.IsComponentDisabled and self:IsComponentDisabled("Debuffs")
    if debuffDisabled then
        if frame.debuffContainer then frame.debuffContainer:Hide() end
        return
    end

    local maxDebuffs = debuffOverrides.MaxIcons or 4
    local numDebuffs = math.min(numDebuffsToShow, maxDebuffs, #SAMPLE_DEBUFF_ICONS)
    if numDebuffs == 0 then return end

    if not frame.debuffContainer then
        frame.debuffContainer = CreateFrame("Frame", nil, frame)
    end
    frame.debuffContainer:SetParent(frame)
    frame.debuffContainer:SetFrameStrata("MEDIUM")
    frame.debuffContainer:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Highlight)

    if not Helpers then Helpers = Orbit.BossFrameHelpers end

    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()
    local position = Helpers:AnchorToPosition(debuffData.posX, debuffData.posY, frameWidth / 2, frameHeight / 2)
    local isHorizontal = (position == "Above" or position == "Below")
    local maxRows = debuffOverrides.MaxRows or 1

    local iconSize = debuffOverrides.IconSize or DEFAULT_DEBUFF_ICON_SIZE
    iconSize = math.max(10, iconSize)

    local rows, iconsPerRow, containerWidth, containerHeight
    if isHorizontal then
        iconsPerRow = math.max(1, math.floor((frameWidth + AURA_SPACING) / (iconSize + AURA_SPACING)))
        rows = math.min(maxRows, math.ceil(numDebuffs / iconsPerRow))
        local displayCols = math.min(math.min(numDebuffs, iconsPerRow * rows), iconsPerRow)
        containerWidth = (displayCols * iconSize) + ((displayCols - 1) * AURA_SPACING)
        containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
    else
        rows = math.min(maxRows, numDebuffs)
        iconsPerRow = math.ceil(numDebuffs / rows)
        containerWidth = (iconsPerRow * iconSize) + ((iconsPerRow - 1) * AURA_SPACING)
        containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
    end

    frame.debuffContainer:SetSize(containerWidth, containerHeight)
    frame.debuffContainer:ClearAllPoints()

    local anchorX = debuffData.anchorX or "LEFT"
    local anchorY = debuffData.anchorY or "CENTER"
    local offsetX = debuffData.offsetX or 0
    local offsetY = debuffData.offsetY or 0
    local justifyH = debuffData.justifyH or "LEFT"

    local anchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)
    local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(false, true, anchorY, justifyH)

    local finalX = offsetX
    local finalY = offsetY
    if anchorX == "RIGHT" then finalX = -offsetX end
    if anchorY == "TOP" then finalY = -offsetY end

    frame.debuffContainer:SetPoint(selfAnchor, frame, anchorPoint, finalX, finalY)
    frame.debuffContainer:Show()

    if not frame.previewDebuffs then frame.previewDebuffs = {} end
    for _, icon in ipairs(frame.previewDebuffs) do icon:Hide() end

    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = true }
    local growDown = (anchorY ~= "BOTTOM")

    for idx = 1, numDebuffs do
        local icon = frame.previewDebuffs[idx]
        if not icon then
            icon = CreateFrame("Button", nil, frame.debuffContainer, "BackdropTemplate")
            icon.Icon = icon:CreateTexture(nil, "ARTWORK")
            icon.Icon:SetAllPoints()
            icon.icon = icon.Icon
            icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
            icon.Cooldown:SetAllPoints()
            icon.Cooldown:SetHideCountdownNumbers(false)
            icon.cooldown = icon.Cooldown
            frame.previewDebuffs[idx] = icon
        end
        icon:SetParent(frame.debuffContainer)
        icon:SetSize(iconSize, iconSize)

        local col = (idx - 1) % iconsPerRow
        local row = math.floor((idx - 1) / iconsPerRow)
        local xOff = col * (iconSize + AURA_SPACING)
        local yOff = row * (iconSize + AURA_SPACING)
        icon:ClearAllPoints()
        if justifyH == "RIGHT" then
            if growDown then icon:SetPoint("TOPRIGHT", frame.debuffContainer, "TOPRIGHT", -xOff, -yOff)
            else icon:SetPoint("BOTTOMRIGHT", frame.debuffContainer, "BOTTOMRIGHT", -xOff, yOff) end
        else
            if growDown then icon:SetPoint("TOPLEFT", frame.debuffContainer, "TOPLEFT", xOff, -yOff)
            else icon:SetPoint("BOTTOMLEFT", frame.debuffContainer, "BOTTOMLEFT", xOff, yOff) end
        end

        local iconIndex = ((idx - 1) % #SAMPLE_DEBUFF_ICONS) + 1
        icon.Icon:SetTexture(SAMPLE_DEBUFF_ICONS[iconIndex])
        if Orbit.Skin and Orbit.Skin.Icons then Orbit.Skin.Icons:ApplyCustom(icon, skinSettings) end
        icon.Cooldown:SetCooldown(GetTime() - PREVIEW_DEFAULTS.FakeCooldownElapsed, PREVIEW_DEFAULTS.FakeCooldownDuration)
        icon.Cooldown:Show()
        icon:Show()
    end
end

-- [ PREVIEW BUFFS ]---------------------------------------------------------------------------------
function Orbit.BossFramePreviewMixin:ShowPreviewBuffs(frame, numBuffsToShow)
    local componentPositions = self:GetSetting(1, "ComponentPositions") or {}
    local buffData = componentPositions.Buffs or {}
    local buffOverrides = buffData.overrides or {}

    local buffDisabled = self.IsComponentDisabled and self:IsComponentDisabled("Buffs")
    if buffDisabled then
        if frame.buffContainer then frame.buffContainer:Hide() end
        return
    end

    local maxBuffs = buffOverrides.MaxIcons or 3
    local numBuffs = math.min(numBuffsToShow, maxBuffs, #SAMPLE_BUFF_ICONS)
    if numBuffs == 0 then return end

    if not frame.buffContainer then
        frame.buffContainer = CreateFrame("Frame", nil, frame)
    end
    frame.buffContainer:SetParent(frame)
    frame.buffContainer:SetFrameStrata("MEDIUM")
    frame.buffContainer:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Highlight)

    if not Helpers then Helpers = Orbit.BossFrameHelpers end

    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()
    local position = Helpers:AnchorToPosition(buffData.posX, buffData.posY, frameWidth / 2, frameHeight / 2)
    local isHorizontal = (position == "Above" or position == "Below")
    local maxRows = buffOverrides.MaxRows or 1
    local iconSize = math.max(10, buffOverrides.IconSize or DEFAULT_BUFF_ICON_SIZE)

    local rows, iconsPerRow, containerWidth, containerHeight
    if isHorizontal then
        iconsPerRow = math.max(1, math.floor((frameWidth + AURA_SPACING) / (iconSize + AURA_SPACING)))
        rows = math.min(maxRows, math.ceil(numBuffs / iconsPerRow))
        local displayCols = math.min(math.min(numBuffs, iconsPerRow * rows), iconsPerRow)
        containerWidth = (displayCols * iconSize) + ((displayCols - 1) * AURA_SPACING)
        containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
    else
        rows = math.min(maxRows, numBuffs)
        iconsPerRow = math.ceil(numBuffs / rows)
        containerWidth = (iconsPerRow * iconSize) + ((iconsPerRow - 1) * AURA_SPACING)
        containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
    end

    frame.buffContainer:SetSize(containerWidth, containerHeight)
    frame.buffContainer:ClearAllPoints()

    local anchorX = buffData.anchorX or "RIGHT"
    local anchorY = buffData.anchorY or "CENTER"
    local offsetX = buffData.offsetX or 0
    local offsetY = buffData.offsetY or 0
    local justifyH = buffData.justifyH or "RIGHT"

    local anchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)
    local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(false, true, anchorY, justifyH)

    local finalX = offsetX
    local finalY = offsetY
    if anchorX == "RIGHT" then finalX = -offsetX end
    if anchorY == "TOP" then finalY = -offsetY end

    frame.buffContainer:SetPoint(selfAnchor, frame, anchorPoint, finalX, finalY)
    frame.buffContainer:Show()

    if not frame.previewBuffs then frame.previewBuffs = {} end
    for _, icon in ipairs(frame.previewBuffs) do icon:Hide() end

    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = true }
    local growDown = (anchorY ~= "BOTTOM")

    for idx = 1, numBuffs do
        local icon = frame.previewBuffs[idx]
        if not icon then
            icon = CreateFrame("Button", nil, frame.buffContainer, "BackdropTemplate")
            icon.Icon = icon:CreateTexture(nil, "ARTWORK")
            icon.Icon:SetAllPoints()
            icon.icon = icon.Icon
            icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
            icon.Cooldown:SetAllPoints()
            icon.Cooldown:SetHideCountdownNumbers(false)
            icon.cooldown = icon.Cooldown
            frame.previewBuffs[idx] = icon
        end
        icon:SetParent(frame.buffContainer)
        icon:SetSize(iconSize, iconSize)

        local col = (idx - 1) % iconsPerRow
        local row = math.floor((idx - 1) / iconsPerRow)
        local xOff = col * (iconSize + AURA_SPACING)
        local yOff = row * (iconSize + AURA_SPACING)
        icon:ClearAllPoints()
        if justifyH == "RIGHT" then
            if growDown then icon:SetPoint("TOPRIGHT", frame.buffContainer, "TOPRIGHT", -xOff, -yOff)
            else icon:SetPoint("BOTTOMRIGHT", frame.buffContainer, "BOTTOMRIGHT", -xOff, yOff) end
        else
            if growDown then icon:SetPoint("TOPLEFT", frame.buffContainer, "TOPLEFT", xOff, -yOff)
            else icon:SetPoint("BOTTOMLEFT", frame.buffContainer, "BOTTOMLEFT", xOff, yOff) end
        end

        local iconIndex = ((idx - 1) % #SAMPLE_BUFF_ICONS) + 1
        icon.Icon:SetTexture(SAMPLE_BUFF_ICONS[iconIndex])
        if Orbit.Skin and Orbit.Skin.Icons then Orbit.Skin.Icons:ApplyCustom(icon, skinSettings) end
        icon.Cooldown:SetCooldown(GetTime() - PREVIEW_DEFAULTS.FakeCooldownElapsed, PREVIEW_DEFAULTS.FakeCooldownDuration)
        icon.Cooldown:Show()
        icon:Show()
    end
end

-- [ HIDE PREVIEW ]----------------------------------------------------------------------------------
function Orbit.BossFramePreviewMixin:HidePreview()
    if InCombatLockdown() or not self.frames then return end
    self.isPreviewActive = false
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
