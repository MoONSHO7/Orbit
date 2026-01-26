---@type Orbit
local Orbit = Orbit
local LSM = LibStub("LibSharedMedia-3.0")

-- Define Mixin
Orbit.BossFramePreviewMixin = {}

-- Reference to shared helpers (loaded from BossFrameHelpers.lua)
-- Note: BossFrameHelpers.lua must be loaded before this file in the TOC
local Helpers = nil -- Will be set when first needed

-- Constants (Replicated from BossFrame.lua to avoid tight coupling)
local MAX_BOSS_FRAMES = 5
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
    ContainerGap = 4,           -- Gap between frame edge and debuff container
    FakeCooldownElapsed = 10,   -- Seconds already elapsed on fake cooldown
    FakeCooldownDuration = 60,  -- Total fake cooldown duration
}

-- Sample debuff icons for preview (reused, no allocation per call)
local SAMPLE_DEBUFF_ICONS = {
    136096, -- Moonfire
    136118, -- Corruption
    132158, -- Nature's Grasp (Roots)
    136048, -- Insect Swarm
    132212, -- Faerie Fire
}

-- [ PREVIEW LOGIC ]---------------------------------------------------------------------------------

function Orbit.BossFramePreviewMixin:ShowPreview()
    -- PREVIEW IS BLOCKED IN COMBAT (Protected function calls)
    if InCombatLockdown() then
        return
    end
    if not self.frames or not self.container then
        return
    end

    self.isPreviewActive = true

    -- Disable Visibility Driver for preview so we can manually Show frames
    UnregisterAttributeDriver(self.container, "state-visibility")
    self.container:Show()

    -- Disable UnitWatch for preview so we can manually Show frames
    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] then
            UnregisterUnitWatch(self.frames[i])
        end
    end

    -- Set up BOTH preview frames first (set flags before size calculations)
    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] then
            self.frames[i].preview = true
            self.frames[i]:Show()
        end
    end

    -- Position frames within container
    self:PositionFrames()

    -- Update container size for preview
    self:UpdateContainerSize()

    -- Apply preview visuals AFTER a short delay to ensure they aren't overwritten
    -- by ApplySettings or UpdateAll that may run from Edit Mode callbacks
    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.frames then  -- Guard against stale reference
            self:ApplyPreviewVisuals()
        end
    end)
end

