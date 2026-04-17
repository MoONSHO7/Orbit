-- [ TRACKED SETTINGS ] ------------------------------------------------------------------------------
-- Per-mode schemas (icons vs bars) dispatched on record.mode; standalone until surface area stabilizes.
local _, Orbit = ...
local L = Orbit.L

local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

local TICK_SIZE_DEFAULT = OrbitEngine.TickMixin.TICK_SIZE_DEFAULT
local TICK_SIZE_MAX = OrbitEngine.TickMixin.TICK_SIZE_MAX
local DEFAULT_SWIPE_COLOR = { r = 1, g = 0.95, b = 0.57, a = 0.7 }

local Plugin = Orbit:GetPlugin("Orbit_Tracked")
if not Plugin then return end

-- [ ADDSETTINGS DISPATCH ] --------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    local record = self:GetContainerRecord(systemIndex)
    if not record then return end

    if record.mode == "icons" then
        self:_BuildIconSettings(dialog, systemFrame, record)
    elseif record.mode == "bar" then
        self:_BuildBarSettings(dialog, systemFrame, record)
    end
end

-- [ ICON SETTINGS ] ---------------------------------------------------------------------------------
function Plugin:_BuildIconSettings(dialog, systemFrame, record)
    local systemIndex = record.id
    local schema = { controls = {}, extraButtons = {} }
    local SB = OrbitEngine.SchemaBuilder

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_TRK_TAB_LAYOUT, L.PLU_TRK_TAB_GLOW, L.PLU_TRK_TAB_VISIBILITY, L.PLU_TRK_TAB_COLORS }, L.PLU_TRK_TAB_LAYOUT)

    if currentTab == L.PLU_TRK_TAB_LAYOUT then
        table.insert(schema.controls, {
            type = "dropdown", key = "aspectRatio", label = L.PLU_TRK_ICON_ASPECT,
            options = {
                { text = L.PLU_CDM_ASPECT_1_1, value = "1:1" },
                { text = L.PLU_CDM_ASPECT_16_9, value = "16:9" },
                { text = L.PLU_CDM_ASPECT_4_3, value = "4:3" },
                { text = L.PLU_CDM_ASPECT_21_9, value = "21:9" },
            },
            default = "1:1",
        })
        table.insert(schema.controls, {
            type = "slider", key = "IconSize", label = L.PLU_TRK_ICON_SIZE,
            min = 20, max = 80, step = 1,
            formatter = function(v) return v .. "px" end,
            default = Constants.Cooldown.DefaultIconSize,
            onChange = function(val)
                self:SetSetting(systemIndex, "IconSize", val)
                self:ApplySettings(systemFrame)
            end,
        })
        table.insert(schema.controls, {
            type = "slider", key = "IconPadding", label = L.PLU_TRK_ICON_PADDING,
            min = 0, max = 15, step = 1,
            default = Constants.Cooldown.DefaultPadding,
            onChange = function(val)
                self:SetSetting(systemIndex, "IconPadding", val)
                self:ApplySettings(systemFrame)
            end,
        })
    elseif currentTab == L.PLU_TRK_TAB_GLOW then
        table.insert(schema.controls, { type = "checkbox", key = "ShowGCDSwipe", label = L.PLU_TRK_SHOW_GCD_SWIPE, default = true })
        SB:AddGlowSettings(self, schema, systemIndex, dialog, systemFrame, {
            prefix = "ActiveGlow",
            label = L.PLU_TRK_ACTIVE_GLOW,
            default = Constants.Glow.DefaultType,
        })
    elseif currentTab == L.PLU_TRK_TAB_VISIBILITY then
        table.insert(schema.controls, {
            type = "checkbox", key = "HideOnCooldown", label = L.PLU_TRK_HIDE_ON_CD,
            tooltip = L.PLU_TRK_HIDE_ON_CD_TT, default = false,
            onChange = function(val)
                self:SetSetting(systemIndex, "HideOnCooldown", val)
                self:ApplySettings(systemFrame)
            end,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "HideOnAvailable", label = L.PLU_TRK_HIDE_ON_READY,
            tooltip = L.PLU_TRK_HIDE_ON_READY_TT, default = false,
            onChange = function(val)
                self:SetSetting(systemIndex, "HideOnAvailable", val)
                self:ApplySettings(systemFrame)
            end,
        })
    elseif currentTab == L.PLU_TRK_TAB_COLORS then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "ActiveSwipeColorCurve", label = L.PLU_TRK_ACTIVE_SWIPE,
            default = { pins = { { position = 0, color = DEFAULT_SWIPE_COLOR } } },
            singleColor = true,
        })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "CooldownSwipeColorCurve", label = L.PLU_TRK_COOLDOWN_SWIPE,
            default = { pins = { { position = 0, color = { r = 0, g = 0, b = 0, a = 0.8 } } } },
            singleColor = true,
        })
        SB:AddColorSettings(self, schema, systemIndex, systemFrame, {
            key = "KeypressColor", label = L.PLU_TRK_KEYPRESS_FLASH,
            default = { r = 1, g = 1, b = 1, a = 0 },
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ BAR SETTINGS ] ----------------------------------------------------------------------------------
local ICON_POS_MIGRATION = { Left = 1, Off = 2, Right = 3 }
function Plugin:_BuildBarSettings(dialog, systemFrame, record)
    local systemIndex = record.id
    -- Migrate legacy string values from the short-lived dropdown variant.
    local storedIconPos = self:GetSetting(systemIndex, "IconPosition")
    if type(storedIconPos) == "string" then
        self:SetSetting(systemIndex, "IconPosition", ICON_POS_MIGRATION[storedIconPos] or 1)
    end
    local schema = { controls = {}, extraButtons = {} }
    local SB = OrbitEngine.SchemaBuilder

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_TRK_TAB_LAYOUT, L.PLU_TRK_TAB_VISIBILITY, L.PLU_TRK_TAB_COLORS }, L.PLU_TRK_TAB_LAYOUT)

    if currentTab == L.PLU_TRK_TAB_LAYOUT then
        table.insert(schema.controls, {
            type = "dropdown", key = "Layout", label = L.PLU_TRK_LAYOUT,
            options = {
                { text = L.PLU_TRK_HORIZONTAL, value = "Horizontal" },
                { text = L.PLU_TRK_VERTICAL, value = "Vertical" },
            },
            default = "Horizontal",
            onChange = function(val)
                self:SetSetting(systemIndex, "Layout", val)
                self:ApplySettings(systemFrame)
            end,
        })
        table.insert(schema.controls, {
            type = "slider", key = "Width", label = L.PLU_TRK_WIDTH,
            min = 80, max = 400, step = 1, default = 200,
            onChange = function(val)
                self:SetSetting(systemIndex, "Width", val)
                self:ApplySettings(systemFrame)
            end,
        })
        table.insert(schema.controls, {
            type = "slider", key = "Height", label = L.PLU_TRK_HEIGHT,
            min = 12, max = 40, step = 1, default = 20,
            onChange = function(val)
                self:SetSetting(systemIndex, "Height", val)
                self:ApplySettings(systemFrame)
            end,
        })
        table.insert(schema.controls, {
            type = "slider", key = "IconPosition", label = L.CMN_ICON_POSITION,
            min = 1, max = 3, step = 1, default = 1,
            formatter = function(v)
                if v == 1 then return L.CMN_ICON_LEFT end
                if v == 3 then return L.CMN_ICON_RIGHT end
                return L.CMN_ICON_OFF
            end,
            onChange = function(val)
                self:SetSetting(systemIndex, "IconPosition", val)
                self:ApplySettings(systemFrame)
            end,
        })
        table.insert(schema.controls, {
            type = "slider", key = "TickSize", label = L.PLU_TRK_TICK,
            min = 0, max = TICK_SIZE_MAX, step = 2, default = TICK_SIZE_DEFAULT,
            tooltip = L.PLU_TRK_TICK_TT,
            onChange = function(val)
                self:SetSetting(systemIndex, "TickSize", val)
                self:ApplySettings(systemFrame)
            end,
        })
    elseif currentTab == L.PLU_TRK_TAB_VISIBILITY then
        table.insert(schema.controls, {
            type = "checkbox", key = "HideOnCooldown", label = L.PLU_TRK_HIDE_ON_CD,
            tooltip = L.PLU_TRK_HIDE_ON_CD_TT, default = false,
            onChange = function(val)
                self:SetSetting(systemIndex, "HideOnCooldown", val)
                self:ApplySettings(systemFrame)
            end,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "HideOnAvailable", label = L.PLU_TRK_HIDE_ON_READY,
            tooltip = L.PLU_TRK_HIDE_ON_READY_TT, default = false,
            onChange = function(val)
                self:SetSetting(systemIndex, "HideOnAvailable", val)
                self:ApplySettings(systemFrame)
            end,
        })
    elseif currentTab == L.PLU_TRK_TAB_COLORS then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "ReadyColor", label = L.PLU_TRK_READY_COLOR,
            default = { pins = { { position = 0, color = { r = 0.3, g = 0.7, b = 1, a = 1 } } } },
            singleColor = true,
        })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "ActiveColor", label = L.PLU_TRK_ACTIVE_COLOR,
            default = { pins = { { position = 0, color = { r = 0.4, g = 1, b = 0.4, a = 1 } } } },
            singleColor = true,
        })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "CooldownColor", label = L.PLU_TRK_CD_COLOR,
            default = { pins = { { position = 0, color = { r = 0.5, g = 0.5, b = 0.5, a = 1 } } } },
            singleColor = true,
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
