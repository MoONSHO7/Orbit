-- [ TRACKED TOOLTIP PARSER ]------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
Orbit.TrackedTooltipParser = {}
local Parser = Orbit.TrackedTooltipParser

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local ACTIVE_DURATION_OVERRIDES = {
    [1122] = 30, -- Summon Infernal: first match is 2s stun, pet lasts 30s
    [633] = 0, -- Lay on Hands: instant, Forbearance is not active phase
    [48743] = 0, -- Death Pact: instant heal, absorb debuff is not active phase
}

local ACTIVE_DURATION_PATTERNS = { "for (%d+%.?%d*) sec", "lasts (%d+%.?%d*) sec", "over (%d+%.?%d*) sec" }
local COOLDOWN_KEYWORDS = { "[Cc]ooldown", "[Rr]echarge" }

-- [ HELPERS ]---------------------------------------------------------------------------------------
local function StripEscapes(text)
    text = text:gsub("|4([^:]+):([^;]+);", "%2")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text
end

-- [ PARSE ACTIVE DURATION ]-------------------------------------------------------------------------
function Parser:ParseActiveDuration(itemType, id)
    if itemType == "spell" and ACTIVE_DURATION_OVERRIDES[id] then
        return ACTIVE_DURATION_OVERRIDES[id]
    end
    local text
    if itemType == "spell" then
        text = C_Spell.GetSpellDescription(id)
    elseif itemType == "item" then
        local tooltipData = C_TooltipInfo and C_TooltipInfo.GetItemByID(id)
        if tooltipData and tooltipData.lines then
            for _, line in ipairs(tooltipData.lines) do
                text = (text or "") .. " " .. (line.leftText or "")
            end
        end
    end
    if not text then return nil end
    text = StripEscapes(text)
    for _, pattern in ipairs(ACTIVE_DURATION_PATTERNS) do
        local num = text:match(pattern)
        if num then return tonumber(num) end
    end
    return nil
end

-- [ PARSE COOLDOWN DURATION ]-----------------------------------------------------------------------
function Parser:ParseCooldownDuration(itemType, id)
    local tooltipData
    if itemType == "spell" then
        tooltipData = C_TooltipInfo and C_TooltipInfo.GetSpellByID(id)
    elseif itemType == "item" then
        tooltipData = C_TooltipInfo and C_TooltipInfo.GetItemByID(id)
    end
    if not tooltipData or not tooltipData.lines then return nil end
    local best
    for _, line in ipairs(tooltipData.lines) do
        local text = StripEscapes(line.rightText or line.leftText or "")
        local compoundMin, compoundSec = text:match("(%d+%.?%d*) [Mm]in (%d+%.?%d*) [Ss]ec [Cc]ooldown")
        if compoundMin and compoundSec then
            local val = (tonumber(compoundMin) * 60) + tonumber(compoundSec)
            if not best or val > best then best = val end
        else
            for _, keyword in ipairs(COOLDOWN_KEYWORDS) do
                local min = text:match("(%d+%.?%d*) [Mm]in " .. keyword)
                if min then
                    local val = tonumber(min) * 60
                    if not best or val > best then best = val end
                end
                local sec = text:match("(%d+%.?%d*) [Ss]ec " .. keyword)
                if sec then
                    local val = tonumber(sec)
                    if not best or val > best then best = val end
                end
            end
        end
    end
    return best
end

-- [ BUILD PHASE CURVE ]-----------------------------------------------------------------------------
function Parser:BuildPhaseCurve(activeDuration, cooldownDuration)
    local curve = C_CurveUtil.CreateCurve()
    curve:AddPoint(0.0, 0)
    if not activeDuration or not cooldownDuration or cooldownDuration <= 0 or activeDuration >= cooldownDuration then
        curve:AddPoint(0.001, 1)
        curve:AddPoint(1.0, 1)
        return curve
    end
    local breakpoint = 1.0 - (activeDuration / cooldownDuration)
    curve:AddPoint(0.001, 1)
    curve:AddPoint(math.max(breakpoint, 0.002), 1)
    curve:AddPoint(breakpoint + 0.001, 0)
    curve:AddPoint(1.0, 0)
    return curve
end
