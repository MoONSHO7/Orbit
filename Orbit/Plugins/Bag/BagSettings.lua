local _, addonTable = ...
local Orbit = addonTable
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Bag"
local COLUMNS_MIN, COLUMNS_MAX, COLUMNS_DEFAULT = 6, 20, 10
local ICON_SIZE_MIN, ICON_SIZE_MAX, ICON_SIZE_DEFAULT = 20, 56, 36
local ICON_PADDING_MIN, ICON_PADDING_MAX, ICON_PADDING_DEFAULT = 0, 8, 2

local Plugin = Orbit:GetPlugin(SYSTEM_ID)
if not Plugin then return end

-- [ ADD SETTINGS ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    table.insert(schema.controls, {
        type = "slider", key = "Columns", label = L.PLU_BAGS_COLUMNS,
        min = COLUMNS_MIN, max = COLUMNS_MAX, step = 1, default = COLUMNS_DEFAULT,
        onChange = SB:MakePluginOnChange(self, systemIndex, "Columns"),
    })
    table.insert(schema.controls, {
        type = "slider", key = "IconSize", label = L.PLU_BAGS_ICON_SIZE,
        min = ICON_SIZE_MIN, max = ICON_SIZE_MAX, step = 1, default = ICON_SIZE_DEFAULT,
        onChange = SB:MakePluginOnChange(self, systemIndex, "IconSize"),
    })
    table.insert(schema.controls, {
        type = "slider", key = "IconPadding", label = L.PLU_BAGS_ICON_PADDING,
        min = ICON_PADDING_MIN, max = ICON_PADDING_MAX, step = 1, default = ICON_PADDING_DEFAULT,
        onChange = SB:MakePluginOnChange(self, systemIndex, "IconPadding"),
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
