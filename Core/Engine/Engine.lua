local _, Orbit = ...

-- [ ORBIT ENGINE ]----------------------------------------------------------------------------------

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

-- [ CONSTANTS ALIAS ]-----------------------------------------------------------------------------
-- All constants are unified in Core/Constants.lua
Engine.Constants = Orbit.Constants
