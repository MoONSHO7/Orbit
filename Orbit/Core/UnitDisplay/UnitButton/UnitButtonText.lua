-- [ UNIT BUTTON - TEXT MODULE ]----------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local MAX_NAME_CHARS = 30
local EDGE_PADDING = 1
local MIN_NAME_WIDTH = 20
local VERTICAL_OVERLAP_TOLERANCE = 2
local TRUNCATION_SUFFIX = ".."

-- [ HEALTH TEXT MODES ]------------------------------------------------------------------------------
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

local DEFAULT_MODE = HEALTH_TEXT_MODES.PERCENT_SHORT

-- [ LOCAL FORMATTERS ]-------------------------------------------------------------------------------
-- Each token formatter returns a display string or a secret value (UnitHealth/UnitHealthMax are secret in
-- 12.0). RenderHealthText combines them with SetFormattedText, which accepts secret args C-side — never Lua concat.

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

-- AbbreviateNumbers accepts secret values (UnitHealth is secret in 12.0, where Lua arithmetic throws); the custom
-- breakpoints give a clean "466K" / "1.5M" with no decimal on thousands, abbreviating only above 10,000.
local HEALTH_ABBREV_BREAKPOINTS = {
    { breakpoint = 1000000, abbreviation = "M", abbreviationIsGlobal = false, significandDivisor = 100000, fractionDivisor = 10 },
    { breakpoint = 10000,   abbreviation = "K", abbreviationIsGlobal = false, significandDivisor = 1000,   fractionDivisor = 1 },
}
local healthAbbrevOpts
local function AbbreviateHealth(value)
    if not AbbreviateNumbers then return value end
    if healthAbbrevOpts == nil then
        healthAbbrevOpts = false
        if CreateAbbreviateConfig then
            local ok, config = pcall(CreateAbbreviateConfig, HEALTH_ABBREV_BREAKPOINTS)
            if ok and config then healthAbbrevOpts = { config = config } end
        end
    end
    return AbbreviateNumbers(value, healthAbbrevOpts or nil)
end

-- Short tokens abbreviate via the secret-safe C call; full tokens forward the raw value to the FontString sink, which renders a plain number (no separators).
local function FormatCurrentK(unit) return AbbreviateHealth(UnitHealth(unit)) end
local function FormatCurrentFull(unit) return UnitHealth(unit) end
local function FormatMaxK(unit) return AbbreviateHealth(UnitHealthMax(unit)) end
local function FormatMaxFull(unit) return UnitHealthMax(unit) end

-- [ HEALTH TOKENS ]----------------------------------------------------------------------------------
-- Canonical value vocabulary. `key` is the literal token the user types; `sample` is the example shown in the
-- input-box tooltip (read by Canvas Mode); `format(unit)` is the live sink.
local HEALTH_TOKENS = {
    { id = "percent",      key = "%",            sample = "100%",    format = function(u) return FormatHealthPercent(u) or "??%" end },
    { id = "currentk", key = "CurrentK", sample = "466K",    format = FormatCurrentK },
    { id = "current",      key = "Current",      sample = "466095",  format = FormatCurrentFull },
    { id = "maxk",     key = "MaxK",     sample = "500K",    format = FormatMaxK },
    { id = "max",          key = "Max",          sample = "500000",  format = FormatMaxFull },
}
local TOKEN_BY_ID = {}
for _, t in ipairs(HEALTH_TOKENS) do TOKEN_BY_ID[t.id] = t end
UnitButton.HEALTH_TOKENS = HEALTH_TOKENS

