---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Minimap"
local DEFAULT_SIZE = Orbit.MinimapConstants.DEFAULT_SIZE

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
local Plugin = Orbit:GetPlugin(SYSTEM_ID)

local CLICK_ACTION_OPTIONS = {
    { value = "none", label = L.PLU_MINIMAP_ACT_NONE },
    { value = "worldmap", label = L.PLU_MINIMAP_ACT_MAP },
    { value = "tracking", label = L.PLU_MINIMAP_ACT_TRACK },
    { value = "calendar", label = L.PLU_MINIMAP_ACT_CAL },
    { value = "time", label = L.PLU_MINIMAP_ACT_TIME },
    { value = "addons", label = L.PLU_MINIMAP_ACT_ADDONS },
}

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- Shape
    table.insert(schema.controls, {
        type = "dropdown",
        key = "Shape",
        label = L.PLU_MINIMAP_SHAPE,
        options = {
            { value = "square", label = L.PLU_MINIMAP_SQUARE },
            { value = "round", label = L.PLU_MINIMAP_ROUND },
        },
        default = "square",
        onChange = function(val)
            self:SetSetting(SYSTEM_ID, "Shape", val)
            self:ApplySettings()
            if dialog.OrbitPanel and dialog.OrbitPanel.Content then
                dialog.OrbitPanel.Content.OrbitRendered = false
                OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
            end
        end,
    })

    -- Size (diameter)
    table.insert(schema.controls, {
        type = "slider",
        key = "Size",
        label = L.PLU_MINIMAP_SIZE,
        min = 100,
        max = 400,
        step = 1,
        default = DEFAULT_SIZE,
    })

    -- Border Colour
    table.insert(schema.controls, {
        type = "colorcurve",
        key = "BorderColor",
        label = L.PLU_MINIMAP_BORDER,
        singleColor = true,
        default = { pins = { { position = 0, color = { r = 0, g = 0, b = 0, a = 1 } } } },
        onChange = function(val)
            local color = val and val.pins and val.pins[1] and val.pins[1].color
            if color then
                self:SetSetting(SYSTEM_ID, "BorderColor", color)
                self:ApplySettings()
            end
        end,
    })

    -- Rotate Minimap
    table.insert(schema.controls, {
        type = "checkbox",
        key = "RotateMinimap",
        label = L.PLU_MINIMAP_ROTATE,
        default = false,
        visibleIf = function()
            local shape = self:GetSetting(SYSTEM_ID, "Shape")
            return shape == "round"
        end,
        onChange = function(val)
            self:SetSetting(SYSTEM_ID, "RotateMinimap", val)
            self:ApplySettings()
        end,
    })

    -- Click Actions
    table.insert(schema.controls, {
        type = "dropdown",
        key = "LeftClickAction",
        label = L.PLU_MINIMAP_LEFT_CLICK,
        options = CLICK_ACTION_OPTIONS,
        default = "none",
    })

    table.insert(schema.controls, {
        type = "dropdown",
        key = "MiddleClickAction",
        label = L.PLU_MINIMAP_MID_CLICK,
        options = CLICK_ACTION_OPTIONS,
        default = "none",
    })

    table.insert(schema.controls, {
        type = "dropdown",
        key = "RightClickAction",
        label = L.PLU_MINIMAP_RIGHT_CLICK,
        options = CLICK_ACTION_OPTIONS,
        default = "tracking",
    })

    -- Auto Zoom-out
    table.insert(schema.controls, {
        type = "checkbox",
        key = "AutoZoomOut",
        label = L.PLU_MINIMAP_AUTO_ZOOM,
        tooltip = L.PLU_MINIMAP_AUTO_ZOOM_TT,
        default = true,
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
