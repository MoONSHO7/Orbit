---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local SYSTEM_ID = "Orbit_Minimap"
local DEFAULT_SIZE = Orbit.MinimapConstants.DEFAULT_SIZE

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------

local Plugin = Orbit:GetPlugin(SYSTEM_ID)

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- Opacity
    SB:AddOpacitySettings(self, schema, systemIndex, systemFrame)

    -- Shape
    table.insert(schema.controls, {
        type = "dropdown",
        key = "Shape",
        label = "Shape",
        options = {
            { value = "square", label = "Square" },
            { value = "round", label = "Round" },
        },
        default = "square",
    })

    -- Size (diameter)
    table.insert(schema.controls, {
        type = "slider",
        key = "Size",
        label = "Size",
        min = 100,
        max = 400,
        step = 1,
        default = DEFAULT_SIZE,
    })

    -- Border Colour
    table.insert(schema.controls, {
        type = "colorcurve",
        key = "BorderColor",
        label = "Border Colour",
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
        label = "Rotate Minimap (Round Only)",
        default = false,
        onChange = function(val)
            self:SetSetting(SYSTEM_ID, "RotateMinimap", val)
            self:ApplySettings()
        end,
    })

    -- Middle-click Action
    table.insert(schema.controls, {
        type = "dropdown",
        key = "MiddleClickAction",
        label = "Middle-click",
        options = {
            { value = "none", label = "None" },
            { value = "worldmap", label = "World Map" },
            { value = "tracking", label = "Tracking Menu" },
        },
        default = "none",
    })

    -- Auto Zoom-out Delay
    table.insert(schema.controls, {
        type = "slider",
        key = "AutoZoomOutDelay",
        label = "Auto Zoom-out Delay (0 = off)",
        min = 0,
        max = 30,
        step = 1,
        default = 5,
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
