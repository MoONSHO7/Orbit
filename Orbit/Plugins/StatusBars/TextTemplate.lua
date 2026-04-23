---@type Orbit
local Orbit = Orbit

-- [ TEXT TEMPLATE ]---------------------------------------------------------------------------------
-- Token-based text rendering for StatusBars value components. Users write templates like
--   "{cur}/{max}  {pct}"  →  "45,000/80,000  56.3%"
-- Tokens are case-sensitive, unknown tokens render as-is ("{foo}") to expose typos.
-- Context fields: cur, max, rested, level, name, perhour, tolevel, eta, session, paragonCycles

Orbit.StatusBarTextTemplate = {}
local TextTemplate = Orbit.StatusBarTextTemplate

local function FormatNumber(n)
    if not n or n == 0 then return "0" end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(n)) or tostring(math.floor(n))
end

local function FormatPercent(num, denom)
    if not num or not denom or denom <= 0 then return "0%" end
    return string.format("%.1f%%", (num / denom) * 100)
end

local function FormatETA(seconds)
    if not seconds or seconds <= 0 or seconds == math.huge then return "—" end
    if seconds < 60 then return string.format("%ds", seconds) end
    if seconds < 3600 then return string.format("%dm", math.floor(seconds / 60)) end
    if seconds < 86400 then return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60)) end
    return string.format("%dd %dh", math.floor(seconds / 86400), math.floor((seconds % 86400) / 3600))
end

local TOKENS = {
    cur      = function(ctx) return FormatNumber(ctx.cur) end,
    max      = function(ctx) return FormatNumber(ctx.max) end,
    pct      = function(ctx) return FormatPercent(ctx.cur, ctx.max) end,
    rested   = function(ctx) return ctx.rested and ctx.rested > 0 and FormatNumber(ctx.rested) or "0" end,
    restedpct = function(ctx) return ctx.rested and ctx.rested > 0 and FormatPercent(ctx.rested, ctx.max) or "0%" end,
    tolevel  = function(ctx) return FormatNumber((ctx.max or 0) - (ctx.cur or 0)) end,
    level    = function(ctx) return tostring(ctx.level or "") end,
    name     = function(ctx) return tostring(ctx.name or "") end,
    perhour  = function(ctx) return FormatNumber(ctx.perhour) end,
    eta      = function(ctx) return FormatETA(ctx.eta) end,
    session  = function(ctx) return FormatNumber(ctx.session) end,
    cycles   = function(ctx) return tostring(ctx.paragonCycles or 0) end,
    pending  = function(ctx) return FormatNumber(ctx.pending) end,
    pendingpct = function(ctx) return FormatPercent(ctx.pending, ctx.max) end,
}

function TextTemplate:Render(template, ctx)
    if not template or template == "" then return "" end
    ctx = ctx or {}
    return (template:gsub("{(%w+)}", function(key)
        local fn = TOKENS[key]
        if fn then
            local ok, result = pcall(fn, ctx)
            return ok and result or "{" .. key .. "}"
        end
        return "{" .. key .. "}"
    end))
end

-- Default templates by plugin for fresh installs.
TextTemplate.DEFAULT_XP    = "{pct}"
TextTemplate.DEFAULT_REP   = "{pct}"
TextTemplate.DEFAULT_HONOR = "{pct}"