-- Parser key table, longest-first so a shorter key can't pre-empt a longer one; `&` is the mouseover divider.
local FORMAT_KEYS = {}
for _, t in ipairs(HEALTH_TOKENS) do FORMAT_KEYS[#FORMAT_KEYS + 1] = { key = t.key, id = t.id } end
FORMAT_KEYS[#FORMAT_KEYS + 1] = { key = "&", mo = true }
table.sort(FORMAT_KEYS, function(a, b) return #a.key > #b.key end)

-- [ LEGACY MODE MAPPING ]----------------------------------------------------------------------------
-- Maps the retired HealthTextMode presets onto the segment model so existing saved values render
-- unchanged (rest value + optional `&` mouseover-reveal).
local LEGACY_SEGMENTS = {
    [HEALTH_TEXT_MODES.PERCENT]           = { { t = "value", v = "percent" } },
    [HEALTH_TEXT_MODES.SHORT]             = { { t = "value", v = "currentk" } },
    [HEALTH_TEXT_MODES.RAW]               = { { t = "value", v = "current" } },
    [HEALTH_TEXT_MODES.PERCENT_SHORT]     = { { t = "value", v = "percent" }, { t = "mo" }, { t = "value", v = "currentk" } },
    [HEALTH_TEXT_MODES.PERCENT_RAW]       = { { t = "value", v = "percent" }, { t = "mo" }, { t = "value", v = "current" } },
    [HEALTH_TEXT_MODES.SHORT_PERCENT]     = { { t = "value", v = "currentk" }, { t = "mo" }, { t = "value", v = "percent" } },
    [HEALTH_TEXT_MODES.SHORT_RAW]         = { { t = "value", v = "currentk" }, { t = "mo" }, { t = "value", v = "current" } },
    [HEALTH_TEXT_MODES.RAW_SHORT]         = { { t = "value", v = "current" }, { t = "mo" }, { t = "value", v = "currentk" } },
    [HEALTH_TEXT_MODES.RAW_PERCENT]       = { { t = "value", v = "current" }, { t = "mo" }, { t = "value", v = "percent" } },
    [HEALTH_TEXT_MODES.SHORT_AND_PERCENT] = { { t = "value", v = "currentk" }, { t = "sep", v = " - " }, { t = "value", v = "percent" } },
}
local function LegacyModeToSegments(mode)
    return LEGACY_SEGMENTS[mode] or LEGACY_SEGMENTS[DEFAULT_MODE]
end

-- Typed-string equivalent of each legacy preset, used to seed the format input box for existing users.
local LEGACY_FORMAT_STRINGS = {
    [HEALTH_TEXT_MODES.PERCENT]           = "%",
    [HEALTH_TEXT_MODES.SHORT]             = "CurrentK",
    [HEALTH_TEXT_MODES.RAW]               = "Current",
    [HEALTH_TEXT_MODES.PERCENT_SHORT]     = "% & CurrentK",
    [HEALTH_TEXT_MODES.PERCENT_RAW]       = "% & Current",
    [HEALTH_TEXT_MODES.SHORT_PERCENT]     = "CurrentK & %",
    [HEALTH_TEXT_MODES.SHORT_RAW]         = "CurrentK & Current",
    [HEALTH_TEXT_MODES.RAW_SHORT]         = "Current & CurrentK",
    [HEALTH_TEXT_MODES.RAW_PERCENT]       = "Current & %",
    [HEALTH_TEXT_MODES.SHORT_AND_PERCENT] = "CurrentK - %",
}
function UnitButton.LegacyHealthModeToFormatString(mode)
    return LEGACY_FORMAT_STRINGS[mode] or LEGACY_FORMAT_STRINGS[DEFAULT_MODE]
end

-- [ SEGMENT RENDERING ]------------------------------------------------------------------------------
-- Values become `%s` slots, separators stay literal, and SetFormattedText fills them C-side. It accepts secret
-- args (AllowedWhenTainted), so several secret health values combine (e.g. "466K - 500K") — Lua concat would throw.
local function RenderHealthText(fs, unit, segs)
    local parts, values = {}, {}
    for _, seg in ipairs(segs) do
        if seg.t == "value" then
            local token = TOKEN_BY_ID[seg.v]
            if token then
                parts[#parts + 1] = "%s"
                values[#values + 1] = token.format(unit)
            end
        elseif seg.t == "sep" then
            parts[#parts + 1] = (seg.v or ""):gsub("%%", "%%%%")
        end
    end
    fs:SetFormattedText(table.concat(parts), unpack(values))
end

-- [ FORMAT STRING PARSING ]--------------------------------------------------------------------------
-- Parses a typed format string into segments. Recognized keys (longest-first) become value/mouseover
-- segments; all other characters are literal text. Whitespace adjacent to the `&` divider is trimmed.
local function ParseFormat(str)
    str = strtrim(str or "")
    local segments = {}
    local buffer, trimNextLeading = "", false
    local function pushBuffer(trimTrailing)
        local b = buffer
        buffer = ""
        if trimNextLeading then b = b:gsub("^%s+", ""); trimNextLeading = false end
        if trimTrailing then b = b:gsub("%s+$", "") end
        if b ~= "" then segments[#segments + 1] = { t = "sep", v = b } end
    end
    local i, n = 1, #str
    while i <= n do
        local matched
        for _, entry in ipairs(FORMAT_KEYS) do
            local klen = #entry.key
            if str:sub(i, i + klen - 1):lower() == entry.key:lower() then matched = entry; break end
        end
        if matched then
            if matched.mo then
                pushBuffer(true)
                segments[#segments + 1] = { t = "mo" }
                trimNextLeading = true
            else
                pushBuffer(false)
                segments[#segments + 1] = { t = "value", v = matched.id }
            end
            i = i + #matched.key
        else
            buffer = buffer .. str:sub(i, i)
            i = i + 1
        end
    end
    pushBuffer(false)
    return segments
end

-- Sample render for previews (token samples, no live unit). Returns the at-rest portion. A blank/whitespace string
-- returns "" — distinct from nil (legacy) — mirroring the live RecomputeHealthSegments so a preview never shows a
-- phantom value. By default, when the at-rest side is empty (e.g. "& Max") it falls back to the mouseover portion so
-- a per-component Canvas preview stays visible/selectable; pass noFallback=true (group-frame rows, which mirror the
-- live frame's at-rest render exactly per README parity) to get the raw rest sample even when empty.
function UnitButton.HealthFormatRestSample(formatString, legacyMode, noFallback)
    local segs = (type(formatString) == "string") and ParseFormat(formatString) or LegacyModeToSegments(legacyMode)
    local moIndex
    for i = 1, #segs do
        if segs[i].t == "mo" then moIndex = i; break end
    end
    local function sample(from, to)
        local out = {}
        for i = from, to do
            local seg = segs[i]
            if seg.t == "value" then
                local tk = TOKEN_BY_ID[seg.v]
                out[#out + 1] = (tk and tk.sample) or seg.v
            elseif seg.t == "sep" then
                out[#out + 1] = seg.v or ""
            end
        end
        return table.concat(out)
    end
    local rest = sample(1, moIndex and moIndex - 1 or #segs)
    if rest ~= "" or noFallback then return rest end
    return moIndex and sample(moIndex + 1, #segs) or rest
end

-- Valid when there is at most one `&` divider and no value token repeats within the same (rest/hover) side.
function UnitButton.ValidateHealthFormat(str)
    if type(str) ~= "string" then return true end
    local moCount, seen = 0, {}
    for _, seg in ipairs(ParseFormat(str)) do
        if seg.t == "mo" then
            moCount = moCount + 1
            if moCount > 1 then return false end
            seen = {}
        elseif seg.t == "value" then
            if seen[seg.v] then return false end
            seen[seg.v] = true
        end
    end
    return true
end

-- [ TEXT MIXIN ]-------------------------------------------------------------------------------------
local TextMixin = {}

-- Resolves the active format (custom segments, else legacy mode) and caches the mouseover split so
-- UpdateHealthText allocates nothing per health event.
function TextMixin:RecomputeHealthSegments()
    -- A string (even "") is the user's chosen format — "" parses to no segments (blank); only nil falls back to the legacy preset.
    local fmt = self.healthTextFormat
    local segs = (type(fmt) == "string") and ParseFormat(fmt) or LegacyModeToSegments(self.healthTextMode)
    local moIndex
    for i = 1, #segs do
        if segs[i].t == "mo" then moIndex = i; break end
    end
    if not moIndex then
        self._healthRestSegs = segs
        self._healthHoverSegs = nil
        return
    end
    local rest, hover = {}, {}
    for j = 1, moIndex - 1 do rest[#rest + 1] = segs[j] end
    for j = moIndex + 1, #segs do hover[#hover + 1] = segs[j] end
    self._healthRestSegs = rest
    -- An empty side is kept as {} (not nil) so a divider with nothing on that side renders blank — distinct from nil (no divider), where mouseover mirrors the rest.
    self._healthHoverSegs = hover
end

function TextMixin:UpdateHealthText()
    if not self.HealthText then return end

    if self.orbitPlugin and self.orbitPlugin.IsComponentDisabled and self.orbitPlugin:IsComponentDisabled("HealthText") then
        self.HealthText:Hide()
        return
    end

    if not self.unit then
        self.HealthText:SetText("")
        self.HealthText:Hide()
        return
    end

    -- Status takes priority over the format, mirroring Blizzard's CompactUnitFrame_UpdateStatusText: offline, then
    -- dead-or-ghost (Blizzard shows DEAD for both), using Blizzard's own localized global strings, before any value.
    if not UnitIsConnected(self.unit) then
        self.HealthText:SetText(PLAYER_OFFLINE)
        self.HealthText:Show()
        return
    end

    if UnitIsDeadOrGhost(self.unit) then
        self.HealthText:SetText(DEAD)
        self.HealthText:Show()
        return
    end

    if self.healthTextEnabled == false then
        self.HealthText:SetText("")
        self.HealthText:Hide()
        return
    end

    if not self._healthRestSegs then self:RecomputeHealthSegments() end
    local active = (self.isMouseOver and self._healthHoverSegs) or self._healthRestSegs
    RenderHealthText(self.HealthText, self.unit, active)
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
    self:RecomputeHealthSegments()
    self:UpdateHealthText()
end

function TextMixin:SetHealthTextFormat(formatString)
    self.healthTextFormat = formatString
    self:RecomputeHealthSegments()
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

    -- issecretvalue first — `name == nil` throws on a secret UnitName.
    if issecretvalue(name) then
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

    self._fullName = name
    self.Name:SetText(name)
    self:ApplyNameColor()
    self:ConstrainNameWidth()
end

-- [ NAME WIDTH CONSTRAINT ]--------------------------------------------------------------------------
local FALLBACK_FONT_HEIGHT = 12
local HEALTH_CHAR_WIDTH_RATIO = 0.6
local TOKEN_CHAR_COUNTS = { percent = 4, currentk = 5, current = 9, maxk = 5, max = 9 }

local function SafeGetValue(fn)
    local ok, val = pcall(fn)
    if not ok or val == nil then return nil end
    if issecretvalue and issecretvalue(val) then return nil end
    return type(val) == "number" and val or nil
end

-- Closureless variant — callers pass the resolved value so GetNameAvailableWidth doesn't allocate 7 thunks per call.
local function FilterNumeric(val)
    if val == nil then return nil end
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
    if not self._healthRestSegs then self:RecomputeHealthSegments() end
    local chars = 0
    for _, seg in ipairs(self._healthRestSegs) do
        if seg.t == "value" then
            chars = chars + (TOKEN_CHAR_COUNTS[seg.v] or 5)
        elseif seg.t == "sep" then
            chars = chars + #(seg.v or "")
        end
    end
    if chars == 0 then chars = 5 end
    return fontHeight * HEALTH_CHAR_WIDTH_RATIO * chars
end

function TextMixin:GetNameAvailableWidth()
    local frameWidth = FilterNumeric(self:GetWidth())
    if not frameWidth or frameWidth <= 0 then return nil end

    if not self.HealthText or not self.HealthText:IsShown() then
        return frameWidth - (EDGE_PADDING * 2)
    end

    local nameLeft = FilterNumeric(self.Name:GetLeft())
    local healthLeft = FilterNumeric(self.HealthText:GetLeft())

    if nameLeft and healthLeft and healthLeft > nameLeft then
        local nameTop = FilterNumeric(self.Name:GetTop())
        local nameBot = FilterNumeric(self.Name:GetBottom())
        local healthTop = FilterNumeric(self.HealthText:GetTop())
        local healthBot = FilterNumeric(self.HealthText:GetBottom())
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
    local name = self._fullName or self.Name:GetText()
    if not name then return end
    if issecretvalue and issecretvalue(name) then return end
    if type(name) ~= "string" or #name == 0 then return end

    local available = self:GetNameAvailableWidth()
    if not available then return end
    available = math.max(available, MIN_NAME_WIDTH)

    -- Skip the binary search when (name, available) is unchanged — only EditMode drag-resize genuinely needs to re-fit per fire.
    if self._lastConstrainName == name and self._lastConstrainAvailable == available then
        if self._lastConstrainResult then self.Name:SetText(self._lastConstrainResult) end
        return
    end

    self.Name:SetText(name)
    local textWidth = FilterNumeric(self.Name:GetStringWidth())
    if not textWidth or textWidth <= available then
        self._lastConstrainName, self._lastConstrainAvailable, self._lastConstrainResult = name, available, name
        return
    end

    if not self._hasNickname then
        local lastWord = string.match(name, "(%S+)$")
        if lastWord and lastWord ~= name then
            self.Name:SetText(lastWord)
            local newWidth = FilterNumeric(self.Name:GetStringWidth())
            if not newWidth or newWidth <= available then
                self._lastConstrainName, self._lastConstrainAvailable, self._lastConstrainResult = name, available, lastWord
                return
            end
            name = lastWord
        end
    end

    local lo, hi = 1, #name
    self.Name:SetText(TRUNCATION_SUFFIX)
    local suffixWidth = FilterNumeric(self.Name:GetStringWidth()) or 0
    local trimTarget = available - suffixWidth
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        self.Name:SetText(string.sub(name, 1, mid))
        local w = FilterNumeric(self.Name:GetStringWidth())
        if not w or w <= trimTarget then lo = mid else hi = mid - 1 end
    end
    local final = string.sub(name, 1, lo) .. TRUNCATION_SUFFIX
    self.Name:SetText(final)
    self._lastConstrainName, self._lastConstrainAvailable, self._lastConstrainResult = name, available, final
end

-- [ TEXT COLOR ] ------------------------------------------------------------------------------------

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

UnitButton.TextMixin = TextMixin
if table.freeze then table.freeze(TextMixin) end
