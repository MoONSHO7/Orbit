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
        -- Coalesce rapid changes: a slider drag fires onChange every frame and each ApplySettings runs a full re-skin, so apply once on the next frame rather than per tick.
        if not plugin._applyPending then
            plugin._applyPending = true
            RunNextFrame(function()
                plugin._applyPending = false
                plugin:ApplySettings()
            end)
        end
    end
end

local function FontSizePx(v) return v .. "px" end

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

        -- Header Font Size
        table.insert(schema.controls, {
            type = "slider",
            key = "HeaderFontSize",
            label = L.PLU_OBJ_HEADER_FONT_SIZE,
            min = C.HEADER_FONT_SIZE_MIN,
            max = C.HEADER_FONT_SIZE_MAX,
            step = C.HEADER_FONT_SIZE_STEP,
            default = C.HEADER_FONT_SIZE_DEFAULT,
            formatter = FontSizePx,
            onChange = OnChange(self, systemIndex, "HeaderFontSize"),
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
            formatter = FontSizePx,
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
            formatter = FontSizePx,
            onChange = OnChange(self, systemIndex, "ObjectiveFontSize"),
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

        -- Show Border (rendered last)
        table.insert(schema.controls, {
            type = "checkbox",
            key = "ShowBorder",
            label = L.PLU_OBJ_SHOW_BORDER,
            default = true,
            onChange = OnChange(self, systemIndex, "ShowBorder"),
        })

    elseif currentTab == L.PLU_OBJ_TAB_BEHAVIOUR then
        -- Progress Bar Label (token format string, e.g. "Current / Max (%)") — rendered first
        local progressTooltip = { { title = L.CFG_FORMAT_TOOLTIP_TITLE } }
        for _, token in ipairs(C.PROGRESS_TOKENS) do
            table.insert(progressTooltip, { key = token.key, value = token.sample })
        end
        table.insert(progressTooltip, { hint = L.CFG_FORMAT_TOOLTIP_HINT })

        table.insert(schema.controls, {
            type = "formatinput",
            key = "ProgressBarLabelFormat",
            label = L.PLU_OBJ_PROGRESS_BAR_LABEL,
            default = C.PROGRESS_FORMAT_DEFAULT,
            tooltipLines = progressTooltip,
            validate = function(str) return self:ValidateProgressFormat(str) end,
            onChange = OnChange(self, systemIndex, "ProgressBarLabelFormat"),
        })

        -- Header Separators
        table.insert(schema.controls, {
            type = "checkbox",
            key = "HeaderSeparators",
            label = L.PLU_OBJ_HEADER_SEPARATORS,
            default = true,
            onChange = OnChange(self, systemIndex, "HeaderSeparators"),
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
        -- Module Header (supports the picker's Class Color pin)
        table.insert(schema.controls, {
            type = "solidcolor",
            key = "HeaderColor",
            label = L.PLU_OBJ_HEADER_COLOUR,
            default = C.HEADER_COLOR_DEFAULT,
            onChange = OnChange(self, systemIndex, "HeaderColor"),
        })

        -- Quest Title
        table.insert(schema.controls, {
            type = "solidcolor",
            key = "TitleColor",
            label = L.PLU_OBJ_TITLE_COLOUR,
            default = C.TITLE_COLOR_DEFAULT,
            onChange = OnChange(self, systemIndex, "TitleColor"),
        })

        -- Completed Quest
        table.insert(schema.controls, {
            type = "solidcolor",
            key = "CompletedColor",
            label = L.PLU_OBJ_COMPLETED_COLOUR,
            default = C.COMPLETED_COLOR_DEFAULT,
            onChange = OnChange(self, systemIndex, "CompletedColor"),
        })

        -- Focused Quest
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
