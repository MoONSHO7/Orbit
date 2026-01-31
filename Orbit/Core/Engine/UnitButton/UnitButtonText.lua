-- [ UNIT BUTTON - TEXT MODULE ]---------------------------------------------------------------------
-- Health text and name text formatting and display
-- This module extends UnitButtonMixin with text-related functionality

local _, Orbit = ...
local Engine = Orbit.Engine

-- Ensure UnitButton namespace exists
Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ HEALTH TEXT MODES ]-----------------------------------------------------------------------------
-- Export modes for use by plugins
local HEALTH_TEXT_MODES = {
    HIDE = "hide",
    PERCENT_SHORT = "percent_short",
    PERCENT_RAW = "percent_raw",
    SHORT_PERCENT = "short_percent",
    SHORT_RAW = "short_raw",
    RAW_SHORT = "raw_short",
    RAW_PERCENT = "raw_percent",
}
UnitButton.HEALTH_TEXT_MODES = HEALTH_TEXT_MODES

-- [ LOCAL FORMATTERS ]------------------------------------------------------------------------------

local function SafeHealthPercent(unit)
    if type(UnitHealthPercent) ~= "function" then
        return nil
    end
    if not CurveConstants or not CurveConstants.ScaleTo100 then
        return nil
    end
    local ok, pct = pcall(UnitHealthPercent, unit, true, CurveConstants.ScaleTo100)
    if ok and pct ~= nil and type(pct) == "number" then
        return pct
    end
    return nil
end

local function FormatHealthPercent(unit)
    local percent = SafeHealthPercent(unit)
    if not percent then
        return nil
    end
    return string.format("%.0f%%", percent)
end

local function FormatShortHealth(unit)
    local health = UnitHealth(unit)

    if AbbreviateLargeNumbers and health then
        local ok, result = pcall(AbbreviateLargeNumbers, health)
        if ok and result then
            return result
        end
    end
    return nil
end

local function FormatRawHealth(unit)
    local health = UnitHealth(unit)
    if health and type(health) == "number" then
        -- Format with thousands separator
        if BreakUpLargeNumbers then
            local ok, result = pcall(BreakUpLargeNumbers, health)
            if ok and result then
                return result
            end
        end
        return tostring(health)
    end
    return nil
end

local function GetHealthTextForFormat(unit, format)
    if format == "percent" then
        return FormatHealthPercent(unit) or "??%"
    elseif format == "short" then
        return FormatShortHealth(unit) or "???"
    elseif format == "raw" then
        return FormatRawHealth(unit) or "???"
    end
    return "???"
end

-- [ TEXT MIXIN ]------------------------------------------------------------------------------------
-- Partial mixin for text functionality (will be merged into UnitButtonMixin)

local TextMixin = {}

function TextMixin:GetHealthTextFormats()
    local mode = self.healthTextMode or HEALTH_TEXT_MODES.PERCENT_SHORT

    local formatMap = {
        [HEALTH_TEXT_MODES.PERCENT_SHORT] = { "percent", "short" },
        [HEALTH_TEXT_MODES.PERCENT_RAW] = { "percent", "raw" },
        [HEALTH_TEXT_MODES.SHORT_PERCENT] = { "short", "percent" },
        [HEALTH_TEXT_MODES.SHORT_RAW] = { "short", "raw" },
        [HEALTH_TEXT_MODES.RAW_SHORT] = { "raw", "short" },
        [HEALTH_TEXT_MODES.RAW_PERCENT] = { "raw", "percent" },
    }

    local formats = formatMap[mode] or { "percent", "short" }
    return formats[1], formats[2]
end

