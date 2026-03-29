-- [ ORBIT REACTION COLOR RESOLVER ]-----------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
Engine.ReactionColor = {}
local RC = Engine.ReactionColor

local REACTION_HOSTILE_MAX = 2
local REACTION_NEUTRAL_MAX = 4

RC.COLORS = {
    HOSTILE = { r = 1, g = 0.1, b = 0.1, a = 1 },
    NEUTRAL = { r = 1, g = 0.8, b = 0, a = 1 },
    FRIENDLY = { r = 0.1, g = 1, b = 0.1, a = 1 },
}

local function GetAccountSetting(key)
    return Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings[key]
end

local function SetAccountSetting(key, val)
    if not Orbit.db.AccountSettings then Orbit.db.AccountSettings = {} end
    Orbit.db.AccountSettings[key] = val
end

function RC:GetOverride(reactionType)
    local custom = GetAccountSetting("ReactionColor_" .. reactionType)
    if custom then return { r = custom.r, g = custom.g, b = custom.b, a = 1 } end
    return self.COLORS[reactionType]
end

function RC:SetOverride(reactionType, colorTable)
    SetAccountSetting("ReactionColor_" .. reactionType, colorTable)
    Orbit.EventBus:Fire("COLORS_CHANGED")
end

function RC:GetReactionColor(reaction)
    if reaction <= REACTION_HOSTILE_MAX then return self:GetOverride("HOSTILE") end
    if reaction <= REACTION_NEUTRAL_MAX then return self:GetOverride("NEUTRAL") end
    return self:GetOverride("FRIENDLY")
end
