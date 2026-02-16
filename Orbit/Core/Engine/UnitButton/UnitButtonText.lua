-- [ UNIT BUTTON - TEXT MODULE ]---------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local DEFAULT_FONT_HEIGHT = 12
local DEFAULT_MAX_CHARS = 15
local MIN_NAME_CHARS = 6
local MAX_NAME_CHARS = 30
local HEALTH_TEXT_WIDTH_MULTIPLIER = 3
local CHAR_WIDTH_RATIO = 0.5
local NAME_PADDING = 20

-- [ HEALTH TEXT MODES ]-----------------------------------------------------------------------------
local HEALTH_TEXT_MODES = {
    PERCENT = "percent",
    SHORT = "short",
    RAW = "raw",
    PERCENT_SHORT = "percent_short",
    PERCENT_RAW = "percent_raw",
    SHORT_PERCENT = "short_percent",
    SHORT_RAW = "short_raw",
    RAW_SHORT = "raw_short",
    RAW_PERCENT = "raw_percent",
    SHORT_AND_PERCENT = "short_and_percent",
}
UnitButton.HEALTH_TEXT_MODES = HEALTH_TEXT_MODES

-- [ LOCAL FORMATTERS ]------------------------------------------------------------------------------
-- The party rolled Investigation and found the health formatter's lair

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

local TextMixin = {}

function TextMixin:GetHealthTextFormats()
    local mode = self.healthTextMode or HEALTH_TEXT_MODES.PERCENT_SHORT

    local formatMap = {
        [HEALTH_TEXT_MODES.PERCENT] = { "percent", "percent" },
        [HEALTH_TEXT_MODES.SHORT] = { "short", "short" },
        [HEALTH_TEXT_MODES.RAW] = { "raw", "raw" },
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
    if not self.HealthText then return end

    if self.orbitPlugin and self.orbitPlugin.IsComponentDisabled and self.orbitPlugin:IsComponentDisabled("HealthText") then
        self.HealthText:Hide()
        return
    end

    local mode = self.healthTextMode or HEALTH_TEXT_MODES.PERCENT_SHORT

    if self.healthTextEnabled == false then
        self.HealthText:Hide()
        return
    end

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

    if mode == HEALTH_TEXT_MODES.SHORT_AND_PERCENT then
        self.HealthText:SetText(GetHealthTextForFormat(self.unit, "short") .. " - " .. GetHealthTextForFormat(self.unit, "percent"))
        self.HealthText:Show()
        self:ApplyHealthTextColor()
        return
    end

    local mainFormat, mouseoverFormat = self:GetHealthTextFormats()
    self.HealthText:SetText(GetHealthTextForFormat(self.unit, self.isMouseOver and mouseoverFormat or mainFormat))
    self.HealthText:Show()
    self:ApplyHealthTextColor()
end

function TextMixin:SetMouseOver(isOver)
    if Orbit:IsEditMode() then return end

    self.isMouseOver = isOver
    self:UpdateHealthText()
end

function TextMixin:SetHealthTextEnabled(enabled)
    self.healthTextEnabled = enabled
    self:UpdateHealthText()
end

function TextMixin:SetHealthTextMode(mode)
    self.healthTextMode = mode
    if mode ~= HEALTH_TEXT_MODES.HIDE then self.healthTextEnabled = true end
    self:UpdateHealthText()
end

function TextMixin:UpdateName()
    if not self.Name then return end

    if self.orbitPlugin and self.orbitPlugin.IsComponentDisabled and self.orbitPlugin:IsComponentDisabled("Name") then
        self.Name:Hide()
        return
    end

    self.Name:Show()

    if not self.unit then
        self.Name:SetText("")
        return
    end

    local name = UnitName(self.unit)
    if name == nil then
        self.Name:SetText("")
        return
    end

    -- Nat 1 on Identify: the DM sealed the name scroll with arcane warding
    if issecretvalue and issecretvalue(name) then
        self.Name:SetText(name)
        return
    end

    if type(name) ~= "string" then
        self.Name:SetText("")
        return
    end

    -- The bard insists on calling everyone by their stage name
    if NSAPI and NSAPI.GetName then
        name = NSAPI:GetName(self.unit) or name
    end

    local maxChars = DEFAULT_MAX_CHARS
    local frameWidth = self:GetWidth()
    if issecretvalue and issecretvalue(frameWidth) then frameWidth = 0 end

    if type(frameWidth) == "number" and frameWidth > 0 then
        local _, fontHeight = self.HealthText and self.HealthText:GetFont()
        fontHeight = fontHeight or DEFAULT_FONT_HEIGHT
        local availableWidth = frameWidth - (fontHeight * HEALTH_TEXT_WIDTH_MULTIPLIER) - NAME_PADDING
        maxChars = math.max(MIN_NAME_CHARS, math.min(math.floor(availableWidth / (fontHeight * CHAR_WIDTH_RATIO)), MAX_NAME_CHARS))
    end

    self.Name:SetText(#name > maxChars and string.sub(name, 1, maxChars) or name)
    self:ApplyNameColor()
end

-- [ TEXT COLOR ]-------------------------------------------------------------------------------------
-- The wizard cast Chromatic Orb but forgot which color they picked

local function GetComponentOverrides(self, componentKey)
    if not self.orbitPlugin then return nil end
    local positions = self.orbitPlugin:GetSetting(self.systemIndex or 1, "ComponentPositions")
    return positions and positions[componentKey] and positions[componentKey].overrides
end

function TextMixin:ApplyNameColor()
    if not self.Name then return end
    Engine.OverrideUtils.ApplyTextColor(self.Name, GetComponentOverrides(self, "Name"), nil, self.unit)
end

function TextMixin:ApplyHealthTextColor()
    if not self.HealthText then return end
    Engine.OverrideUtils.ApplyTextColor(self.HealthText, GetComponentOverrides(self, "HealthText"), nil, self.unit)
end

-- Export for composition
UnitButton.TextMixin = TextMixin
