-- [ GROUP FRAME SETTINGS ]---------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local SB = OrbitEngine.SchemaBuilder
local Helpers = Orbit.GroupFrameHelpers

-- [ ADD SETTINGS ]-----------------------------------------------------------------------------------
local ICON_BUTTON_SIZE = 20
local DISPEL_SPEED_MIN = -0.30
local DISPEL_SPEED_MAX = 0.30
local DISPEL_SPEED_STEP = 0.15
-- Integer-keyed (value*100) to avoid float-precision lookup misses.
local DISPEL_SPEED_LABELS = {
    [-30] = function() return Orbit.L.PLU_GRP_DISPEL_SPEED_VSLOW end,
    [-15] = function() return Orbit.L.PLU_GRP_DISPEL_SPEED_SLOW end,
    [0]   = function() return Orbit.L.PLU_GRP_DISPEL_SPEED_NORMAL end,
    [15]  = function() return Orbit.L.PLU_GRP_DISPEL_SPEED_FAST end,
    [30]  = function() return Orbit.L.PLU_GRP_DISPEL_SPEED_VFAST end,
}
local function FormatDispelSpeed(value)
    local key = math.floor(((value or 0) * 100 / 15) + 0.5) * 15
    local label = DISPEL_SPEED_LABELS[key]
    return label and label() or DISPEL_SPEED_LABELS[0]()
end

if not OrbitEngine.Layout:HasWidgetType("quickcopyundo") then
    OrbitEngine.Layout:RegisterWidgetType("quickcopyundo", function(container, def, getValue, callback)
        local options = type(def.options) == "function" and def.options() or def.options or {}
        local initialValue = getValue and getValue() or def.default or ""
        
        local UpdateState

        local frame = OrbitEngine.Layout:CreateDropdown(container, def.label, options, initialValue, function(value)
            if callback then callback(value) end
            C_Timer.After(0, function() if UpdateState then UpdateState() end end)
        end)
        frame.OrbitType = "QuickCopyUndo"

        local undoBtn = CreateFrame("Button", nil, frame)
        undoBtn:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
        undoBtn:SetPoint("LEFT", frame.Dropdown or frame.dropdown or frame, "RIGHT", 5, 0)
        frame.undoBtn = undoBtn
        
        local icon = undoBtn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetAtlas("talents-button-undo")
        undoBtn.Icon = icon
        
        UpdateState = function()
            local plugin = def.plugin
            if plugin and plugin._undoSnapshot then
                undoBtn:Enable()
                icon:SetDesaturated(false)
                icon:SetAlpha(1)
            else
                undoBtn:Disable()
                icon:SetDesaturated(true)
                icon:SetAlpha(0.4)
            end
        end
        
        undoBtn:SetScript("OnClick", function()
            if def.onUndo then def.onUndo() end
            UpdateState()
        end)
        undoBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self:IsEnabled() then
                self.Icon:SetAlpha(0.8)
                GameTooltip:SetText(L.PLU_GRP_UNDO_QUICK_COPY)
            else
                GameTooltip:SetText(L.PLU_GRP_NOTHING_UNDO)
            end
            GameTooltip:Show()
        end)
        undoBtn:SetScript("OnLeave", function(self)
            if self:IsEnabled() then self.Icon:SetAlpha(1) end
            GameTooltip:Hide()
        end)
        
        UpdateState()
        frame.UpdateState = UpdateState
        return frame
    end)
end

