-- [ ORBIT REGISTRY ]--------------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.systems = Engine.systems or {}
Engine.systemToPlugin = Engine.systemToPlugin or {}

---@class OrbitSystem : OrbitPluginMixin
---@field name string
---@field system string
---@field frame frame
---@field Init function?
---@field OnLoad function?
---@field ApplySettings function?

Engine.SystemMixin = {}

function Engine.SystemMixin:Init() end
function Engine.SystemMixin:OnLoad() end
function Engine.SystemMixin:AddSettings(dialog, systemFrame) end
function Engine.SystemMixin:UpdateLayout(frame) end

function Engine.SystemMixin:GetSetting(systemIndex, key)
    error("Orbit: GetSetting not implemented by plugin " .. (self.name or "unknown"))
end

function Engine.SystemMixin:SetSetting(systemIndex, key, value)
    error("Orbit: SetSetting not implemented by plugin " .. (self.name or "unknown"))
end

---@return OrbitSystem
function Engine:RegisterSystem(name, system, mixin)
    local plugin = CreateFromMixins(Engine.SystemMixin, mixin)
    plugin.name = name
    plugin.system = system

    table.insert(Engine.systems, plugin)
    if system then Engine.systemToPlugin[system] = plugin end
    if plugin.Init then plugin:Init() end

    return plugin
end

---@return OrbitSystem
function Engine:GetSystem(system) return Engine.systemToPlugin[system] end
