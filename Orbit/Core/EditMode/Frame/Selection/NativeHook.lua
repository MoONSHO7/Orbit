-- [ ORBIT SELECTION - NATIVE FRAME HOOKS ]---------------------------------------------------------
-- Logic consolidated into EditFrame.lua to avoid duplicate hooksecurefunc calls.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.SelectionNativeHook = Engine.SelectionNativeHook or {}
Engine.SelectionNativeHook.hooked = true
