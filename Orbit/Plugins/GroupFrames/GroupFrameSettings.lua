-- [ GROUP FRAME SETTINGS ]--------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local SB = OrbitEngine.SchemaBuilder
local Helpers = Orbit.GroupFrameHelpers

-- [ ADD SETTINGS ]----------------------------------------------------------------------------------
local ICON_BUTTON_SIZE = 20

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
                GameTooltip:SetText("Undo Quick Copy")
            else
                GameTooltip:SetText("Nothing to undo")
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
        type = "dropdown", key = "_EditTier", label = "Editing Tier",
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

    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Colors", "Indicators" }, "Layout", plugin)

    if currentTab == "Layout" then
        -- Copy controls
        local copyOptions = { { text = "Select Tier...", value = "" } }
        for _, tier in ipairs(Helpers.TIERS) do
            if tier ~= editTier then
                copyOptions[#copyOptions + 1] = { text = "Copy from " .. Helpers.TIER_LABELS[tier], value = tier }
            end
        end
        table.insert(schema.controls, {
            type = "quickcopyundo", key = "_CopyFrom", label = "Quick Copy", default = "",
            options = copyOptions,
            plugin = plugin,
            onChange = function(val)
                if val and val ~= "" then
                    local tiers = plugin:GetSetting(1, "Tiers") or {}
                    plugin._undoSnapshot = Orbit.Engine.DeepCopy and Orbit.Engine.DeepCopy(tiers[editTier] or {}) or CopyTable(tiers[editTier] or {})
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
                type = "dropdown", key = "Orientation", label = "Orientation", default = 0,
                options = { { text = "Vertical", value = 0 }, { text = "Horizontal", value = 1 } },
                onChange = function(val)
                    plugin:SetTierSetting("Orientation", val, editTier)
                    plugin:SetTierSetting("GrowthDirection", val == 0 and "Down" or "Right", editTier)
                    plugin:ApplySettings()
                    if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:SchedulePreviewUpdate() end
                    if dialog.orbitTabCallback then dialog.orbitTabCallback() end
                end,
            })
            local growthOptions = orientation == 0 and { { text = "Down", value = "Down" }, { text = "Up", value = "Up" }, { text = "Center", value = "Center" } }
                or { { text = "Right", value = "Right" }, { text = "Left", value = "Left" }, { text = "Center", value = "Center" } }
            table.insert(schema.controls, { type = "dropdown", key = "GrowthDirection", label = "Growth Direction", default = orientation == 0 and "Down" or "Right", options = growthOptions, onChange = TierMOC("GrowthDirection") })
            table.insert(schema.controls, { type = "slider", key = "Width", label = "Width", min = 50, max = 400, step = 1, default = 160, onChange = TierMOC("Width") })
            table.insert(schema.controls, { type = "slider", key = "Height", label = "Height", min = 20, max = 100, step = 1, default = 40, onChange = TierMOC("Height") })
            table.insert(schema.controls, { type = "slider", key = "Spacing", label = "Spacing", min = 0, max = 50, step = 1, default = 0, onChange = TierMOC("Spacing") })
            table.insert(schema.controls, {
                type = "checkbox", key = "IncludePlayer", label = "Include Player", default = false,
                onChange = TierMOC("IncludePlayer", function()
                    if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:ShowPreview() else plugin:UpdateFrameUnits() end
                end),
            })
            local showPower = plugin:GetTierSetting("ShowPowerBar", editTier)
            if showPower == nil then showPower = true end
            table.insert(schema.controls, { type = "checkbox", key = "ShowPowerBar", label = "Show Power Bar", default = true, onChange = function(val)
                TierMOC("ShowPowerBar")(val)
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end })
            if showPower then
                table.insert(schema.controls, { type = "slider", key = "PowerBarHeight", label = "Powerbar Height", min = 5, max = 30, step = 1, default = 10, suffix = "%", onChange = TierMOC("PowerBarHeight") })
            end
        else
            -- Raid-specific layout controls
            local tierMax = Helpers:GetTierMaxFrames(editTier)
            local maxGroups = math.ceil(tierMax / 5)
            local sortMode = plugin:GetTierSetting("SortMode", editTier) or "Group"
            if sortMode == "Group" then
                table.insert(schema.controls, {
                    type = "dropdown", key = "Orientation", label = "Orientation", default = "Vertical",
                    options = { { text = "Vertical", value = "Vertical" }, { text = "Horizontal", value = "Horizontal" } },
                    onChange = TierMOC("Orientation"),
                })
            end
            table.insert(schema.controls, { type = "dropdown", key = "GrowthDirection", label = "Growth Direction", default = "Down", options = { { text = "Down", value = "Down" }, { text = "Up", value = "Up" }, { text = "Center", value = "Center" } }, onChange = TierMOC("GrowthDirection") })
            table.insert(schema.controls, {
                type = "dropdown", key = "SortMode", label = "Sort Mode", default = "Group",
                options = { { text = "Group", value = "Group" }, { text = "Role", value = "Role" }, { text = "Alphabetical", value = "Alphabetical" } },
                onChange = function(val)
                    plugin:SetTierSetting("SortMode", val, editTier)
                    if not InCombatLockdown() then plugin:UpdateFrameUnits(); plugin:PositionFrames() end
                    if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:SchedulePreviewUpdate() end
                    C_Timer.After(0, function() OrbitEngine.Layout:Reset(dialog); Orbit.GroupFrameSettings(plugin, dialog, systemFrame) end)
                end,
            })
            table.insert(schema.controls, { type = "slider", key = "Width", label = "Width", min = 50, max = 200, step = 1, default = 100, onChange = TierMOC("Width") })
            table.insert(schema.controls, { type = "slider", key = "Height", label = "Height", min = 20, max = 80, step = 1, default = 40, onChange = TierMOC("Height") })
            table.insert(schema.controls, { type = "slider", key = "MemberSpacing", label = "Member Spacing", min = 0, max = 50, step = 1, default = 2, onChange = TierMOC("MemberSpacing") })
            if sortMode == "Group" then
                local gprDefault = math.min(maxGroups, 6)
                table.insert(schema.controls, { type = "slider", key = "GroupsPerRow", label = "Groups Per Row", min = 1, max = maxGroups, step = 1, default = gprDefault, onChange = TierMOC("GroupsPerRow") })
                table.insert(schema.controls, { type = "slider", key = "GroupSpacing", label = "Group Spacing", min = 0, max = 50, step = 1, default = 4, onChange = TierMOC("GroupSpacing") })
            else
                local maxFlatRows = math.max(1, math.ceil(tierMax / 5))
                table.insert(schema.controls, { type = "slider", key = "FlatRows", label = "Rows", min = 1, max = maxFlatRows, step = 1, default = 1, onChange = TierMOC("FlatRows") })
            end
            table.insert(schema.controls, {
                type = "checkbox", key = "HideBlizzardRaidPanel", label = "Hide Blizzard Raid Panel", default = false,
                onChange = function(val)
                    plugin:SetSetting(1, "HideBlizzardRaidPanel", val)
                    if plugin.UpdateBlizzardRaidPanelVisibility then
                        plugin:UpdateBlizzardRaidPanelVisibility()
                    end
                end,
            })
            local showPower = plugin:GetTierSetting("ShowPowerBar", editTier)
            if showPower == nil then showPower = true end
            table.insert(schema.controls, { type = "checkbox", key = "ShowPowerBar", label = "Show Healer Power Bars", default = true, onChange = function(val)
                TierMOC("ShowPowerBar")(val)
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end })
            if showPower then
                table.insert(schema.controls, { type = "slider", key = "PowerBarHeight", label = "Powerbar Height", min = 5, max = 30, step = 1, default = 16, suffix = "%", onChange = TierMOC("PowerBarHeight") })
            end
        end
    elseif currentTab == "Colors" then
        table.insert(schema.controls, { type = "color", key = "SelectionColor", label = "Selection Highlight", default = { r = 0.8, g = 0.9, b = 1.0, a = 1 }, onChange = TierMOC("SelectionColor") })
        local aggroRefresh = function() Orbit.AggroIndicatorMixin:InvalidateAggroSettings(plugin); if plugin.UpdateAllAggroIndicators then plugin:UpdateAllAggroIndicators(plugin) end end
        table.insert(schema.controls, { type = "color", key = "AggroColor", label = "Aggro Highlight", default = { r = 1.0, g = 0.0, b = 0.0, a = 1 }, onChange = TierMOC("AggroColor", aggroRefresh) })
    elseif currentTab == "Indicators" then
        if not isParty and (plugin:GetTierSetting("SortMode", editTier) or "Group") == "Group" then
            table.insert(schema.controls, { type = "checkbox", key = "ShowGroupLabels", label = "Show Groups", default = true, onChange = TierMOC("ShowGroupLabels") })
        end
        local dispelRefresh = function() Orbit.DispelIndicatorMixin:InvalidateDispelCurve(plugin); if plugin.UpdateAllDispelIndicators then plugin:UpdateAllDispelIndicators(plugin) end end
        table.insert(schema.controls, { type = "checkbox", key = "DispelIndicatorEnabled", label = "Enable Dispel Indicators", default = true, onChange = TierMOC("DispelIndicatorEnabled", dispelRefresh) })
        table.insert(schema.controls, { type = "checkbox", key = "DispelOnlyByMe", label = "Only Dispellable By Me", default = false, onChange = TierMOC("DispelOnlyByMe", dispelRefresh) })
        table.insert(schema.controls, { type = "slider", key = "DispelThickness", label = "Dispel Border Thickness", default = 2, min = 1, max = 5, step = 1, onChange = TierMOC("DispelThickness", dispelRefresh) })
        table.insert(schema.controls, { type = "slider", key = "DispelFrequency", label = "Dispel Animation Speed", default = 0.25, min = 0.1, max = 1.0, step = 0.05, onChange = TierMOC("DispelFrequency", dispelRefresh) })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, plugin, schema)
end
