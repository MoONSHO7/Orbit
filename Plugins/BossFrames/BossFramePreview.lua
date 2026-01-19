local _, addonTable = ...
local Orbit = addonTable
local LSM = LibStub("LibSharedMedia-3.0")

-- Define Mixin
Orbit.BossFramePreviewMixin = {}

-- Reference to shared helpers (loaded from BossFrameHelpers.lua)
local Helpers = nil -- Will be set when first needed

-- Constants
local MAX_BOSS_FRAMES = 5
local PREVIEW_FRAME_COUNT = 2 -- Number of frames to show in preview
local POWER_BAR_HEIGHT_RATIO = 0.2
local DEBOUNCE_DELAY = Orbit.Constants and Orbit.Constants.Timing and Orbit.Constants.Timing.DefaultDebounce or 0.1

-- Preview defaults
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

-- Sample debuff icons for preview
local SAMPLE_DEBUFF_ICONS = {
    136096, -- Moonfire
    136118, -- Corruption
    132158, -- Nature's Grasp (Roots)
    136048, -- Insect Swarm
    132212, -- Faerie Fire
}

-- ================================================================================================
-- PREVIEW LIFECYCLE
-- Uses the REAL frames for preview to ensure perfect visual match
-- Container driver is handled by Edit Mode callbacks in BossFrame.lua
-- ================================================================================================

function Orbit.BossFramePreviewMixin:ShowPreview()
    if not self.frames then
        return
    end
    
    -- Mark that we're in preview mode
    self.isPreviewActive = true
    
    -- Protected operations require being out of combat
    if InCombatLockdown() then
        -- Queue protected setup for after combat
        if not self.showPreviewCleanupFrame then
            self.showPreviewCleanupFrame = CreateFrame("Frame")
            self.showPreviewCleanupFrame:SetScript("OnEvent", function(f, event)
                if event == "PLAYER_REGEN_ENABLED" then
                    f:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    if self.isPreviewActive then
                        self:ShowPreviewProtected()
                    end
                end
            end)
        end
        self.showPreviewCleanupFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        
        -- For now, just apply visual-only changes (no protected calls)
        self:SchedulePreviewUpdate()
        return
    end
    
    -- Do the protected setup immediately
    self:ShowPreviewProtected()
end

-- Separated protected operations that require being out of combat
function Orbit.BossFramePreviewMixin:ShowPreviewProtected()
    if not self.frames then
        return
    end
    
    -- Temporarily disable UnitWatch on real frames so we can manually show them
    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] then
            UnregisterUnitWatch(self.frames[i])
        end
    end
    
    -- Show and set up preview for first N frames
    for i = 1, PREVIEW_FRAME_COUNT do
        if self.frames[i] then
            self.frames[i].isPreview = true
            self.frames[i]:Show()
        end
    end
    
    -- Hide remaining frames
    for i = PREVIEW_FRAME_COUNT + 1, MAX_BOSS_FRAMES do
        if self.frames[i] then
            self.frames[i]:Hide()
        end
    end
    
    -- Position frames
    self:PositionFrames()
    
    -- Update container size
    self:UpdateContainerSize()
    
    -- Apply preview visuals after a short delay to avoid race with ApplySettings
    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.isPreviewActive and self.frames then
            self:ApplyPreviewVisuals()
        end
    end)
end

function Orbit.BossFramePreviewMixin:HidePreview()
    if not self.frames then
        return
    end
    
    -- Mark preview as inactive
    self.isPreviewActive = false
    
    -- Clear preview state on all frames
    for i, frame in ipairs(self.frames) do
        frame.isPreview = nil
        
        -- Hide preview-only elements
        if frame.previewDebuffs then
            for _, icon in ipairs(frame.previewDebuffs) do
                icon:Hide()
            end
        end
        
        -- Hide cast bar (real cast events will control it)
        if frame.CastBar then
            frame.CastBar:Hide()
        end
    end
    
    -- Re-enable UnitWatch for real frames (only out of combat)
    if not InCombatLockdown() then
        for i = 1, MAX_BOSS_FRAMES do
            if self.frames[i] then
                RegisterUnitWatch(self.frames[i])
            end
        end
    else
        -- Queue for after combat
        if not self.hidePreviewCleanupFrame then
            self.hidePreviewCleanupFrame = CreateFrame("Frame")
            self.hidePreviewCleanupFrame:SetScript("OnEvent", function(f, event)
                if event == "PLAYER_REGEN_ENABLED" then
                    f:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    for i = 1, MAX_BOSS_FRAMES do
                        if self.frames[i] then
                            RegisterUnitWatch(self.frames[i])
                        end
                    end
                end
            end)
        end
        self.hidePreviewCleanupFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    
    -- Update container size
    if not InCombatLockdown() then
        self:UpdateContainerSize()
    end
