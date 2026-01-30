---@type Orbit
local Orbit = Orbit
local LSM = LibStub("LibSharedMedia-3.0")

-- Define Mixin
Orbit.PartyFramePreviewMixin = {}

-- Reference to shared helpers
local Helpers = nil -- Will be set when first needed

-- Constants
local MAX_PREVIEW_FRAMES = 5  -- 4 party + 1 potential player
local DEBOUNCE_DELAY = Orbit.Constants.Timing.DefaultDebounce

-- Combat-safe wrappers (matches PartyFrame.lua)
local function SafeRegisterUnitWatch(frame)
    if not frame then return end
    Orbit:SafeAction(function()
        RegisterUnitWatch(frame)
    end)
end

local function SafeUnregisterUnitWatch(frame)
    if not frame then return end
    Orbit:SafeAction(function()
        UnregisterUnitWatch(frame)
    end)
end

-- Preview defaults - varied values for realistic appearance
local PREVIEW_DEFAULTS = {
    HealthPercents = { 95, 72, 45, 28, 100 },  -- 5th is player
    PowerPercents = { 85, 60, 40, 15, 80 },
    Names = { "Healbot", "Tankenstein", "Stabby", "Pyromancer", "You" },
    Classes = { "PRIEST", "WARRIOR", "ROGUE", "MAGE", "PALADIN" },
    AuraSpacing = 2,
    FakeCooldownElapsed = 10,   -- Seconds already elapsed on fake cooldown
    FakeCooldownDuration = 60,  -- Total fake cooldown duration
}

-- Sample debuff icons for preview (harmful auras)
local SAMPLE_DEBUFF_ICONS = {
    136096, -- Moonfire
    136118, -- Corruption
    132158, -- Nature's Grasp (Roots)
    136048, -- Insect Swarm
    132212, -- Faerie Fire
}

-- Sample buff icons for preview (helpful auras from player)
local SAMPLE_BUFF_ICONS = {
    135907, -- Rejuvenation
    136048, -- Regrowth
    136041, -- Power Word: Shield
    135944, -- Renew
    135987, -- Earth Shield
}

-- [ PREVIEW LOGIC ]---------------------------------------------------------------------------------

function Orbit.PartyFramePreviewMixin:ShowPreview()
    -- Preview is blocked in combat (protected function calls)
    if InCombatLockdown() then
        return
    end
    if not self.frames or not self.container then
        return
    end

    -- Lazy-load helpers reference
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end

    -- Disable visibility driver for preview so we can manually show frames
    UnregisterStateDriver(self.container, "visibility")
    self.container:Show()

    -- Check if we're in Canvas Mode (right-click component editing)
    local isCanvasMode = false
    local OrbitEngine = Orbit.Engine
    if OrbitEngine and OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then
        -- Canvas Mode active on one of our frames
        for _, frame in ipairs(self.frames) do
            if OrbitEngine.CanvasMode.currentFrame == frame then
                isCanvasMode = true
                break
            end
        end
    end

    -- In Canvas Mode show only 1 frame; in Edit Mode show based on settings
    local includePlayer = self:GetSetting(1, "IncludePlayer")
    local baseFrames = isCanvasMode and 1 or 4
    local framesToShow = includePlayer and (baseFrames + 1) or baseFrames

    -- Disable UnitWatch and show frames for preview
    for i = 1, MAX_PREVIEW_FRAMES do
        if self.frames[i] then
            SafeUnregisterUnitWatch(self.frames[i])
            self.frames[i].preview = true
            if i <= framesToShow then
                self.frames[i]:Show()
            else
                self.frames[i]:Hide()
            end
        end
    end

    -- Position frames within container
    self:PositionFrames()

    -- Update container size for preview
    self:UpdateContainerSize()

    -- Apply preview visuals after a short delay to ensure they aren't overwritten
    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.frames then
            self:ApplyPreviewVisuals()
        end
    end)
end

