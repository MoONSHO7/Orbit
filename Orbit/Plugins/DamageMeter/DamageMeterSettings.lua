---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local CVAR_AUTO_RESET = "damageMeterResetOnNewInstance"
local BAR_HEIGHT_MIN = 14
local BAR_HEIGHT_MAX = 40
local BAR_HEIGHT_DEFAULT = 18
local BAR_GAP_MIN = 0
local BAR_GAP_MAX = 8
local BAR_GAP_DEFAULT = 1
local STYLE_MIN = 0
local STYLE_MAX = 100
local STYLE_STEP = 5
local STYLE_DEFAULT = 100
local BORDER_NONE    = 1
local BORDER_PER_BAR = 2
local BORDER_FRAME   = 3
local BORDER_LABELS = {
    [BORDER_NONE]    = L.PLU_DM_BORDER_NONE,
    [BORDER_PER_BAR] = L.PLU_DM_BORDER_PER_BAR,
    [BORDER_FRAME]   = L.PLU_DM_BORDER_FRAME,
}
local BG_NONE    = 1
local BG_PER_BAR = 2
local BG_FRAME   = 3
local BG_LABELS = {
    [BG_NONE]    = L.PLU_DM_BG_NONE,
    [BG_PER_BAR] = L.PLU_DM_BG_PER_BAR,
    [BG_FRAME]   = L.PLU_DM_BG_FRAME,
}
local TITLE_OFF          = 1
local TITLE_TOP_LEFT     = 2
local TITLE_TOP_RIGHT    = 3
local TITLE_BOTTOM_LEFT  = 4
local TITLE_BOTTOM_RIGHT = 5
local TITLE_LABELS = {
    [TITLE_OFF]          = L.PLU_DM_TITLE_OFF,
    [TITLE_TOP_LEFT]     = L.PLU_DM_TITLE_TOP_LEFT,
    [TITLE_TOP_RIGHT]    = L.PLU_DM_TITLE_TOP_RIGHT,
    [TITLE_BOTTOM_LEFT]  = L.PLU_DM_TITLE_BOTTOM_LEFT,
    [TITLE_BOTTOM_RIGHT] = L.PLU_DM_TITLE_BOTTOM_RIGHT,
}
local TITLE_SIZE_MIN     = 8
local TITLE_SIZE_MAX     = 22
local TITLE_SIZE_DEFAULT = 12

local Plugin = Orbit:GetPlugin(DM.SystemID)
if not Plugin then return end

-- [ ICON POSITION ] ---------------------------------------------------------------------------------
local ICON_SLIDER_MIN = 1
local ICON_SLIDER_MAX = 3
local ICON_LABELS = {
    [1] = L.CMN_ICON_LEFT,
    [2] = L.CMN_ICON_OFF,
    [3] = L.CMN_ICON_RIGHT,
}

