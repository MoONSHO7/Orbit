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

function RC:GetReactionColor(reaction)
    if reaction <= REACTION_HOSTILE_MAX then return self.COLORS.HOSTILE end
    if reaction <= REACTION_NEUTRAL_MAX then return self.COLORS.NEUTRAL end
    return self.COLORS.FRIENDLY
end