function Orbit.BossFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then
        return
    end

    -- Get settings
    local width = self:GetSetting(1, "Width") or PREVIEW_DEFAULTS.Width
    local height = self:GetSetting(1, "Height") or PREVIEW_DEFAULTS.Height
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"

    -- Build debuff icon list from sample icons (no table allocation per call)
    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 4

    for i = 1, MAX_BOSS_FRAMES do
        if self.frames[i] and self.frames[i].preview then
            local frame = self.frames[i]

            -- Set frame size
            frame:SetSize(width, height)

            -- Apply texture and set up health bar
            if frame.Health then
                frame.Health:ClearAllPoints()
                frame.Health:SetPoint("TOPLEFT", 1, -1)
                frame.Health:SetPoint("BOTTOMRIGHT", -1, height * POWER_BAR_HEIGHT_RATIO + 1)
                frame.Health:SetStatusBarTexture(texturePath)
                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(PREVIEW_DEFAULTS.HealthPercent)
                frame.Health:SetStatusBarColor(1, 0.1, 0.1) -- Red for hostile boss
                frame.Health:Show()
            end

            -- Apply texture and set up power bar
            if frame.Power then
                frame.Power:ClearAllPoints()
                frame.Power:SetPoint("BOTTOMLEFT", 1, 1)
                frame.Power:SetPoint("BOTTOMRIGHT", -1, 1)
                frame.Power:SetHeight(height * POWER_BAR_HEIGHT_RATIO)
                frame.Power:SetStatusBarTexture(texturePath)
                frame.Power:SetMinMaxValues(0, 100)
                frame.Power:SetValue(PREVIEW_DEFAULTS.PowerPercent)
                frame.Power:SetStatusBarColor(0, 0.5, 1) -- Blue for mana
                frame.Power:Show()
            end

            -- Preview name - ensure visible and OVERRIDE any unit data
            if frame.Name then
                frame.Name:SetText("Boss " .. i)
                frame.Name:SetTextColor(1, 1, 1, 1)
                frame.Name:Show()
            end

            -- Preview health text - OVERRIDE UpdateHealthText
            if frame.HealthText then
                frame.HealthText:SetText(PREVIEW_DEFAULTS.HealthPercent .. "%")
                frame.HealthText:SetTextColor(1, 1, 1, 1)
                frame.HealthText:Show()
            end

            -- Show cast bar preview (so user can see spacing effect)
            if frame.CastBar then
                local castBarHeight = self:GetSetting(1, "CastBarHeight") or PREVIEW_DEFAULTS.CastBarHeight
                local castBarPosition = self:GetSetting(1, "CastBarPosition") or "Below"
                local showIcon = self:GetSetting(1, "CastBarIcon")
                local iconOffset = 0

                frame.CastBar:SetSize(width, castBarHeight)
                frame.CastBar:SetStatusBarTexture(texturePath)
                frame.CastBar:SetMinMaxValues(0, PREVIEW_DEFAULTS.CastDuration)
                frame.CastBar:SetValue(PREVIEW_DEFAULTS.CastProgress)
                frame.CastBar.unit = "preview" -- prevent event hooks from erroring

                -- Ensure correct positioning (Using shared method)
                self:PositionCastBar(frame.CastBar, frame, castBarPosition)

                -- Handle Icon visibility and positioning
                if frame.CastBar.Icon then
                    if showIcon then
                        frame.CastBar.Icon:SetTexture(136243) -- Hearthstone icon for preview
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

                -- Adjust StatusBar texture to start after icon
                local statusBarTexture = frame.CastBar:GetStatusBarTexture()
                if statusBarTexture then
                    statusBarTexture:ClearAllPoints()
                    statusBarTexture:SetPoint("TOPLEFT", frame.CastBar, "TOPLEFT", iconOffset, 0)
                    statusBarTexture:SetPoint("BOTTOMLEFT", frame.CastBar, "BOTTOMLEFT", iconOffset, 0)
                    statusBarTexture:SetPoint("TOPRIGHT", frame.CastBar, "TOPRIGHT", 0, 0)
                    statusBarTexture:SetPoint("BOTTOMRIGHT", frame.CastBar, "BOTTOMRIGHT", 0, 0)
                end

                -- Adjust background to start after icon
                if frame.CastBar.bg then
                    frame.CastBar.bg:ClearAllPoints()
                    frame.CastBar.bg:SetPoint("TOPLEFT", frame.CastBar, "TOPLEFT", iconOffset, 0)
                    frame.CastBar.bg:SetPoint("BOTTOMRIGHT", frame.CastBar, "BOTTOMRIGHT", 0, 0)
                end

                -- Position text based on icon
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

            -- Show fake debuff icons preview (pass maxDebuffs, function uses SAMPLE_DEBUFF_ICONS)
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
    local frameHeight = frame:GetHeight()
    local frameWidth = frame:GetWidth()
    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 4
    local numDebuffs = math.min(numDebuffsToShow, maxDebuffs, #SAMPLE_DEBUFF_ICONS)
    local spacing = PREVIEW_DEFAULTS.DebuffSpacing

    if numDebuffs == 0 then
        return
    end

    -- Lazy-load helpers reference
    if not Helpers then
        Helpers = Orbit.BossFrameHelpers
    end

    -- Calculate Size & Layout using shared helper
    local iconSize, xOffsetStep = Helpers:CalculateDebuffLayout(
        isHorizontal, frameWidth, frameHeight, maxDebuffs, spacing
    )

    -- Create preview icons if needed
    if not frame.previewDebuffs then
        frame.previewDebuffs = {}
    end

    -- Hide existing preview icons
    for _, icon in ipairs(frame.previewDebuffs) do
        icon:Hide()
    end

    -- Ensure debuff container is properly set up
    if not frame.debuffContainer then
        frame.debuffContainer = CreateFrame("Frame", nil, frame)
    else
        -- Parent to frame (simpler for preview)
        frame.debuffContainer:SetParent(frame)
    end

    -- Reset visibility
    frame.debuffContainer:SetFrameStrata("MEDIUM")
    frame.debuffContainer:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.debuffContainer:Show()

    -- Get cast bar settings for collision avoidance
    local castBarPos = self:GetSetting(1, "CastBarPosition")
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or PREVIEW_DEFAULTS.CastBarHeight

    -- Position container using shared helper
    Helpers:PositionDebuffContainer(
        frame.debuffContainer, frame, position,
        numDebuffs, iconSize, spacing, castBarPos, castBarHeight
    )

    -- Settings for Skin
    local globalBorder = Orbit.db.GlobalSettings.BorderSize or 1
    local skinSettings = {
        zoom = 0,
        borderStyle = 1, -- Pixel Perfect
        borderSize = globalBorder,
        showTimer = true,
    }

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

        -- Position icon using shared helper
        currentX = Helpers:PositionDebuffIcon(
            icon, frame.debuffContainer, isHorizontal, position,
            currentX, iconSize, xOffsetStep, spacing
        )

        -- Set fake texture (cycle through sample icons)
        local iconIndex = ((i - 1) % #SAMPLE_DEBUFF_ICONS) + 1
        icon.Icon:SetTexture(SAMPLE_DEBUFF_ICONS[iconIndex])

        -- Apply Skin
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
        end

        -- Fake Cooldown (simulate debuff that started FakeCooldownElapsed seconds ago)
        icon.Cooldown:SetCooldown(GetTime() - PREVIEW_DEFAULTS.FakeCooldownElapsed, PREVIEW_DEFAULTS.FakeCooldownDuration)
        icon.Cooldown:Show()

        icon:Show()
    end

    -- Trigger layout update if not in combat (safe for preview)
    if not InCombatLockdown() then
        self:PositionFrames()
    end
end

function Orbit.BossFramePreviewMixin:HidePreview()
    -- PREVIEW IS BLOCKED IN COMBAT (Protected function calls)
    if InCombatLockdown() then
        -- Register event to hide when combat ends
        if not self.previewCleanupFrame then
            self.previewCleanupFrame = CreateFrame("Frame")
            self.previewCleanupFrame:SetScript("OnEvent", function(f, event)
                if event == "PLAYER_REGEN_ENABLED" then
                    f:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    self:HidePreview()
                end
            end)
        end
        self.previewCleanupFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

        -- Try to cleanup non-secure visuals immediately to reduce clutter
        -- (Only if it's safe - i.e. not touching protected frames)
        if self.frames then
            for i, frame in ipairs(self.frames) do
                -- Visually hide the main frame immediately so it doesn't linger
                frame:SetAlpha(0)

                if frame.previewDebuffs then
                    for _, icon in ipairs(frame.previewDebuffs) do
                        icon:Hide()
                    end
                end
                if frame.CastBar then
                    frame.CastBar:Hide()
                end
            end
        end
        
        return
    else
        -- Clean up event if we reached here safely (e.g. called manually or after regression)
        if self.previewCleanupFrame then
            self.previewCleanupFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end
    end

    if not self.frames then
        return
    end

    self.isPreviewActive = false

    -- Restore Visibility Driver for normal gameplay
    local visibilityDriver =
        "[@boss1,exists] show; [@boss2,exists] show; [@boss3,exists] show; [@boss4,exists] show; [@boss5,exists] show; hide"
    RegisterAttributeDriver(self.container, "state-visibility", visibilityDriver)

    for i, frame in ipairs(self.frames) do
        frame.preview = nil
        
        -- Restore visual visibility (in case it was hidden during combat deferral)
        frame:SetAlpha(1) 

        -- Restore UnitWatch for normal gameplay (handles combat visibility)
        RegisterUnitWatch(frame)

        -- Hide and clear preview debuffs to release memory
        if frame.previewDebuffs then
            for _, icon in ipairs(frame.previewDebuffs) do
                icon:Hide()
                icon:ClearAllPoints()
            end
            -- Clear the table but keep the frame references for reuse
            -- (frames are parented to debuffContainer so they won't leak)
            wipe(frame.previewDebuffs)
        end

        -- Hide cast bar preview (will be controlled by actual casts)
        if frame.CastBar then
            frame.CastBar:Hide()
        end
    end

    -- Update container size
    self:UpdateContainerSize()
end

function Orbit.BossFramePreviewMixin:SchedulePreviewUpdate()
    if not self._previewVisualsScheduled then
        self._previewVisualsScheduled = true
        C_Timer.After(DEBOUNCE_DELAY, function()
            self._previewVisualsScheduled = false
            if self.frames then  -- Guard against stale reference
                self:ApplyPreviewVisuals()
            end
        end)
    end
end