function TextMixin:UpdateHealthText()
    if not self.HealthText then
        return
    end
    
    -- Check if component is disabled via plugin (Canvas Mode drag-to-disable)
    if self.orbitPlugin and self.orbitPlugin.IsComponentDisabled then
        if self.orbitPlugin:IsComponentDisabled("HealthText") then
            self.HealthText:Hide()
            return
        end
    end

    local mode = self.healthTextMode or HEALTH_TEXT_MODES.PERCENT_SHORT

    -- Handle Hide mode
    if mode == HEALTH_TEXT_MODES.HIDE then
        self.HealthText:Hide()
        return
    end

    if self.healthTextEnabled == false then
        self.HealthText:Hide()
        return
    end
    
    -- Guard against nil unit
    if not self.unit then
        self.HealthText:SetText("")
        self.HealthText:Hide()
        return
    end

    if UnitIsDeadOrGhost(self.unit) then
        self.HealthText:SetText("Dead")
        self.HealthText:Show()
        return
    end

    -- Parse mode to get main/mouseover formats
    local mainFormat, mouseoverFormat = self:GetHealthTextFormats()

    local text
    if self.isMouseOver then
        text = GetHealthTextForFormat(self.unit, mouseoverFormat)
    else
        text = GetHealthTextForFormat(self.unit, mainFormat)
    end

    self.HealthText:SetText(text)
    self.HealthText:Show()
    
    -- Apply text color based on global settings
    self:ApplyHealthTextColor()
end

function TextMixin:SetMouseOver(isOver)
    -- Skip mouseover updates during Edit Mode to allow component dragging
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
        return
    end
    
    self.isMouseOver = isOver
    self:UpdateHealthText()
end

function TextMixin:SetHealthTextEnabled(enabled)
    self.healthTextEnabled = enabled
    self:UpdateHealthText()
end

function TextMixin:SetHealthTextMode(mode)
    self.healthTextMode = mode
    -- If mode is not hide, ensure healthTextEnabled is true
    if mode ~= HEALTH_TEXT_MODES.HIDE then
        self.healthTextEnabled = true
    end
    self:UpdateHealthText()
end

function TextMixin:UpdateName()
    if not self.Name then
        return
    end
    
    -- Check if component is disabled via plugin (Canvas Mode drag-to-disable)
    if self.orbitPlugin and self.orbitPlugin.IsComponentDisabled then
        if self.orbitPlugin:IsComponentDisabled("Name") then
            self.Name:Hide()
            return
        end
    end
    
    -- Show name (may have been hidden by disabled state)
    self.Name:Show()
    
    -- Guard against nil unit
    if not self.unit then
        self.Name:SetText("")
        return
    end
    
    local name = UnitName(self.unit)

    -- Handle nil/invalid names
    if name == nil then
        self.Name:SetText("")
        return
    end

    -- WoW 12.0: UnitName returns secret values for non-player units during combat
    -- Secret values can be passed to SetText but cannot have string operations performed on them
    if issecretvalue and issecretvalue(name) then
        self.Name:SetText(name) -- FontString:SetText accepts secret values
        return
    end

    -- Non-secret string: safe to truncate
    if type(name) ~= "string" then
        self.Name:SetText("")
        return
    end

    local maxChars = 15

    local frameWidth = self:GetWidth()
    if type(frameWidth) == "number" and frameWidth > 0 then
        -- Estimate HealthText reserved width based on font size (avoids secret value issues)
        -- "100%" is ~4-5 chars, estimate ~0.6x font height per character
        local fontName, fontHeight = self.HealthText and self.HealthText:GetFont()
        fontHeight = fontHeight or 12
        local estimatedHealthTextWidth = fontHeight * 3  -- Approximate width for "100%"
        
        -- Available width = frame - healthText space - padding
        local availableWidth = frameWidth - estimatedHealthTextWidth - 20
        
        -- Estimate characters: assume ~0.5x font height per character average
        local charWidth = fontHeight * 0.5
        maxChars = math.floor(availableWidth / charWidth)
        maxChars = math.max(6, math.min(maxChars, 30)) -- Clamp between 6-30
    end

    if #name > maxChars then
        self.Name:SetText(string.sub(name, 1, maxChars))
    else
        self.Name:SetText(name)
    end
    
    -- Apply text color based on global settings and component overrides
    self:ApplyNameColor()
end

