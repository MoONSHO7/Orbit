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

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Behaviour", "Colours" }, "Layout")

    if currentTab == "Layout" then
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

    elseif currentTab == "Behaviour" then
        -- Header Separators
        table.insert(schema.controls, {
            type = "checkbox",
            key = "HeaderSeparators",
            label = "Header Separators",
            default = true,
            onChange = OnChange(self, systemIndex, "HeaderSeparators"),
        })

        -- Skin Progress Bars
        table.insert(schema.controls, {
            type = "checkbox",
            key = "SkinProgressBars",
            label = "Skin Progress Bars",
            default = true,
            onChange = OnChange(self, systemIndex, "SkinProgressBars"),
        })

        -- Progress Bar Label Mode
        table.insert(schema.controls, {
            type = "dropdown",
            key = "ProgressBarMode",
            label = "Progress Bar Label",
            default = "Percent",
            options = {
                { label = "Percent (75%)", value = "Percent" },
                { label = "X / Y (150 / 200)", value = "XY" },
                { label = "Both (150 / 200  (75%))", value = "Both" },
            },
            onChange = OnChange(self, systemIndex, "ProgressBarMode"),
        })

        -- Auto-Collapse in Combat
        table.insert(schema.controls, {
            type = "checkbox",
            key = "AutoCollapseCombat",
            label = "Collapse in Combat",
            default = false,
            onChange = OnChange(self, systemIndex, "AutoCollapseCombat"),
        })

    elseif currentTab == "Colours" then
        -- Custom Quest Colors (classification / tag colouring)
        table.insert(schema.controls, {
            type = "checkbox",
            key = "CustomColors",
            label = "Custom Quest Colors",
            default = true,
            onChange = OnChange(self, systemIndex, "CustomColors"),
        })

        -- Class Color Headers (moved from Behaviour)
        table.insert(schema.controls, {
            type = "checkbox",
            key = "ClassColorHeaders",
            label = "Class Color Headers",
            default = false,
            onChange = OnChange(self, systemIndex, "ClassColorHeaders"),
        })

        -- Title Font Size
        table.insert(schema.controls, {
            type = "slider",
            key = "TitleFontSize",
            label = "Title Font Size",
            min = C.TITLE_FONT_SIZE_MIN,
            max = C.TITLE_FONT_SIZE_MAX,
            step = C.TITLE_FONT_SIZE_STEP,
            default = C.TITLE_FONT_SIZE_DEFAULT,
            formatter = function(v) return v .. "pt" end,
            onChange = OnChange(self, systemIndex, "TitleFontSize"),
        })

        -- Objective Font Size
        table.insert(schema.controls, {
            type = "slider",
            key = "ObjectiveFontSize",
            label = "Objective Font Size",
            min = C.OBJECTIVE_FONT_SIZE_MIN,
            max = C.OBJECTIVE_FONT_SIZE_MAX,
            step = C.OBJECTIVE_FONT_SIZE_STEP,
            default = C.OBJECTIVE_FONT_SIZE_DEFAULT,
            formatter = function(v) return v .. "pt" end,
            onChange = OnChange(self, systemIndex, "ObjectiveFontSize"),
        })

        -- Quest Title Colour
        table.insert(schema.controls, {
            type = "solidcolor",
            key = "TitleColor",
            label = "Quest Title Colour",
            default = C.TITLE_COLOR_DEFAULT,
            onChange = OnChange(self, systemIndex, "TitleColor"),
        })

        -- Completed Quest Colour
        table.insert(schema.controls, {
            type = "solidcolor",
            key = "CompletedColor",
            label = "Completed Quest Colour",
            default = C.COMPLETED_COLOR_DEFAULT,
            onChange = OnChange(self, systemIndex, "CompletedColor"),
        })

        -- Focused Quest Colour
        table.insert(schema.controls, {
            type = "solidcolor",
            key = "FocusColor",
            label = "Focused Quest Colour",
            default = C.FOCUS_COLOR_DEFAULT,
            onChange = OnChange(self, systemIndex, "FocusColor"),
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
