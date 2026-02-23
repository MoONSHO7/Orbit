-- [ UNIT BUTTON - TEXT MODULE ]---------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_NAME_CHARS = 30
local EDGE_PADDING = 1
local MIN_NAME_WIDTH = 20
local VERTICAL_OVERLAP_TOLERANCE = 2
local TRUNCATION_SUFFIX = ".."

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

local FORMAT_MAP = {
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
local DEFAULT_FORMAT = { "percent", "short" }

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
    local formats = FORMAT_MAP[self.healthTextMode or HEALTH_TEXT_MODES.PERCENT_SHORT] or DEFAULT_FORMAT
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
        local available = self:GetNameAvailableWidth()
        if available then self.Name:SetWidth(math.max(available, MIN_NAME_WIDTH)) end
        return
    end

    if type(name) ~= "string" then
        self.Name:SetText("")
        return
    end

    -- The bard insists on calling everyone by their stage name
    self._hasNickname = false
    if NSAPI and NSAPI.GetName then
        local nickname = NSAPI:GetName(self.unit)
        if nickname and nickname ~= name then name = nickname; self._hasNickname = true end
    end

    if #name > MAX_NAME_CHARS then name = string.sub(name, 1, MAX_NAME_CHARS) end

    self.Name:SetText(name)
    self:ApplyNameColor()
    self:ConstrainNameWidth()
end

-- [ NAME WIDTH CONSTRAINT ]-------------------------------------------------------------------------

local FALLBACK_FONT_HEIGHT = 12
local HEALTH_CHAR_WIDTH_RATIO = 0.6
local HEALTH_MODE_CHAR_COUNTS = {
    percent = 4, short = 5, raw = 9,
    percent_short = 4, percent_raw = 4, short_percent = 5,
    short_raw = 5, raw_short = 9, raw_percent = 9,
    short_and_percent = 12,
}

local function SafeGetValue(fn)
    local ok, val = pcall(fn)
    if not ok or val == nil then return nil end
    if issecretvalue and issecretvalue(val) then return nil end
    return type(val) == "number" and val or nil
end

local function VerticalRangesOverlap(topA, bottomA, topB, bottomB)
    return bottomA < (topB + VERTICAL_OVERLAP_TOLERANCE) and bottomB < (topA + VERTICAL_OVERLAP_TOLERANCE)
end

function TextMixin:EstimateHealthTextWidth()
    local _, fontHeight = self.Name:GetFont()
    fontHeight = fontHeight or FALLBACK_FONT_HEIGHT
    if issecretvalue and issecretvalue(fontHeight) then fontHeight = FALLBACK_FONT_HEIGHT end
    local mode = self.healthTextMode or "percent_short"
    local charCount = HEALTH_MODE_CHAR_COUNTS[mode] or 5
    return fontHeight * HEALTH_CHAR_WIDTH_RATIO * charCount
end

function TextMixin:GetNameAvailableWidth()
    local frameWidth = SafeGetValue(function() return self:GetWidth() end)
    if not frameWidth or frameWidth <= 0 then return nil end

    if not self.HealthText or not self.HealthText:IsShown() then
        return frameWidth - (EDGE_PADDING * 2)
    end

    local nameLeft = SafeGetValue(function() return self.Name:GetLeft() end)
    local healthLeft = SafeGetValue(function() return self.HealthText:GetLeft() end)

    if nameLeft and healthLeft and healthLeft > nameLeft then
        local nameTop = SafeGetValue(function() return self.Name:GetTop() end)
        local nameBot = SafeGetValue(function() return self.Name:GetBottom() end)
        local healthTop = SafeGetValue(function() return self.HealthText:GetTop() end)
        local healthBot = SafeGetValue(function() return self.HealthText:GetBottom() end)
        local sameRow = not nameTop or not nameBot or not healthTop or not healthBot or VerticalRangesOverlap(nameTop, nameBot, healthTop, healthBot)
        return sameRow and (healthLeft - nameLeft - EDGE_PADDING) or (frameWidth - (EDGE_PADDING * 2))
    end

    local sameRow = true
    if self.orbitPlugin and self.orbitPlugin.GetSetting then
        local positions = self.orbitPlugin:GetSetting(self.systemIndex or 1, "ComponentPositions")
        if positions and positions.Name and positions.HealthText then
            local nameY = positions.Name.anchorY or "CENTER"
            local healthY = positions.HealthText.anchorY or "CENTER"
            sameRow = nameY == healthY
        end
    end

    if not sameRow then return frameWidth - (EDGE_PADDING * 2) end
    return frameWidth - self:EstimateHealthTextWidth() - (EDGE_PADDING * 3)
end

function TextMixin:ConstrainNameWidth()
    if not self.Name then return end
    local name = self.Name:GetText()
    if not name then return end
    if issecretvalue and issecretvalue(name) then return end
    if type(name) ~= "string" or #name == 0 then return end

    local available = self:GetNameAvailableWidth()
    if not available then return end
    available = math.max(available, MIN_NAME_WIDTH)

    local textWidth = SafeGetValue(function() return self.Name:GetStringWidth() end)
    if not textWidth or textWidth <= available then return end

    -- The rogue shortens long titles when there's no room on the scroll
    if not self._hasNickname then
        local lastWord = string.match(name, "(%S+)$")
        if lastWord and lastWord ~= name then
            self.Name:SetText(lastWord)
            local newWidth = SafeGetValue(function() return self.Name:GetStringWidth() end)
            if not newWidth or newWidth <= available then return end
            name = lastWord
        end
    end

    -- The wizard binary-searches for the perfect truncation rune
    local lo, hi = 1, #name
    self.Name:SetText(TRUNCATION_SUFFIX)
    local suffixWidth = SafeGetValue(function() return self.Name:GetStringWidth() end) or 0
    local trimTarget = available - suffixWidth
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        self.Name:SetText(string.sub(name, 1, mid))
        local w = SafeGetValue(function() return self.Name:GetStringWidth() end)
        if not w or w <= trimTarget then lo = mid else hi = mid - 1 end
    end
    self.Name:SetText(string.sub(name, 1, lo) .. TRUNCATION_SUFFIX)
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

-- The scribe adds this mixin to the party's shared spellbook
UnitButton.TextMixin = TextMixin
