-- [ OBJECTIVES SETTINGS ]----------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local L = Orbit.L

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
    local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_OBJ_TAB_LAYOUT, L.PLU_OBJ_TAB_BEHAVIOUR, L.PLU_OBJ_TAB_COLOURS }, L.PLU_OBJ_TAB_LAYOUT)

    if currentTab == L.PLU_OBJ_TAB_LAYOUT then
        -- Width
        table.insert(schema.controls, {
            type = "slider",
            key = "Width",
            label = L.CMN_WIDTH,
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
            label = L.CMN_HEIGHT,
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
            label = L.PLU_OBJ_SHOW_BORDER,
            default = true,
            onChange = OnChange(self, systemIndex, "ShowBorder"),
        })

        -- Background Opacity
        table.insert(schema.controls, {
            type = "slider",
            key = "BackgroundOpacity",
            label = L.PLU_OBJ_BG_OPACITY,
            min = C.BG_OPACITY_MIN,
            max = C.BG_OPACITY_MAX,
            step = C.BG_OPACITY_STEP,
            default = C.BG_OPACITY_DEFAULT,
            formatter = function(v) return v .. "%" end,
            onChange = OnChange(self, systemIndex, "BackgroundOpacity"),
        })

    elseif currentTab == L.PLU_OBJ_TAB_BEHAVIOUR then
        -- Header Separators
        table.insert(schema.controls, {
            type = "checkbox",
            key = "HeaderSeparators",
            label = L.PLU_OBJ_HEADER_SEPARATORS,
            default = true,
            onChange = OnChange(self, systemIndex, "HeaderSeparators"),
        })

        -- Skin Progress Bars
        table.insert(schema.controls, {
            type = "checkbox",
            key = "SkinProgressBars",
            label = L.PLU_OBJ_SKIN_PROGRESS_BARS,
            default = true,
            onChange = OnChange(self, systemIndex, "SkinProgressBars"),
        })

        -- Progress Bar Label Mode
        table.insert(schema.controls, {
            type = "dropdown",
            key = "ProgressBarMode",
            label = L.PLU_OBJ_PROGRESS_BAR_LABEL,
            default = "Percent",
            options = {
                { label = L.PLU_OBJ_PB_PERCENT, value = "Percent" },
                { label = L.PLU_OBJ_PB_XY, value = "XY" },
                { label = L.PLU_OBJ_PB_BOTH, value = "Both" },
            },
            onChange = OnChange(self, systemIndex, "ProgressBarMode"),
        })

        -- Auto-Collapse in Combat
        table.insert(schema.controls, {
            type = "checkbox",
            key = "AutoCollapseCombat",
            label = L.PLU_OBJ_AUTO_COLLAPSE_COMBAT,
            default = false,
            onChange = OnChange(self, systemIndex, "AutoCollapseCombat"),
        })

        -- Show Quest Count
        table.insert(schema.controls, {
            type = "checkbox",
            key = "ShowQuestCount",
            label = L.PLU_OBJ_SHOW_QUEST_COUNT,
            default = true,
            onChange = OnChange(self, systemIndex, "ShowQuestCount"),
        })

    elseif currentTab == L.PLU_OBJ_TAB_COLOURS then
        -- Custom Quest Colors (classification / tag colouring)
        table.insert(schema.controls, {
            type = "checkbox",
            key = "CustomColors",
            label = L.PLU_OBJ_CUSTOM_COLORS,
            default = true,
            onChange = OnChange(self, systemIndex, "CustomColors"),
        })

        -- Class Color Headers (moved from Behaviour)
        table.insert(schema.controls, {
            type = "checkbox",
            key = "ClassColorHeaders",
            label = L.PLU_OBJ_CLASS_COLOR_HEADERS,
            default = false,
            onChange = OnChange(self, systemIndex, "ClassColorHeaders"),
        })

        -- Title Font Size
        table.insert(schema.controls, {
            type = "slider",
            key = "TitleFontSize",
            label = L.PLU_OBJ_TITLE_FONT_SIZE,
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
            label = L.PLU_OBJ_OBJECTIVE_FONT_SIZE,
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
            label = L.PLU_OBJ_TITLE_COLOUR,
            default = C.TITLE_COLOR_DEFAULT,
            onChange = OnChange(self, systemIndex, "TitleColor"),
        })

        -- Completed Quest Colour
        table.insert(schema.controls, {
            type = "solidcolor",
            key = "CompletedColor",
            label = L.PLU_OBJ_COMPLETED_COLOUR,
            default = C.COMPLETED_COLOR_DEFAULT,
            onChange = OnChange(self, systemIndex, "CompletedColor"),
        })

        -- Focused Quest Colour
        table.insert(schema.controls, {
            type = "solidcolor",
            key = "FocusColor",
            label = L.PLU_OBJ_FOCUS_COLOUR,
            default = C.FOCUS_COLOR_DEFAULT,
            onChange = OnChange(self, systemIndex, "FocusColor"),
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