function Orbit.PartyFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then
        return
    end

    -- Lazy-load helpers
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end

    -- Check if we're in Canvas Mode (right-click component editing)
    local isCanvasMode = false
    local OrbitEngine = Orbit.Engine
    if OrbitEngine and OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then
        -- Canvas Mode is active on one of our frames (or container)
        for _, frame in ipairs(self.frames) do
            if OrbitEngine.CanvasMode.currentFrame == frame or 
               OrbitEngine.CanvasMode.currentFrame == self.container then
                isCanvasMode = true
                break
            end
        end
    end

    -- Get settings
    local width = self:GetSetting(1, "Width") or Helpers.LAYOUT.DefaultWidth
    local height = self:GetSetting(1, "Height") or Helpers.LAYOUT.DefaultHeight
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
    local borderSize = (self.GetPlayerSetting and self:GetPlayerSetting("BorderSize")) or 1

    for i = 1, MAX_PREVIEW_FRAMES do
        if self.frames[i] and self.frames[i].preview then
            local frame = self.frames[i]

            -- Set frame size
            frame:SetSize(width, height)

            -- Update layout for power bar positioning
            Helpers:UpdateFrameLayout(frame, borderSize)

            -- Apply texture and set up health bar
            if frame.Health then
                frame.Health:SetStatusBarTexture(texturePath)
                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(PREVIEW_DEFAULTS.HealthPercents[i])

                -- Apply class color
                local classColor = C_ClassColor.GetClassColor(PREVIEW_DEFAULTS.Classes[i])
                if classColor then
                    frame.Health:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
                end
                frame.Health:Show()
            end

            -- Apply texture and set up power bar (respect ShowPowerBar setting)
            local showPower = self:GetSetting(1, "ShowPowerBar")
            if showPower == nil then showPower = true end

            if frame.Power then
                if showPower then
                    frame.Power:SetStatusBarTexture(texturePath)
                    frame.Power:SetMinMaxValues(0, 100)
                    frame.Power:SetValue(PREVIEW_DEFAULTS.PowerPercents[i])
                    frame.Power:SetStatusBarColor(0, 0.5, 1) -- Mana blue
                    frame.Power:Show()
                else
                    frame.Power:Hide()
                end
            end

            -- Update health bar to fill space when power bar hidden
            if frame.Health then
                local inset = borderSize or 1
                frame.Health:ClearAllPoints()
                if showPower then
                    local powerHeight = height * 0.2
                    frame.Health:SetPoint("TOPLEFT", inset, -inset)
                    frame.Health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, powerHeight + inset)
                else
                    frame.Health:SetPoint("TOPLEFT", inset, -inset)
                    frame.Health:SetPoint("BOTTOMRIGHT", -inset, inset)
                end
            end

            -- Preview name - ensure visible and override any unit data
            if frame.Name then
                frame.Name:SetText(PREVIEW_DEFAULTS.Names[i])
                frame.Name:SetTextColor(1, 1, 1, 1)
                frame.Name:Show()
            end

            -- Preview health text - override UpdateHealthText
            if frame.HealthText then
                frame.HealthText:SetText(PREVIEW_DEFAULTS.HealthPercents[i] .. "%")
                frame.HealthText:SetTextColor(1, 1, 1, 1)
                frame.HealthText:Show()
            end

            -- Apply global text styling (font, size, shadow)
            if self.ApplyTextStyling then
                self:ApplyTextStyling(frame)
            end

            -- Preview Status Indicators
            -- Role Icon (show varied roles for preview)
            local previewRoles = { "HEALER", "TANK", "DAMAGER", "DAMAGER" }
            local roleAtlases = Orbit.RoleAtlases
            if self:GetSetting(1, "ShowRoleIcon") ~= false and frame.RoleIcon then
                local roleAtlas = roleAtlases[previewRoles[i]]
                if roleAtlas then
                    frame.RoleIcon:SetAtlas(roleAtlas)
                    frame.RoleIcon:Show()
                end
            elseif frame.RoleIcon then
                frame.RoleIcon:Hide()
            end
            
            -- Leader Icon (show on first frame only)
            if self:GetSetting(1, "ShowLeaderIcon") ~= false and frame.LeaderIcon then
                if i == 1 then
                    frame.LeaderIcon:SetAtlas(Orbit.IconPreviewAtlases.LeaderIcon)
                    frame.LeaderIcon:Show()
                else
                    frame.LeaderIcon:Hide()
                end
            elseif frame.LeaderIcon then
                frame.LeaderIcon:Hide()
            end
            
            -- Selection Highlight (show on second frame for preview)
            if self:GetSetting(1, "ShowSelectionHighlight") ~= false and frame.SelectionHighlight then
                if i == 2 then
                    frame.SelectionHighlight:Show()
                else
                    frame.SelectionHighlight:Hide()
                end
            elseif frame.SelectionHighlight then
                frame.SelectionHighlight:Hide()
            end
            
            -- Aggro Highlight (show on third frame - tank has aggro preview)
            if self:GetSetting(1, "ShowAggroHighlight") ~= false and frame.AggroHighlight then
                if i == 2 then  -- Tank has aggro
                    frame.AggroHighlight:SetVertexColor(1.0, 0.6, 0.0, 0.6) -- Orange
                    frame.AggroHighlight:Show()
                else
                    frame.AggroHighlight:Hide()
                end
            elseif frame.AggroHighlight then
                frame.AggroHighlight:Hide()
            end
            
            -- Center status icons - show in Canvas Mode for positioning, hide in normal preview
            if isCanvasMode then
                local iconSize = 24  -- Size for visibility
                local spacing = 28   -- Spacing between icons
                local previewAtlases = Orbit.IconPreviewAtlases or {}
                
                -- Phase Icon - show with mock atlas (offset left)
                if frame.PhaseIcon then
                    frame.PhaseIcon:SetAtlas(previewAtlases.PhaseIcon)
                    frame.PhaseIcon:SetSize(iconSize, iconSize)
                    -- Only set default position if no saved position exists
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.PhaseIcon then
                        frame.PhaseIcon:ClearAllPoints()
                        frame.PhaseIcon:SetPoint("CENTER", frame, "CENTER", -spacing * 1.5, 0)
                    end
                    frame.PhaseIcon:Show()
                end
                -- Ready Check Icon - show with mock atlas (offset left-center)
                if frame.ReadyCheckIcon then
                    frame.ReadyCheckIcon:SetAtlas(previewAtlases.ReadyCheckIcon)
                    frame.ReadyCheckIcon:SetSize(iconSize, iconSize)
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.ReadyCheckIcon then
                        frame.ReadyCheckIcon:ClearAllPoints()
                        frame.ReadyCheckIcon:SetPoint("CENTER", frame, "CENTER", -spacing * 0.5, 0)
                    end
                    frame.ReadyCheckIcon:Show()
                end
                -- Incoming Res Icon - show with mock atlas (offset right-center)
                if frame.ResIcon then
                    frame.ResIcon:SetAtlas(previewAtlases.ResIcon)
                    frame.ResIcon:SetSize(iconSize, iconSize)
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.ResIcon then
                        frame.ResIcon:ClearAllPoints()
                        frame.ResIcon:SetPoint("CENTER", frame, "CENTER", spacing * 0.5, 0)
                    end
                    frame.ResIcon:Show()
                end
                -- Incoming Summon Icon - show with mock atlas (offset right)
                if frame.SummonIcon then
                    frame.SummonIcon:SetAtlas(previewAtlases.SummonIcon)
                    frame.SummonIcon:SetSize(iconSize, iconSize)
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.SummonIcon then
                        frame.SummonIcon:ClearAllPoints()
                        frame.SummonIcon:SetPoint("CENTER", frame, "CENTER", spacing * 1.5, 0)
                    end
                    frame.SummonIcon:Show()
                end
            else
                -- Hide in normal Edit Mode preview (they overlap)
                if frame.PhaseIcon then frame.PhaseIcon:Hide() end
                if frame.ReadyCheckIcon then frame.ReadyCheckIcon:Hide() end
                if frame.ResIcon then frame.ResIcon:Hide() end
                if frame.SummonIcon then frame.SummonIcon:Hide() end
            end
            
            -- Hide real aura pools before showing preview auras
            if frame.debuffPool then
                frame.debuffPool:ReleaseAll()
            end
            if frame.buffPool then
                frame.buffPool:ReleaseAll()
            end
            
            -- Show preview auras (debuffs and buffs)
            self:ShowPreviewAuras(frame, i)
        end
    end
