-- [ ORBIT ENGINE ]----------------------------------------------------------------------------------

local _, Orbit = ...

---@class OrbitEngine
---@field WidgetLogic OrbitWidgetLogic
---@field Frame OrbitFrameManager
---@field FramePersistence OrbitFramePersistence
---@field Config OrbitConfig
---@field Layout OrbitLayout
---@field systems OrbitSystem[]
---@field internal table
Orbit.Engine = {}
local Engine = Orbit.Engine

Engine.internal = Engine.internal or {}
Engine.Constants = Orbit.Constants
