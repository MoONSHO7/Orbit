local _, addonTable = ...
local Orbit = addonTable
local LSM = LibStub("LibSharedMedia-3.0")

-- Define Mixin
Orbit.BossFramePreviewMixin = {}

-- Constants (Replicated from BossFrame.lua to avoid tight coupling)
local MAX_BOSS_FRAMES = 5
local POWER_BAR_HEIGHT_RATIO = 0.2

-- State
local previewVisualsScheduled = false

-- [ PREVIEW LOGIC ]---------------------------------------------------------------------------------

function Orbit.BossFramePreviewMixin:ShowPreview()
    -- PREVIEW IS BLOCKED IN COMBAT (Protected function calls)
    if InCombatLockdown() then
        return
    end
    if not self.frames or not self.container then
        return
    end

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
    for i = 1, 2 do
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
    C_Timer.After(0.1, function()
        self:ApplyPreviewVisuals()
    end)
end

function Orbit.BossFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then
        return
    end

    -- Get settings
    local width = self:GetSetting(1, "Width") or 150
    local height = self:GetSetting(1, "Height") or 40
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"

    -- Fake debuff icons for preview
    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 4
    local fakeDebuffIcons = {}
    local sampleIcons = {
        136096, -- Moonfire
        136118, -- Corruption
        132158, -- Nature's Grasp (Roots)
        136048, -- Insect Swarm
        132212, -- Faerie Fire
    }

    for i = 1, maxDebuffs do
        -- Cycle through samples
        local iconIndex = ((i - 1) % #sampleIcons) + 1
        table.insert(fakeDebuffIcons, sampleIcons[iconIndex])
    end

    for i = 1, 2 do
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
                frame.Health:SetValue(75) -- 75% health preview
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
                frame.Power:SetValue(50) -- 50% power preview
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
                frame.HealthText:SetText("75%")
                frame.HealthText:SetTextColor(1, 1, 1, 1)
                frame.HealthText:Show()
            end

            -- Show cast bar preview (so user can see spacing effect)
            if frame.CastBar then
                local castBarHeight = self:GetSetting(1, "CastBarHeight") or 14
                local castBarPosition = self:GetSetting(1, "CastBarPosition") or "Below"
                local showIcon = self:GetSetting(1, "CastBarIcon")
                local iconOffset = 0

                frame.CastBar:SetSize(width, castBarHeight)
                frame.CastBar:SetStatusBarTexture(texturePath)
                frame.CastBar:SetMinMaxValues(0, 3)
                frame.CastBar:SetValue(1.5)
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
                    frame.CastBar.Timer:SetText("1.5")
                end
                frame.CastBar:Show()
            end

            -- Show fake debuff icons preview
            self:ShowPreviewDebuffs(frame, fakeDebuffIcons)
        end
    end
end

function Orbit.BossFramePreviewMixin:ShowPreviewDebuffs(frame, icons)
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
    local numDebuffs = math.min(#icons, maxDebuffs)
    local spacing = 2

    if numDebuffs == 0 then
        return
    end

    -- Calculate Size & Layout
    local iconSize, xOffsetStep, yOffsetStep
    if isHorizontal then
        local totalSpacing = (maxDebuffs - 1) * spacing
        iconSize = (frameWidth - totalSpacing) / maxDebuffs
        xOffsetStep = iconSize + spacing
    else
        iconSize = frameHeight
        xOffsetStep = 0
    end

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

    -- Position container based on settings & collisions
    frame.debuffContainer:ClearAllPoints()

    local castBarPos = self:GetSetting(1, "CastBarPosition")
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or 14
    local castBarGap = 4
    local elementGap = 4

    if position == "Left" then
        frame.debuffContainer:SetPoint("RIGHT", frame, "LEFT", -4, 0)
        frame.debuffContainer:SetSize((numDebuffs * iconSize) + ((numDebuffs - 1) * spacing), iconSize)
    elseif position == "Right" then
        frame.debuffContainer:SetPoint("LEFT", frame, "RIGHT", 4, 0)
        frame.debuffContainer:SetSize((numDebuffs * iconSize) + ((numDebuffs - 1) * spacing), iconSize)
    elseif position == "Above" then
        local yOffset = elementGap
        if castBarPos == "Above" then
            yOffset = yOffset + castBarHeight + castBarGap
        end
        frame.debuffContainer:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, yOffset)
        frame.debuffContainer:SetSize(frameWidth, iconSize)
    elseif position == "Below" then
        local yOffset = -elementGap
        if castBarPos == "Below" then
            yOffset = yOffset - castBarHeight - castBarGap
        end
        frame.debuffContainer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, yOffset)
        frame.debuffContainer:SetSize(frameWidth, iconSize)
    end

    -- Settings for Skin
    local globalBorder = self:GetPlayerSetting("BorderSize") or 1
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
        icon:ClearAllPoints()

        if isHorizontal then
            icon:SetPoint("TOPLEFT", frame.debuffContainer, "TOPLEFT", currentX, 0)
            currentX = currentX + xOffsetStep
        elseif position == "Left" then
            icon:SetPoint("TOPRIGHT", frame.debuffContainer, "TOPRIGHT", -currentX, 0)
            currentX = currentX + iconSize + spacing
        else -- Right
            icon:SetPoint("TOPLEFT", frame.debuffContainer, "TOPLEFT", currentX, 0)
            currentX = currentX + iconSize + spacing
        end

        -- Set fake texture
        icon.Icon:SetTexture(icons[i])

        -- Apply Skin
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
        end

        -- Fake Cooldown
        icon.Cooldown:SetCooldown(GetTime() - 10, 60)
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

        -- Hide preview debuffs
        if frame.previewDebuffs then
            for _, icon in ipairs(frame.previewDebuffs) do
                icon:Hide()
            end
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
    if not previewVisualsScheduled then
        previewVisualsScheduled = true
        C_Timer.After(0.1, function()
            previewVisualsScheduled = false
            self:ApplyPreviewVisuals()
        end)
    end
end