end

-- Show preview debuffs and buffs on a frame
function Orbit.PartyFramePreviewMixin:ShowPreviewAuras(frame, frameIndex)
    local orientation = self:GetSetting(1, "Orientation") or 0
    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 3
    local maxBuffs = self:GetSetting(1, "MaxBuffs") or 3
    
    -- Get orientation-specific position settings
    local debuffKey = orientation == 0 and "DebuffPositionVertical" or "DebuffPositionHorizontal"
    local buffKey = orientation == 0 and "BuffPositionVertical" or "BuffPositionHorizontal"
    local debuffPosition = self:GetSetting(1, debuffKey) or (orientation == 0 and "Right" or "Above")
    local buffPosition = self:GetSetting(1, buffKey) or (orientation == 0 and "Left" or "Below")
    
    -- Vary the number of icons shown per frame for variety
    local debuffCounts = { 2, 3, 1, 2, 0 }
    local buffCounts = { 3, 1, 2, 1, 0 }
    local numDebuffs = math.min(debuffCounts[frameIndex] or 2, maxDebuffs)
    local numBuffs = math.min(buffCounts[frameIndex] or 1, maxBuffs)
    
    -- Show debuffs
    self:ShowPreviewAuraIcons(frame, "debuff", debuffPosition, numDebuffs, maxDebuffs, SAMPLE_DEBUFF_ICONS)
    
    -- Show buffs
    self:ShowPreviewAuraIcons(frame, "buff", buffPosition, numBuffs, maxBuffs, SAMPLE_BUFF_ICONS)