end

-- ================================================================================================
-- PREVIEW VISUALS
-- Apply fake data to real frames for WYSIWYG preview
-- ================================================================================================

function Orbit.BossFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames or not self.isPreviewActive then
        return
    end

    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 4
    
    for i = 1, PREVIEW_FRAME_COUNT do
        local frame = self.frames[i]
        if frame and frame.isPreview then
            -- Apply fake health values
            if frame.Health then
                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(PREVIEW_DEFAULTS.HealthPercent)
                frame.Health:SetStatusBarColor(1, 0.1, 0.1) -- Red for hostile
            end
            
            -- Apply fake power values
            if frame.Power then
                frame.Power:SetMinMaxValues(0, 100)
                frame.Power:SetValue(PREVIEW_DEFAULTS.PowerPercent)
                frame.Power:SetStatusBarColor(0, 0.5, 1) -- Mana blue
            end
            
            -- Set fake name
            if frame.Name then
                frame.Name:SetText("Boss " .. i)
            end
            
            -- Set fake health text
            if frame.HealthText then
                frame.HealthText:SetText(PREVIEW_DEFAULTS.HealthPercent .. "%")
            end
            
            -- Show cast bar preview
            self:ApplyPreviewCastBar(frame)
            
            -- Show debuff preview
            self:ShowPreviewDebuffs(frame, maxDebuffs)
        end
    end
end