function Orbit.GroupFrameSettings(plugin, dialog, systemFrame)
    local MOC = function(key, pre) return SB:MakePluginOnChange(plugin, 1, key, pre) end
    local editTier = plugin:GetSetting(1, "_EditTier") or plugin:GetCurrentTier()
    local TierMOC = function(key, pre)
        return function(val)
            plugin:SetTierSetting(key, val, editTier)
            if pre then pre() end
            plugin:ApplySettings()
            if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:SchedulePreviewUpdate() end
        end
    end
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, plugin, systemFrame)

    -- Tier selector at the top
    local tierOptions = {}
    for _, tier in ipairs(Helpers.TIERS) do
        tierOptions[#tierOptions + 1] = { text = Helpers.TIER_LABELS[tier], value = tier }
    end
    table.insert(schema.controls, {
        type = "dropdown", key = "_EditTier", label = L.PLU_GRP_EDIT_TIER,
        default = plugin:GetCurrentTier(),
        options = tierOptions,
        onChange = function(val)
            if OrbitEngine.CanvasMode then OrbitEngine.CanvasMode:ExitAll() end
            plugin:SaveCurrentTierPosition()
            plugin:SetSetting(1, "_EditTier", val)
            plugin._editTierOverride = val
            plugin.container.orbitCanvasTitle = "Group Frame: " .. val
            plugin:ApplySettings()
            plugin:RestoreTierPosition(val)
            plugin:ShowPreview()
            C_Timer.After(0, function() OrbitEngine.Layout:Reset(dialog); Orbit.GroupFrameSettings(plugin, dialog, systemFrame) end)
        end,
    })

    plugin._editTierOverride = editTier
    local isParty = Helpers:IsPartyTier(editTier)

    local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_GRP_TAB_LAYOUT, L.PLU_GRP_TAB_COLORS, L.PLU_GRP_TAB_INDICATORS }, L.PLU_GRP_TAB_LAYOUT, plugin)

    if currentTab == L.PLU_GRP_TAB_LAYOUT then
        -- Copy controls
        local copyOptions = { { text = L.PLU_GRP_SELECT_TIER, value = "" } }
        for _, tier in ipairs(Helpers.TIERS) do
            if tier ~= editTier then
                copyOptions[#copyOptions + 1] = { text = L.PLU_GRP_COPY_FROM_F:format(Helpers.TIER_LABELS[tier]), value = tier }
            end
        end
        table.insert(schema.controls, {
            type = "quickcopyundo", key = "_CopyFrom", label = L.PLU_GRP_QUICK_COPY, default = "",
            options = copyOptions,
            plugin = plugin,
            onChange = function(val)
                if val and val ~= "" then
                    local tiers = plugin:GetSetting(1, "Tiers") or {}
                    plugin._undoSnapshot = CopyTable(tiers[editTier] or {})
                    plugin:CopyTierSettings(val, editTier)
                    plugin:ApplySettings()
                    C_Timer.After(0, function() OrbitEngine.Layout:Reset(dialog); Orbit.GroupFrameSettings(plugin, dialog, systemFrame) end)
                end
            end,
            onUndo = function()
                if plugin._undoSnapshot then
                    local tiers = plugin:GetSetting(1, "Tiers") or {}
                    tiers[editTier] = plugin._undoSnapshot
                    plugin:SetSetting(1, "Tiers", tiers)
                    plugin._undoSnapshot = nil
                    plugin:ApplySettings()
                    C_Timer.After(0, function() OrbitEngine.Layout:Reset(dialog); Orbit.GroupFrameSettings(plugin, dialog, systemFrame) end)
                end
            end,
        })


        if isParty then
            -- Party-specific layout controls
            local orientation = plugin:GetTierSetting("Orientation", editTier) or 0
            table.insert(schema.controls, {
                type = "dropdown", key = "Orientation", label = L.PLU_GRP_ORIENTATION, default = 0,
                options = { { text = L.PLU_GRP_ORIENT_VERTICAL, value = 0 }, { text = L.PLU_GRP_ORIENT_HORIZONTAL, value = 1 } },
                onChange = function(val)
                    plugin:SetTierSetting("Orientation", val, editTier)
                    plugin:SetTierSetting("GrowthDirection", val == 0 and "down" or "right", editTier)
                    plugin:ApplySettings()
                    if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:SchedulePreviewUpdate() end
                    if dialog.orbitTabCallback then dialog.orbitTabCallback() end
                end,
            })
            local growthOptions = orientation == 0 and { { text = L.PLU_GRP_GROW_DOWN, value = "down" }, { text = L.PLU_GRP_GROW_UP, value = "up" }, { text = L.PLU_GRP_GROW_CENTER, value = "center" } }
                or { { text = L.PLU_GRP_GROW_RIGHT, value = "right" }, { text = L.PLU_GRP_GROW_LEFT, value = "left" }, { text = L.PLU_GRP_GROW_CENTER, value = "center" } }
            table.insert(schema.controls, { type = "dropdown", key = "GrowthDirection", label = L.PLU_GRP_GROWTH, default = orientation == 0 and "down" or "right", options = growthOptions, onChange = TierMOC("GrowthDirection") })
            table.insert(schema.controls, { type = "slider", key = "Width", label = L.PLU_GRP_WIDTH, min = 50, max = 400, step = 1, default = 160, onChange = TierMOC("Width") })
            table.insert(schema.controls, { type = "slider", key = "Height", label = L.PLU_GRP_HEIGHT, min = 20, max = 100, step = 1, default = 40, onChange = TierMOC("Height") })
            table.insert(schema.controls, { type = "slider", key = "Spacing", label = L.PLU_GRP_SPACING, min = 0, max = 50, step = 1, default = 0, onChange = TierMOC("Spacing") })
            table.insert(schema.controls, { type = "slider", key = "OutOfRangeOpacity", label = L.PLU_GRP_OUT_OF_RANGE_OPACITY, min = 0, max = 80, step = 5, default = 30, suffix = "%", onChange = TierMOC("OutOfRangeOpacity") })
            table.insert(schema.controls, {
                type = "checkbox", key = "IncludePlayer", label = L.PLU_GRP_INCLUDE_PLAYER, default = false,
                onChange = TierMOC("IncludePlayer", function()
                    if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:ShowPreview() else plugin:UpdateFrameUnits() end
                end),
            })
            local showPower = plugin:GetTierSetting("ShowPowerBar", editTier)
            if showPower == nil then showPower = true end
            table.insert(schema.controls, { type = "checkbox", key = "ShowPowerBar", label = L.PLU_GRP_SHOW_POWER_BAR, default = true, onChange = function(val)
                TierMOC("ShowPowerBar")(val)
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end })
            if showPower then
                table.insert(schema.controls, { type = "slider", key = "PowerBarHeight", label = L.PLU_GRP_POWER_BAR_HEIGHT, min = 5, max = 30, step = 1, default = 10, suffix = "%", onChange = TierMOC("PowerBarHeight") })
            end
        else
            -- Raid-specific layout controls
            local tierMax = Helpers:GetTierMaxFrames(editTier)
            local maxGroups = math.ceil(tierMax / 5)
            local sortMode = plugin:GetTierSetting("SortMode", editTier) or "group"
            if sortMode == "group" then
                table.insert(schema.controls, {
                    type = "dropdown", key = "Orientation", label = L.PLU_GRP_ORIENTATION, default = "vertical",
                    options = { { text = L.PLU_GRP_ORIENT_VERTICAL, value = "vertical" }, { text = L.PLU_GRP_ORIENT_HORIZONTAL, value = "horizontal" } },
                    onChange = TierMOC("Orientation"),
                })
            end
            table.insert(schema.controls, { type = "dropdown", key = "GrowthDirection", label = L.PLU_GRP_GROWTH, default = "down", options = { { text = L.PLU_GRP_GROW_DOWN, value = "down" }, { text = L.PLU_GRP_GROW_UP, value = "up" }, { text = L.PLU_GRP_GROW_CENTER, value = "center" } }, onChange = TierMOC("GrowthDirection") })
            table.insert(schema.controls, {
                type = "dropdown", key = "SortMode", label = L.PLU_GRP_SORT_MODE, default = "group",
                options = { { text = L.PLU_GRP_SORT_GROUP, value = "group" }, { text = L.PLU_GRP_SORT_ROLE, value = "role" }, { text = L.PLU_GRP_SORT_ALPHABETICAL, value = "alphabetical" } },
                onChange = function(val)
                    plugin:SetTierSetting("SortMode", val, editTier)
                    if not InCombatLockdown() then plugin:UpdateFrameUnits(); plugin:PositionFrames() end
                    if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:SchedulePreviewUpdate() end
                    C_Timer.After(0, function() OrbitEngine.Layout:Reset(dialog); Orbit.GroupFrameSettings(plugin, dialog, systemFrame) end)
                end,
            })
            table.insert(schema.controls, { type = "slider", key = "Width", label = L.PLU_GRP_WIDTH, min = 50, max = 200, step = 1, default = 100, onChange = TierMOC("Width") })
            table.insert(schema.controls, { type = "slider", key = "Height", label = L.PLU_GRP_HEIGHT, min = 20, max = 80, step = 1, default = 40, onChange = TierMOC("Height") })
            table.insert(schema.controls, { type = "slider", key = "MemberSpacing", label = L.PLU_GRP_MEMBER_SPACING, min = 0, max = 50, step = 1, default = 2, onChange = TierMOC("MemberSpacing") })
            table.insert(schema.controls, { type = "slider", key = "OutOfRangeOpacity", label = L.PLU_GRP_OUT_OF_RANGE_OPACITY, min = 0, max = 80, step = 5, default = 30, suffix = "%", onChange = TierMOC("OutOfRangeOpacity") })
            if sortMode == "group" then
                local gprDefault = math.min(maxGroups, 6)
                table.insert(schema.controls, { type = "slider", key = "GroupsPerRow", label = L.PLU_GRP_GROUPS_PER_ROW, min = 1, max = maxGroups, step = 1, default = gprDefault, onChange = TierMOC("GroupsPerRow") })
                table.insert(schema.controls, { type = "slider", key = "GroupSpacing", label = L.PLU_GRP_GROUP_SPACING, min = 0, max = 50, step = 1, default = 4, onChange = TierMOC("GroupSpacing") })
            else
                local maxFlatRows = math.max(1, math.ceil(tierMax / 5))
                table.insert(schema.controls, { type = "slider", key = "FlatRows", label = L.PLU_GRP_ROWS, min = 1, max = maxFlatRows, step = 1, default = 1, onChange = TierMOC("FlatRows") })
            end
            table.insert(schema.controls, {
                type = "checkbox", key = "HideBlizzardRaidPanel", label = L.PLU_GRP_HIDE_BLIZZ_RAID, default = false,
                onChange = function(val)
                    plugin:SetSetting(1, "HideBlizzardRaidPanel", val)
                    if plugin.UpdateBlizzardRaidPanelVisibility then
                        plugin:UpdateBlizzardRaidPanelVisibility()
                    end
                end,
            })
            local showPower = plugin:GetTierSetting("ShowPowerBar", editTier)
            if showPower == nil then showPower = true end
            table.insert(schema.controls, { type = "checkbox", key = "ShowPowerBar", label = L.PLU_GRP_HEALER_POWER, default = true, onChange = function(val)
                TierMOC("ShowPowerBar")(val)
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end })
            if showPower then
                table.insert(schema.controls, { type = "slider", key = "PowerBarHeight", label = L.PLU_GRP_POWER_BAR_HEIGHT, min = 5, max = 30, step = 1, default = 16, suffix = "%", onChange = TierMOC("PowerBarHeight") })
            end
        end
    elseif currentTab == L.PLU_GRP_TAB_COLORS then
        table.insert(schema.controls, { type = "color", key = "SelectionColor", label = L.PLU_GRP_SELECT_HIGHLIGHT, default = { r = 0.8, g = 0.9, b = 1.0, a = 1 }, onChange = TierMOC("SelectionColor") })
        local aggroRefresh = function() Orbit.AggroIndicatorMixin:InvalidateAggroSettings(plugin); if plugin.UpdateAllAggroIndicators then plugin:UpdateAllAggroIndicators(plugin) end end
        table.insert(schema.controls, { type = "color", key = "AggroColor", label = L.PLU_GRP_AGGRO_HIGHLIGHT, default = { r = 1.0, g = 0.0, b = 0.0, a = 1 }, onChange = TierMOC("AggroColor", aggroRefresh) })
    elseif currentTab == L.PLU_GRP_TAB_INDICATORS then
        if not isParty and (plugin:GetTierSetting("SortMode", editTier) or "group") == "group" then
            table.insert(schema.controls, { type = "checkbox", key = "ShowGroupLabels", label = L.PLU_GRP_SHOW_GROUPS, default = true, onChange = TierMOC("ShowGroupLabels") })
        end
        local dispelRefresh = function()
            Orbit.DispelIndicatorMixin:InvalidateDispelCurve(plugin)
            if plugin.UpdateAllDispelIndicators then plugin:UpdateAllDispelIndicators(plugin) end
            if plugin.RefreshDispelPreview then plugin:RefreshDispelPreview() end
        end
        local dispelToggle = function() dispelRefresh(); if dialog.orbitTabCallback then dialog.orbitTabCallback() end end
        
        local dispelEnabled = plugin:GetTierSetting("DispelIndicatorEnabled", editTier)
        if dispelEnabled == nil then dispelEnabled = true end

        table.insert(schema.controls, { type = "checkbox", key = "DispelIndicatorEnabled", label = L.PLU_GRP_DISPEL_ENABLE, default = true, onChange = TierMOC("DispelIndicatorEnabled", dispelToggle) })

        if dispelEnabled then
            table.insert(schema.controls, { type = "checkbox", key = "DispelOnlyByMe", label = L.PLU_GRP_DISPEL_ME, default = false, onChange = TierMOC("DispelOnlyByMe", dispelRefresh) })
            local glowType = plugin:GetTierSetting("DispelGlowType", editTier) or Orbit.Constants.Glow.Type.Pixel
            table.insert(schema.controls, { type = "dropdown", key = "DispelGlowType", label = L.PLU_GRP_DISPEL_GLOW, default = Orbit.Constants.Glow.Type.Pixel, options = { { label = L.PLU_GRP_DISPEL_PIXEL, value = Orbit.Constants.Glow.Type.Pixel }, { label = L.PLU_GRP_DISPEL_AUTOCAST, value = Orbit.Constants.Glow.Type.Autocast } }, onChange = TierMOC("DispelGlowType", dispelToggle) })

            local def = Orbit.Constants.Glow.Defaults.Pixel
            if glowType == Orbit.Constants.Glow.Type.Autocast then
                def = Orbit.Constants.Glow.Defaults.Autocast
                table.insert(schema.controls, { type = "slider", key = "DispelNumLines", label = L.PLU_GRP_DISPEL_PARTICLES, min = 1, max = 20, step = 1, default = def.Particles, onChange = TierMOC("DispelNumLines", dispelRefresh) })
            else
                table.insert(schema.controls, { type = "slider", key = "DispelNumLines", label = L.PLU_GRP_DISPEL_LINES, min = 1, max = 20, step = 1, default = def.Lines, onChange = TierMOC("DispelNumLines", dispelRefresh) })
            end

            table.insert(schema.controls, { type = "slider", key = "DispelFrequency", label = L.PLU_GRP_DISPEL_SPEED, min = DISPEL_SPEED_MIN, max = DISPEL_SPEED_MAX, step = DISPEL_SPEED_STEP, default = 0.0, formatter = FormatDispelSpeed, onChange = TierMOC("DispelFrequency", dispelRefresh) })

            if glowType == Orbit.Constants.Glow.Type.Pixel then
                table.insert(schema.controls, { type = "slider", key = "DispelLength", label = L.PLU_GRP_DISPEL_LENGTH, min = 1, max = 150, step = 1, default = def.Length, onChange = TierMOC("DispelLength", dispelRefresh) })
                table.insert(schema.controls, { type = "slider", key = "DispelThickness", label = L.PLU_GRP_DISPEL_THICKNESS, min = 1, max = 10, step = 1, default = def.Thickness, onChange = TierMOC("DispelThickness", dispelRefresh) })
                table.insert(schema.controls, { type = "checkbox", key = "DispelBorder", label = L.PLU_GRP_DISPEL_BORDER, default = def.Border, onChange = TierMOC("DispelBorder", dispelRefresh) })
            end
        end
    end

    OrbitEngine.Config:Render(dialog, systemFrame, plugin, schema)
end