end

-- Helper to show preview aura icons (debuffs or buffs)
function Orbit.PartyFramePreviewMixin:ShowPreviewAuraIcons(frame, auraType, position, numIcons, maxIcons, sampleIcons)
    local containerKey = auraType .. "Container"
    local poolKey = "preview" .. auraType:gsub("^%l", string.upper) .. "s"
    
    -- Handle disabled position
    if position == "Disabled" then
        if frame[containerKey] then
            frame[containerKey]:Hide()
        end
        return
    end
    
    if numIcons == 0 then
        if frame[containerKey] then
            frame[containerKey]:Hide()
        end
        return
    end
    
    -- Ensure container exists
    if not frame[containerKey] then
        frame[containerKey] = CreateFrame("Frame", nil, frame)
    end
    
    local container = frame[containerKey]
    container:SetParent(frame)
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(frame:GetFrameLevel() + 5)
    container:Show()
    
    -- Calculate layout
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()
    local isHorizontal = (position == "Above" or position == "Below")
    local spacing = PREVIEW_DEFAULTS.AuraSpacing
    
    -- Calculate icon size based on position
    local iconSize
    if isHorizontal then
        iconSize = (frameWidth - (maxIcons - 1) * spacing) / maxIcons
        iconSize = math.max(12, iconSize)
    else
        iconSize = frameHeight
        iconSize = math.max(12, iconSize)
    end
    
    -- Calculate container size
    local containerWidth, containerHeight
    if isHorizontal then
        containerWidth = (numIcons * iconSize) + ((numIcons - 1) * spacing)
        containerHeight = iconSize
    else
        containerWidth = (numIcons * iconSize) + ((numIcons - 1) * spacing)
        containerHeight = iconSize
    end
    
    container:SetSize(containerWidth, containerHeight)
    
    -- Position container
    container:ClearAllPoints()
    if position == "Above" then
        container:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    elseif position == "Below" then
        container:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    elseif position == "Left" then
        container:SetPoint("TOPRIGHT", frame, "TOPLEFT", -2, 0)
    elseif position == "Right" then
        container:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
    end
    
    -- Create preview icons array if needed
    if not frame[poolKey] then
        frame[poolKey] = {}
    end
    
    -- Hide existing preview icons
    for _, icon in ipairs(frame[poolKey]) do
        icon:Hide()
    end
    
    -- Skin settings
    local globalBorder = (self.GetPlayerSetting and self:GetPlayerSetting("BorderSize")) or 1
    local skinSettings = {
        zoom = 0,
        borderStyle = 1,
        borderSize = globalBorder,
        showTimer = true,
    }
    
    -- Create and position icons
    for i = 1, numIcons do
        local icon = frame[poolKey][i]
        if not icon then
            icon = CreateFrame("Button", nil, container, "BackdropTemplate")
            icon.Icon = icon:CreateTexture(nil, "ARTWORK")
            icon.Icon:SetAllPoints()
            icon.icon = icon.Icon
            
            icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
            icon.Cooldown:SetAllPoints()
            icon.Cooldown:SetHideCountdownNumbers(false)
            icon.cooldown = icon.Cooldown
            
            frame[poolKey][i] = icon
        end
        
        icon:SetParent(container)
        icon:SetSize(iconSize, iconSize)
        
        -- Position icon
        icon:ClearAllPoints()
        local xOffset = (i - 1) * (iconSize + spacing)
        if position == "Left" then
            -- Grow right-to-left (away from center)
            icon:SetPoint("TOPRIGHT", container, "TOPRIGHT", -xOffset, 0)
        else
            -- Grow left-to-right
            icon:SetPoint("TOPLEFT", container, "TOPLEFT", xOffset, 0)
        end
        
        -- Set texture (cycle through sample icons)
        local iconIndex = ((i - 1) % #sampleIcons) + 1
        icon.Icon:SetTexture(sampleIcons[iconIndex])
        
        -- Apply skin
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
        end
        
        -- Fake cooldown
        icon.Cooldown:SetCooldown(GetTime() - PREVIEW_DEFAULTS.FakeCooldownElapsed, PREVIEW_DEFAULTS.FakeCooldownDuration)
        icon.Cooldown:Show()
        
        icon:Show()
    end
end

function Orbit.PartyFramePreviewMixin:HidePreview()
    -- Combat check: Edit Mode auto-exits on combat start, so this should never be called during combat.
    -- If it somehow is, bail out safely.
    if InCombatLockdown() then
        return
    end

    if not self.frames then
        return
    end

    -- Restore visibility driver for normal gameplay (hide in raids)
    local visibilityDriver = "[petbattle] hide; [@raid1,exists] hide; [@party1,exists] show; hide"
    RegisterStateDriver(self.container, "visibility", visibilityDriver)

    for i, frame in ipairs(self.frames) do
        frame.preview = nil

        -- Restore visual visibility
        frame:SetAlpha(1)

        -- Restore UnitWatch for normal gameplay
        SafeRegisterUnitWatch(frame)
        
        -- Hide and clear preview debuffs
        if frame.previewDebuffs then
            for _, icon in ipairs(frame.previewDebuffs) do
                icon:Hide()
            end
            wipe(frame.previewDebuffs)
        end
        
        -- Hide and clear preview buffs
        if frame.previewBuffs then
            for _, icon in ipairs(frame.previewBuffs) do
                icon:Hide()
            end
            wipe(frame.previewBuffs)
        end

        -- Force refresh with real unit data (replaces preview values)
        if frame.UpdateAll then
            frame:UpdateAll()
        end
        
    end
    
    -- Reassign units based on current IncludePlayer setting (always sorted by role)
    if self.UpdateFrameUnits then
        self:UpdateFrameUnits()
    end

    -- Apply full settings to reset visuals
    if self.ApplySettings then
        self:ApplySettings()
    end

    -- Update container size
    self:UpdateContainerSize()
end

function Orbit.PartyFramePreviewMixin:SchedulePreviewUpdate()
    if not self._previewVisualsScheduled then
        self._previewVisualsScheduled = true
        C_Timer.After(DEBOUNCE_DELAY, function()
            self._previewVisualsScheduled = false
            if self.frames then
                self:ApplyPreviewVisuals()
                -- Reposition frames after size changes
                self:PositionFrames()
                self:UpdateContainerSize()
            end
        end)
    end
end