function Orbit.BossFramePreviewMixin:ApplyPreviewCastBar(frame)
    if not frame.CastBar then
        return
    end
    
    local width = self:GetSetting(1, "Width") or PREVIEW_DEFAULTS.Width
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or PREVIEW_DEFAULTS.CastBarHeight
    local castBarPosition = self:GetSetting(1, "CastBarPosition") or "Below"
    local showIcon = self:GetSetting(1, "CastBarIcon")
    local textureName = self:GetSetting(1, "Texture") or self:GetPlayerSetting("Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
    
    local iconOffset = 0
    
    frame.CastBar:SetSize(width, castBarHeight)
    frame.CastBar:SetStatusBarTexture(texturePath)
    frame.CastBar:SetMinMaxValues(0, PREVIEW_DEFAULTS.CastDuration)
    frame.CastBar:SetValue(PREVIEW_DEFAULTS.CastProgress)
    frame.CastBar:SetStatusBarColor(1, 0.7, 0)
    
    -- Position cast bar
    self:PositionCastBar(frame.CastBar, frame, castBarPosition)
    
    -- Icon handling
    if frame.CastBar.Icon then
        if showIcon then
            frame.CastBar.Icon:SetTexture(136243) -- Hearthstone
            frame.CastBar.Icon:SetSize(castBarHeight, castBarHeight)
            frame.CastBar.Icon:ClearAllPoints()
            frame.CastBar.Icon:SetPoint("LEFT", frame.CastBar, "LEFT", 0, 0)
            frame.CastBar.Icon:Show()
            iconOffset = castBarHeight
            
            if frame.CastBar.IconBorder then
                frame.CastBar.IconBorder:Show()
            end
            
            -- Hide left border for merged look
            if frame.CastBar.Borders and frame.CastBar.Borders.Left then
                frame.CastBar.Borders.Left:Hide()
            end
        else
            frame.CastBar.Icon:Hide()
            if frame.CastBar.IconBorder then
                frame.CastBar.IconBorder:Hide()
            end
            if frame.CastBar.Borders and frame.CastBar.Borders.Left then
                frame.CastBar.Borders.Left:Show()
            end
        end
    end
    
    -- Adjust status bar texture position for icon
    local statusBarTexture = frame.CastBar:GetStatusBarTexture()
    if statusBarTexture then
        statusBarTexture:ClearAllPoints()
        statusBarTexture:SetPoint("TOPLEFT", frame.CastBar, "TOPLEFT", iconOffset, 0)
        statusBarTexture:SetPoint("BOTTOMRIGHT", frame.CastBar, "BOTTOMRIGHT", 0, 0)
    end
    
    -- Background adjustment
    if frame.CastBar.bg then
        frame.CastBar.bg:ClearAllPoints()
        frame.CastBar.bg:SetPoint("TOPLEFT", frame.CastBar, "TOPLEFT", iconOffset, 0)
        frame.CastBar.bg:SetPoint("BOTTOMRIGHT", frame.CastBar, "BOTTOMRIGHT", 0, 0)
    end
    
    -- Text position
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
        frame.CastBar.Timer:SetText(string.format("%.1f", PREVIEW_DEFAULTS.CastProgress))
    end
    
    frame.CastBar:Show()
end

-- ================================================================================================
-- PREVIEW DEBUFFS
-- ================================================================================================

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
    local frameHeight = frame:GetHeight()
    local frameWidth = frame:GetWidth()
    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 4
    local numDebuffs = math.min(numDebuffsToShow, maxDebuffs, #SAMPLE_DEBUFF_ICONS)
    local spacing = PREVIEW_DEFAULTS.DebuffSpacing

    if numDebuffs == 0 then
        return
    end

    -- Lazy-load helpers
    if not Helpers then
        Helpers = Orbit.BossFrameHelpers
    end

    -- Calculate layout
    local iconSize, xOffsetStep = Helpers:CalculateDebuffLayout(
        isHorizontal, frameWidth, frameHeight, maxDebuffs, spacing
    )

    -- Ensure debuff container exists
    if not frame.debuffContainer then
        frame.debuffContainer = CreateFrame("Frame", nil, frame)
    end
    frame.debuffContainer:SetParent(frame)
    frame.debuffContainer:SetFrameStrata("MEDIUM")
    frame.debuffContainer:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.debuffContainer:Show()

    -- Initialize pool if needed
    if not frame.previewDebuffs then
        frame.previewDebuffs = {}
    end

    -- Position container
    local castBarPos = self:GetSetting(1, "CastBarPosition")
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or PREVIEW_DEFAULTS.CastBarHeight

    Helpers:PositionDebuffContainer(
        frame.debuffContainer, frame, position,
        numDebuffs, iconSize, spacing, castBarPos, castBarHeight
    )

    -- Skin settings
    local globalBorder = self:GetPlayerSetting("BorderSize") or 1
    local skinSettings = {
        zoom = 0,
        borderStyle = 1,
        borderSize = globalBorder,
        showTimer = true,
    }

    -- Create/show debuff icons
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

        -- Position
        currentX = Helpers:PositionDebuffIcon(
            icon, frame.debuffContainer, isHorizontal, position,
            currentX, iconSize, xOffsetStep, spacing
        )

        -- Texture
        local iconIndex = ((i - 1) % #SAMPLE_DEBUFF_ICONS) + 1
        icon.Icon:SetTexture(SAMPLE_DEBUFF_ICONS[iconIndex])

        -- Apply skin
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
        end

        -- Fake cooldown
        icon.Cooldown:SetCooldown(GetTime() - PREVIEW_DEFAULTS.FakeCooldownElapsed, PREVIEW_DEFAULTS.FakeCooldownDuration)
        icon.Cooldown:Show()

        icon:Show()
    end

    -- Hide excess icons
    for i = numDebuffs + 1, #frame.previewDebuffs do
        frame.previewDebuffs[i]:Hide()
    end
end

-- ================================================================================================
-- UTILITY
-- ================================================================================================

function Orbit.BossFramePreviewMixin:SchedulePreviewUpdate()
    if not self._previewVisualsScheduled then
        self._previewVisualsScheduled = true
        C_Timer.After(DEBOUNCE_DELAY, function()
            self._previewVisualsScheduled = false
            if self.isPreviewActive and self.frames then
                self:ApplyPreviewVisuals()
            end
        end)
    end
end
