-- [ OBJECTIVES SETTINGS ]-----------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local C = Orbit.ObjectivesConstants
local SYSTEM_ID = C.SYSTEM_ID

local Plugin = Orbit:GetPlugin("Objectives")

local function OnChange(plugin, systemIndex, key)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        plugin:ApplySettings()
    end
end

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame and systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- Scale
    SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "Scale",
        label = "Scale",
        default = C.DEFAULT_SCALE,
    })

    -- Width
    table.insert(schema.controls, {
        type = "slider",
        key = "Width",
        label = "Width",
        min = C.WIDTH_MIN,
        max = C.WIDTH_MAX,
        step = C.WIDTH_STEP,
        default = C.DEFAULT_WIDTH,
        onChange = OnChange(self, systemIndex, "Width"),
    })

    -- Height
    table.insert(schema.controls, {
        type = "slider",
        key = "Height",
        label = "Height",
        min = C.HEIGHT_MIN,
        max = C.HEIGHT_MAX,
        step = C.HEIGHT_STEP,
        default = C.DEFAULT_HEIGHT,
        onChange = OnChange(self, systemIndex, "Height"),
    })

    -- Show Border
    table.insert(schema.controls, {
        type = "checkbox",
        key = "ShowBorder",
        label = "Show Border",
        default = true,
        onChange = OnChange(self, systemIndex, "ShowBorder"),
    })

    -- Background Opacity
    table.insert(schema.controls, {
        type = "slider",
        key = "BackgroundOpacity",
        label = "Background Opacity",
        min = C.BG_OPACITY_MIN,
        max = C.BG_OPACITY_MAX,
        step = C.BG_OPACITY_STEP,
        default = C.BG_OPACITY_DEFAULT,
        formatter = function(v) return v .. "%" end,
        onChange = OnChange(self, systemIndex, "BackgroundOpacity"),
    })

    -- Class Color Headers
    table.insert(schema.controls, {
        type = "checkbox",
        key = "ClassColorHeaders",
        label = "Class Color Headers",
        default = false,
        onChange = OnChange(self, systemIndex, "ClassColorHeaders"),
    })

    -- Header Separators
    table.insert(schema.controls, {
        type = "checkbox",
        key = "HeaderSeparators",
        label = "Header Separators",
        default = true,
        onChange = OnChange(self, systemIndex, "HeaderSeparators"),
    })

    -- Quest Marker Style
    table.insert(schema.controls, {
        type = "dropdown",
        key = "QuestMarkerStyle",
        label = "Quest Marker Style",
        default = "Simplified",
        options = {
            { label = "Simplified", value = "Simplified" },
            { label = "Icons", value = "Icons" },
        },
        onChange = OnChange(self, systemIndex, "QuestMarkerStyle"),
    })

    -- Skin Progress Bars
    table.insert(schema.controls, {
        type = "checkbox",
        key = "SkinProgressBars",
        label = "Skin Progress Bars",
        default = true,
        onChange = OnChange(self, systemIndex, "SkinProgressBars"),
    })

    -- Auto-Collapse in Combat
    table.insert(schema.controls, {
        type = "checkbox",
        key = "AutoCollapseCombat",
        label = "Collapse in Combat",
        default = false,
        onChange = OnChange(self, systemIndex, "AutoCollapseCombat"),
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