-- [ SCHEMA BUILDER ] --------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame and systemFrame.systemIndex
    if not systemIndex then return end

    local schema = { controls = {}, extraButtons = {} }
    local SB = OrbitEngine.SchemaBuilder

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local tabs = { L.PLU_DM_TAB_LAYOUT, L.PLU_DM_TAB_BEHAVIOUR }
    local currentTab = SB:AddSettingsTabs(schema, dialog, tabs, L.PLU_DM_TAB_LAYOUT)

    -- Create button lives in the footer on both tabs; callback is self-guarded so label-at-cap is cosmetic.
    local canCreate = self:CanCreateMeter()
    local createLabel = L.PLU_DM_MENU_NEW
    if not canCreate then
        createLabel = createLabel .. (" (%d/%d)"):format(self:GetMeterCount(), DM.MaxMeters)
    end
    table.insert(schema.extraButtons, {
        text = createLabel,
        callback = function()
            if not self:CanCreateMeter() then return end
            self:CreateMeter(DM.MeterType.Dps)
            C_Timer.After(0, function()
                OrbitEngine.Layout:Reset(dialog)
                self:AddSettings(dialog, systemFrame)
            end)
        end,
    })

    if currentTab == L.PLU_DM_TAB_BEHAVIOUR then
        -- Plugin-global; stored on SYSTEM_INDEX so all meters share the toggle.
        table.insert(schema.controls, {
            type = "checkbox",
            key = "AutoSwitchToCurrent",
            label = L.PLU_DM_AUTO_SWITCH_CURRENT,
            tooltip = L.PLU_DM_AUTO_SWITCH_CURRENT_TT,
            default = true,
            getValue = function() return self:GetSetting(DM.SystemIndex, "AutoSwitchToCurrent") end,
            onChange = function(v) self:SetSetting(DM.SystemIndex, "AutoSwitchToCurrent", v) end,
        })
        -- CVar proxy: read/write Blizzard state directly so our checkbox stays in sync with /console.
        table.insert(schema.controls, {
            type = "checkbox",
            key = "_AutoResetDamageMeter",
            label = L.PLU_DM_AUTO_RESET_INSTANCE,
            tooltip = L.PLU_DM_AUTO_RESET_INSTANCE_TT,
            getValue = function() return GetCVarBool(CVAR_AUTO_RESET) end,
            onChange = function(v)
                if InCombatLockdown() then return end
                SetCVar(CVAR_AUTO_RESET, v and "1" or "0")
            end,
        })
        OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
        return
    end

    -- [ QUICK COPY ] ----------------------------------------------------------
    local copyOptions = { { text = L.PLU_DM_SELECT_METER, value = "" } }
    local defs = self:GetMeterDefs()
    local userIDs = {}
    for id in pairs(defs) do userIDs[#userIDs + 1] = id end
    table.sort(userIDs)
    local METER_TYPE_LABEL_KEY = {
        [DM.MeterType.DamageDone]            = "PLU_DM_METRIC_DAMAGE",
        [DM.MeterType.Dps]                   = "PLU_DM_METRIC_DAMAGE",
        [DM.MeterType.HealingDone]           = "PLU_DM_METRIC_HEALING",
        [DM.MeterType.Hps]                   = "PLU_DM_METRIC_HEALING",
        [DM.MeterType.DamageTaken]           = "PLU_DM_METRIC_DAMAGETAKEN",
        [DM.MeterType.AvoidableDamageTaken]  = "PLU_DM_METRIC_AVOIDABLEDAMAGE",
        [DM.MeterType.EnemyDamageTaken]      = "PLU_DM_METRIC_ENEMYDAMAGETAKEN",
        [DM.MeterType.Interrupts]            = "PLU_DM_METRIC_INTERRUPTS",
        [DM.MeterType.Dispels]               = "PLU_DM_METRIC_DISPELS",
        [DM.MeterType.Deaths]                = "PLU_DM_METRIC_DEATHS",
    }
    for _, otherID in ipairs(userIDs) do
        if otherID ~= systemIndex then
            local d = defs[otherID]
            local metricLabel = L[METER_TYPE_LABEL_KEY[d.meterType] or "PLU_DM_METRIC_DAMAGE"] or ""
            local label = L.PLU_DM_METER_LABEL_F:format(otherID, metricLabel)
            copyOptions[#copyOptions + 1] = {
                text  = L.PLU_DM_COPY_FROM_F:format(label),
                value = tostring(otherID),
            }
        end
    end
    table.insert(schema.controls, {
        type = "quickcopyundo", key = "_CopyFrom", label = L.PLU_DM_QUICK_COPY, default = "",
        options = copyOptions,
        plugin = self,
        onChange = function(val)
            if not val or val == "" then return end
            local sourceID = tonumber(val)
            if not sourceID then return end
            local snapshot = self:CopyMeterSettings(sourceID, systemIndex)
            if snapshot then self._undoSnapshot = snapshot end
            C_Timer.After(0, function()
                OrbitEngine.Layout:Reset(dialog)
                self:AddSettings(dialog, systemFrame)
            end)
        end,
        onUndo = function()
            if not self._undoSnapshot then return end
            self:RestoreMeterSnapshot(systemIndex, self._undoSnapshot)
            self._undoSnapshot = nil
            C_Timer.After(0, function()
                OrbitEngine.Layout:Reset(dialog)
                self:AddSettings(dialog, systemFrame)
            end)
        end,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "Title",
        label = L.PLU_DM_TITLE,
        min = TITLE_OFF, max = TITLE_BOTTOM_RIGHT, step = 1,
        default = TITLE_TOP_LEFT,
        formatter = function(v) return TITLE_LABELS[v] or "" end,
        onChange = function(v)
            self:SetSetting(systemIndex, "Title", v)
            self:RelayoutAllMeters()
        end,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "TitleSize",
        label = L.PLU_DM_TITLE_SIZE,
        min = TITLE_SIZE_MIN, max = TITLE_SIZE_MAX, step = 1,
        default = TITLE_SIZE_DEFAULT,
        formatter = function(v) return v .. "px" end,
        onChange = function(v)
            self:SetSetting(systemIndex, "TitleSize", v)
            self:RelayoutAllMeters()
        end,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "BarHeight",
        label = L.PLU_DM_BAR_HEIGHT,
        min = BAR_HEIGHT_MIN, max = BAR_HEIGHT_MAX, step = 1,
        default = BAR_HEIGHT_DEFAULT,
        formatter = function(v) return v .. "px" end,
        onChange = function(v)
            self:SetSetting(systemIndex, "BarHeight", v)
            self:RelayoutAllMeters()
        end,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "BarGap",
        label = L.PLU_DM_BAR_GAP,
        min = BAR_GAP_MIN, max = BAR_GAP_MAX, step = 1,
        default = BAR_GAP_DEFAULT,
        formatter = function(v) return v .. "px" end,
        onChange = function(v)
            self:SetSetting(systemIndex, "BarGap", v)
            self:RelayoutAllMeters()
        end,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "IconPosition",
        label = L.CMN_ICON_POSITION,
        min = ICON_SLIDER_MIN, max = ICON_SLIDER_MAX, step = 1,
        default = 1,
        formatter = function(v) return ICON_LABELS[v] or "" end,
        onChange = function(v)
            self:SetSetting(systemIndex, "IconPosition", v)
            self:RelayoutAllMeters()
        end,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "Style",
        label = L.PLU_DM_STYLE,
        min = STYLE_MIN, max = STYLE_MAX, step = STYLE_STEP,
        default = STYLE_DEFAULT,
        formatter = function(v) return v .. "%" end,
        onChange = function(v)
            self:SetSetting(systemIndex, "Style", v)
            self:RelayoutAllMeters()
        end,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "Border",
        label = L.PLU_DM_BORDER,
        min = BORDER_NONE, max = BORDER_FRAME, step = 1,
        default = BORDER_FRAME,
        formatter = function(v) return BORDER_LABELS[v] or "" end,
        onChange = function(v)
            self:SetSetting(systemIndex, "Border", v)
            self:RelayoutAllMeters()
        end,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "Background",
        label = L.PLU_DM_BACKGROUND,
        min = BG_NONE, max = BG_FRAME, step = 1,
        default = BG_PER_BAR,
        formatter = function(v) return BG_LABELS[v] or "" end,
        onChange = function(v)
            self:SetSetting(systemIndex, "Background", v)
            self:RelayoutAllMeters()
        end,
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