-- Apply color to Name text based on global settings and component overrides
function TextMixin:ApplyNameColor()
    if not self.Name then return end
    
    -- Check for component-level custom color override (from Canvas Mode)
    local customColorOverride = nil
    if self.orbitPlugin then
        local systemIndex = self.systemIndex or 1
        local positions = self.orbitPlugin:GetSetting(systemIndex, "ComponentPositions")
        if positions and positions.Name and positions.Name.overrides then
            local overrides = positions.Name.overrides
            if overrides.CustomColor and overrides.CustomColorValue then
                customColorOverride = overrides.CustomColorValue
            end
        end
    end
    
    if customColorOverride and type(customColorOverride) == "table" then
        -- Use component-level override
        self.Name:SetTextColor(customColorOverride.r or 1, customColorOverride.g or 1, customColorOverride.b or 1, customColorOverride.a or 1)
        return
    end
    
    -- Use global font color settings
    local globalSettings = Orbit.db and Orbit.db.GlobalSettings or {}
    local useClassColorFont = globalSettings.UseClassColorFont ~= false  -- Default true
    
    if useClassColorFont then
        -- Use class color for players, reaction color for NPCs
        if self.unit and UnitIsPlayer(self.unit) then
            local _, class = UnitClass(self.unit)
            if class then
                local classColor = RAID_CLASS_COLORS[class]
                if classColor then
                    self.Name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
                    return
                end
            end
        else
            -- NPC: use reaction color
            if self.unit and UnitExists(self.unit) then
                local reaction = UnitReaction(self.unit, "player")
                if reaction then
                    local reactionColor = FACTION_BAR_COLORS[reaction]
                    if reactionColor then
                        self.Name:SetTextColor(reactionColor.r, reactionColor.g, reactionColor.b, 1)
                        return
                    end
                end
            end
        end
        -- Fallback to white if no class/reaction color found
        self.Name:SetTextColor(1, 1, 1, 1)
    else
        -- Use global font color
        local fontColor = globalSettings.FontColor or { r = 1, g = 1, b = 1, a = 1 }
        self.Name:SetTextColor(fontColor.r, fontColor.g, fontColor.b, fontColor.a or 1)
    end
end

-- Apply color to HealthText based on global settings and component overrides
function TextMixin:ApplyHealthTextColor()
    if not self.HealthText then return end
    
    -- Check for component-level custom color override (from Canvas Mode)
    local customColorOverride = nil
    if self.orbitPlugin then
        local systemIndex = self.systemIndex or 1
        local positions = self.orbitPlugin:GetSetting(systemIndex, "ComponentPositions")
        if positions and positions.HealthText and positions.HealthText.overrides then
            local overrides = positions.HealthText.overrides
            if overrides.CustomColor and overrides.CustomColorValue then
                customColorOverride = overrides.CustomColorValue
            end
        end
    end
    
    if customColorOverride and type(customColorOverride) == "table" then
        -- Use component-level override
        self.HealthText:SetTextColor(customColorOverride.r or 1, customColorOverride.g or 1, customColorOverride.b or 1, customColorOverride.a or 1)
        return
    end
    
    -- Use global font color settings
    local globalSettings = Orbit.db and Orbit.db.GlobalSettings or {}
    local useClassColorFont = globalSettings.UseClassColorFont ~= false  -- Default true
    
    if useClassColorFont then
        -- Use class color for players, reaction color for NPCs (same as name)
        if self.unit and UnitIsPlayer(self.unit) then
            local _, class = UnitClass(self.unit)
            if class then
                local classColor = RAID_CLASS_COLORS[class]
                if classColor then
                    self.HealthText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
                    return
                end
            end
        else
            -- NPC: use reaction color
            if self.unit and UnitExists(self.unit) then
                local reaction = UnitReaction(self.unit, "player")
                if reaction then
                    local reactionColor = FACTION_BAR_COLORS[reaction]
                    if reactionColor then
                        self.HealthText:SetTextColor(reactionColor.r, reactionColor.g, reactionColor.b, 1)
                        return
                    end
                end
            end
        end
        -- Fallback to white if no class/reaction color found
        self.HealthText:SetTextColor(1, 1, 1, 1)
    else
        -- Use global font color
        local fontColor = globalSettings.FontColor or { r = 1, g = 1, b = 1, a = 1 }
        self.HealthText:SetTextColor(fontColor.r, fontColor.g, fontColor.b, fontColor.a or 1)
    end
end

-- Export for composition
UnitButton.TextMixin = TextMixin
