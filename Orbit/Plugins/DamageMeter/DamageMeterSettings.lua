---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local BORDER = DM.Border
local BG = DM.Background
local TITLE = DM.Title
local ICON = DM.IconPos
local CVAR_AUTO_RESET = "damageMeterResetOnNewInstance"
local BAR_HEIGHT_MIN = 14
local BAR_HEIGHT_MAX = 40
local BAR_GAP_MIN = 0
local BAR_GAP_MAX = 8
local STYLE_MIN = 0
local STYLE_MAX = 100
local STYLE_STEP = 5
local TITLE_SIZE_MIN = 8
local TITLE_SIZE_MAX = 22

local BORDER_LABELS = {
    [BORDER.None]   = L.PLU_DM_BORDER_NONE,
    [BORDER.PerBar] = L.PLU_DM_BORDER_PER_BAR,
    [BORDER.Frame]  = L.PLU_DM_BORDER_FRAME,
}
local BG_LABELS = {
    [BG.None]   = L.PLU_DM_BG_NONE,
    [BG.PerBar] = L.PLU_DM_BG_PER_BAR,
    [BG.Frame]  = L.PLU_DM_BG_FRAME,
}
local TITLE_LABELS = {
    [TITLE.Off]         = L.PLU_DM_TITLE_OFF,
    [TITLE.TopLeft]     = L.PLU_DM_TITLE_TOP_LEFT,
    [TITLE.TopRight]    = L.PLU_DM_TITLE_TOP_RIGHT,
    [TITLE.BottomLeft]  = L.PLU_DM_TITLE_BOTTOM_LEFT,
    [TITLE.BottomRight] = L.PLU_DM_TITLE_BOTTOM_RIGHT,
}
local ICON_LABELS = {
    [ICON.Left]  = L.CMN_ICON_LEFT,
    [ICON.Off]   = L.CMN_ICON_OFF,
    [ICON.Right] = L.CMN_ICON_RIGHT,
}

local Plugin = Orbit:GetPlugin(DM.SystemID)
if not Plugin then return end

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
    for _, otherID in ipairs(userIDs) do
        if otherID ~= systemIndex then
            local d = defs[otherID]
            local metricLabel = L[DM.MetricLabelKeys[d.meterType] or "PLU_DM_METRIC_DAMAGE"] or ""
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
        min = TITLE.Off, max = TITLE.BottomRight, step = 1,
        default = DM.DefaultDef.title,
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
        default = DM.DefaultDef.titleSize,
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
        default = DM.DefaultDef.barHeight,
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
        default = DM.DefaultDef.barGap,
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
        min = ICON.Left, max = ICON.Right, step = 1,
        default = DM.DefaultDef.iconPosition,
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
        default = DM.DefaultDef.style,
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
        min = BORDER.None, max = BORDER.Frame, step = 1,
        default = DM.DefaultDef.border,
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
        min = BG.None, max = BG.Frame, step = 1,
        default = DM.DefaultDef.background,
        formatter = function(v) return BG_LABELS[v] or "" end,
        onChange = function(v)
            self:SetSetting(systemIndex, "Background", v)
            self:RelayoutAllMeters()
        end,
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
