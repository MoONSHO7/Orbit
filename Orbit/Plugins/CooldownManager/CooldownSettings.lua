---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap
local CooldownUtils = OrbitEngine.CooldownUtils

function CDM:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    local schema = { controls = {}, extraButtons = {} }
    local SB = OrbitEngine.SchemaBuilder
    local isInheriting = false
    local frame = VIEWER_MAP[systemIndex] and VIEWER_MAP[systemIndex].anchor or systemFrame

    if frame and frame.isChildFrame then
        isInheriting = self:GetSetting(systemIndex, "InheritLayout")
    end

    -- Buff Bars get their own dedicated dialog
    if systemIndex == Constants.Cooldown.SystemIndex.BuffBar then
        SB:SetTabRefreshCallback(dialog, self, systemFrame)
        local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_CDM_TAB_LAYOUT, L.PLU_CDM_TAB_COLORS }, L.PLU_CDM_TAB_LAYOUT)

        if currentTab == L.PLU_CDM_TAB_LAYOUT then
            local buffBarAnchor = self.buffBarAnchor
            local isDocked = OrbitEngine.Frame:GetAnchorParent(buffBarAnchor) ~= nil
            local function ResizeCanvasPreview()
                local dlg = OrbitEngine.CanvasModeDialog
                if not dlg or not dlg:IsShown() or not dlg.previewFrame then return end
                local w = self:GetSetting(systemIndex, "Width") or 200
                local h = self:GetSetting(systemIndex, "Height") or 20
                dlg.previewFrame.sourceWidth = w
                dlg.previewFrame.sourceHeight = h
                dlg.previewFrame:SetSize(w, h)
                if dlg.TransformLayer then
                    dlg.TransformLayer.baseWidth = w
                    dlg.TransformLayer.baseHeight = h
                    dlg.TransformLayer:SetSize(w, h)
                    if OrbitEngine.CanvasMode.ApplyPanOffset then OrbitEngine.CanvasMode.ApplyPanOffset(dlg, dlg.panOffsetX, dlg.panOffsetY) end
                end
            end
            table.insert(schema.controls, {
                type = "slider", key = "Height", label = L.PLU_CDM_HEIGHT, min = 12, max = 40, step = 1, default = 20,
                onChange = function(val) self:SetSetting(systemIndex, "Height", val); self:ProcessChildren(buffBarAnchor); ResizeCanvasPreview() end,
            })
            if not isDocked then
                table.insert(schema.controls, {
                    type = "slider", key = "Width", label = L.PLU_CDM_WIDTH, min = 80, max = 400, step = 1, default = 200,
                    onChange = function(val) self:SetSetting(systemIndex, "Width", val); self:ProcessChildren(buffBarAnchor); ResizeCanvasPreview() end,
                })
            end
            table.insert(schema.controls, {
                type = "slider", key = "Spacing", label = L.PLU_CDM_SPACING, min = 0, max = 30, step = 1, default = 2,
                onChange = function(val) self:SetSetting(systemIndex, "Spacing", val); self:ProcessChildren(buffBarAnchor) end,
            })
        elseif currentTab == L.PLU_CDM_TAB_COLORS then
            local barColors = {
                { key = "BarColor1", label = L.PLU_CDM_BAR_1, default = { pins = { { position = 0, color = { r = 0.3, g = 0.7, b = 1, a = 1 } } } } },
                { key = "BarColor2", label = L.PLU_CDM_BAR_2, default = { pins = { { position = 0, color = { r = 0.4, g = 0.9, b = 0.4, a = 1 } } } } },
                { key = "BarColor3", label = L.PLU_CDM_BAR_3, default = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0.3, a = 1 } } } } },
                { key = "BarColor4", label = L.PLU_CDM_BAR_4, default = { pins = { { position = 0, color = { r = 0.9, g = 0.4, b = 0.9, a = 1 } } } } },
                { key = "BarColor5", label = L.PLU_CDM_BAR_5, default = { pins = { { position = 0, color = { r = 1, g = 0.4, b = 0.4, a = 1 } } } } },
            }
            for _, def in ipairs(barColors) do
                SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
                    key = def.key, label = def.label, default = def.default, singleColor = true,
                })
            end
        end

        OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
        return
    end

    table.insert(schema.extraButtons, {
        text = L.PLU_CDM_OPEN_CD_SETTINGS,
        callback = function()
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then securecall("HideUIPanel", EditModeManagerFrame) end
            if CooldownViewerSettings then CooldownViewerSettings:Show() end
        end,
    })

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local tabs = { L.PLU_CDM_TAB_LAYOUT, L.PLU_CDM_TAB_GLOW, L.PLU_CDM_TAB_COLORS }
    if systemIndex == Constants.Cooldown.SystemIndex.BuffIcon then
        tabs = { L.PLU_CDM_TAB_LAYOUT, L.PLU_CDM_TAB_GLOW, L.PLU_CDM_TAB_COLORS, L.PLU_CDM_TAB_BEHAVIOUR }
    end
    local currentTab = SB:AddSettingsTabs(schema, dialog, tabs, L.PLU_CDM_TAB_LAYOUT)

    if currentTab == L.PLU_CDM_TAB_LAYOUT then
        if isInheriting then
            table.insert(schema.controls, { type = "label", text = L.PLU_CDM_INHERITED })
        else
            table.insert(schema.controls, {
                type = "dropdown", key = "aspectRatio", label = L.PLU_CDM_ICON_ASPECT,
                options = {
                    { text = L.PLU_CDM_ASPECT_1_1, value = "1:1" }, { text = L.PLU_CDM_ASPECT_16_9, value = "16:9" },
                    { text = L.PLU_CDM_ASPECT_4_3, value = "4:3" }, { text = L.PLU_CDM_ASPECT_21_9, value = "21:9" },
                },
                default = "1:1",
            })
            table.insert(schema.controls, {
                type = "slider", key = "IconSize", label = L.PLU_CDM_ICON_SIZE,
                min = 20, max = 80, step = 1,
                formatter = function(v) return v .. "px" end,
                default = Constants.Cooldown.DefaultIconSize,
                onChange = function(val)
                    self:SetSetting(systemIndex, "IconSize", val)
                    self:ApplySettings(systemFrame)
                end,
            })
            table.insert(schema.controls, { type = "slider", key = "IconPadding", label = L.PLU_CDM_ICON_PADDING, min = 0, max = 15, step = 1, default = Constants.Cooldown.DefaultPadding })
            table.insert(schema.controls, { type = "slider", key = "IconLimit", label = L.PLU_CDM_NUM_COLUMNS, min = 1, max = 20, step = 1, default = Constants.Cooldown.DefaultLimit })
        end
    elseif currentTab == L.PLU_CDM_TAB_GLOW then
        table.insert(schema.controls, { type = "checkbox", key = "ShowGCDSwipe", label = L.PLU_CDM_SHOW_GCD_SWIPE, default = true })
        table.insert(schema.controls, {
            type = "checkbox", key = "AssistedHighlight", label = L.PLU_CDM_ASSISTED_GLOW, default = false,
            onChange = function(val)
                self:SetSetting(systemIndex, "AssistedHighlight", val)
                SetCVar("assistedCombatHighlight", val and "1" or "0")
                if self.UpdateAssistedHighlights then self:UpdateAssistedHighlights() end
            end,
        })
        SB:AddGlowSettings(self, schema, systemIndex, dialog, systemFrame, {
            prefix = "PandemicGlow",
            label = L.PLU_CDM_PANDEMIC_GLOW,
            default = Constants.Glow.DefaultType,
            onUpdate = function() self:MarkPandemicDirty() end
        })
        SB:AddGlowSettings(self, schema, systemIndex, dialog, systemFrame, {
            prefix = "ProcGlow",
            label = L.PLU_CDM_PROC_GLOW,
            default = Constants.Glow.DefaultType
        })
    elseif currentTab == L.PLU_CDM_TAB_COLORS then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "ActiveSwipeColorCurve", label = L.PLU_CDM_ACTIVE_SWIPE,
            default = { pins = { { position = 0, color = { r = 1, g = 0.95, b = 0.57, a = 0.7 } } } },
            singleColor = true,
        })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "CooldownSwipeColorCurve", label = L.PLU_CDM_COOLDOWN_SWIPE,
            default = { pins = { { position = 0, color = { r = 0, g = 0, b = 0, a = 0.8 } } } },
            singleColor = true,
        })
        if systemIndex ~= Constants.Cooldown.SystemIndex.BuffIcon and systemIndex ~= Constants.Cooldown.SystemIndex.BuffBar then
            SB:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "KeypressColor", label = L.PLU_CDM_KEYPRESS_FLASH,
                default = { r = 1, g = 1, b = 1, a = 0 },
            })
        end
    elseif currentTab == L.PLU_CDM_TAB_BEHAVIOUR then
        table.insert(schema.controls, {
            type = "checkbox", key = "AlwaysShow", label = L.PLU_CDM_ALWAYS_SHOW, default = false,
            tooltip = L.PLU_CDM_ALWAYS_SHOW_TT,
            onChange = function(val)
                self:SetSetting(systemIndex, "AlwaysShow", val)
                self:ApplyAll()
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end,
        })
        if self:GetSetting(systemIndex, "AlwaysShow") then
            table.insert(schema.controls, {
                type = "checkbox", key = "HideBorders", label = L.PLU_CDM_HIDE_BORDERS, default = false,
                tooltip = L.PLU_CDM_HIDE_BORDERS_TT,
                onChange = function(val) self:SetSetting(systemIndex, "HideBorders", val); self:ApplyAll() end,
            })
            table.insert(schema.controls, {
                type = "slider", key = "InactiveAlpha", label = L.PLU_CDM_INACTIVE_ALPHA, min = 20, max = 100, step = 1, default = 60,
                onChange = function(val) self:SetSetting(systemIndex, "InactiveAlpha", val); self:ApplyAll() end,
            })
        end
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ COMPONENT UTILITY ] -----------------------------------------------------------------------------
local _cdmDisabledHashCache = setmetatable({}, { __mode = "k" })

function CDM:IsComponentDisabled(componentKey, systemIndex)
    systemIndex = systemIndex or 1
    local Txn = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.Transaction
    local disabled = (Txn and Txn:IsActive() and Txn:GetPlugin() == self) and Txn:GetDisabledComponents() or self:GetSetting(systemIndex, "DisabledComponents") or {}
    local hash = _cdmDisabledHashCache[disabled]
    if not hash then
        hash = {}
        for _, key in ipairs(disabled) do hash[key] = true end
        _cdmDisabledHashCache[disabled] = hash
    end
    return hash[componentKey] or false
end
