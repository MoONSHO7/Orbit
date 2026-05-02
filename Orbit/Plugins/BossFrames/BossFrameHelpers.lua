---@type Orbit
local Orbit = Orbit

Orbit.BossFrameHelpers = {}
local Helpers = Orbit.BossFrameHelpers

function Helpers:AnchorToPosition(posX, posY, halfW, halfH)
    return Orbit.Engine.PositionUtils.AnchorToPosition(posX, posY, halfW, halfH, "Left")
end
