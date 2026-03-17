---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap
local CooldownUtils = OrbitEngine.CooldownUtils
local function RelayoutChargeBars(plugin) Orbit.ChargeBarLayout:LayoutChargeBars(plugin) end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function CDM:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or 1
    local SB = OrbitEngine.SchemaBuilder

    local frame = self:GetFrameBySystemIndex(systemIndex)
    local isAnchored = frame and OrbitEngine.Frame:GetAnchorParent(frame) ~= nil
    local isTracked = frame and frame.isTrackedBar
    local isInheriting = frame and CooldownUtils:IsInheritingLayout(self, frame, VIEWER_MAP)

    local schema = { hideNativeSettings = true, controls = {}, extraButtons = {} }

    -- Charge Bars get their own dedicated dialog
    if frame and frame.isChargeBar then
        SB:SetTabRefreshCallback(dialog, self, systemFrame)
        local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Colors", "Visibility" }, "Layout")

        if currentTab == "Layout" then
            if not isAnchored then
                table.insert(schema.controls, {
                    type = "slider", key = "Width", label = "Width", min = 50, max = 400, step = 1, default = 120,
                    onChange = function(val) self:SetSetting(systemIndex, "Width", val); RelayoutChargeBars(self) end,
                })
            end
            table.insert(schema.controls, {
                type = "slider", key = "Height", label = "Height", min = 6, max = 40, step = 1, default = 12,
                onChange = function(val) self:SetSetting(systemIndex, "Height", val); RelayoutChargeBars(self) end,
            })
            table.insert(schema.controls, {
                type = "slider", key = "Spacing", label = "Spacing", min = 0, max = 50, step = 1, default = 0,
                onChange = function(val) self:SetSetting(systemIndex, "Spacing", val); RelayoutChargeBars(self) end,
            })
            table.insert(schema.controls, {
                type = "slider", key = "TickSize", label = "Tick", min = 0, max = 6, step = 2, default = 6,
                tooltip = "Width of the leading-edge tick mark (0 = hidden)",
                onChange = function(val) self:SetSetting(systemIndex, "TickSize", val); RelayoutChargeBars(self) end,
            })
        elseif currentTab == "Colors" then
            SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
                key = "BarColorCurve", label = "Bar Color",
                onChange = function(curveData)
                    self:SetSetting(systemIndex, "BarColorCurve", curveData)
                    RelayoutChargeBars(self)
                end,
            })
        elseif currentTab == "Visibility" then
            SB:AddOpacitySettings(self, schema, systemIndex, systemFrame)
            table.insert(schema.controls, {
                type = "checkbox", key = "OutOfCombatFade", label = "Out of Combat Fade", default = false,
                tooltip = "Hide frame when out of combat with no target",
                onChange = function(val)
                    self:SetSetting(systemIndex, "OutOfCombatFade", val)
                    Orbit.OOCFadeMixin:RefreshAll()
                    if dialog.orbitTabCallback then dialog.orbitTabCallback() end
                end,
            })
            table.insert(schema.controls, {
                type = "checkbox", key = "MouseoverOnly", label = "Mouseover Only", default = false,
                tooltip = "Only show frame while mousing over it",
                onChange = function(val)
                    self:SetSetting(systemIndex, "MouseoverOnly", val)
                    local data = VIEWER_MAP[systemIndex]
                    if data and data.anchor then
                        Orbit.OOCFadeMixin:ApplyOOCFade(data.anchor, self, systemIndex, "OutOfCombatFade", false)
                        Orbit.OOCFadeMixin:RefreshAll()
                    end
                end,
            })
            table.insert(schema.controls, {
                type = "checkbox", key = "SmoothAnimation", label = "Smooth Animation", default = false,
                tooltip = "Smoothly animate charge transitions",
                onChange = function(val)
                    self:SetSetting(systemIndex, "SmoothAnimation", val)
                end,
            })
            table.insert(schema.controls, {
                type = "checkbox", key = "FrequentUpdates", label = "Frequent Updates", default = true,
                tooltip = "Updates the charge bar every frame instead of interval ticks",
                onChange = function(val)
                    self:SetSetting(systemIndex, "FrequentUpdates", val)
                    self:RefreshChargeUpdateMethod()
                end,
            })
        end

        OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
        return
    end

    -- Buff Bars get their own dedicated dialog
    if systemIndex == Constants.Cooldown.SystemIndex.BuffBar then
        SB:SetTabRefreshCallback(dialog, self, systemFrame)
        local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Colors" }, "Layout")

        if currentTab == "Layout" then
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
                type = "slider", key = "Height", label = "Bar Height", min = 12, max = 40, step = 1, default = 20,
                onChange = function(val) self:SetSetting(systemIndex, "Height", val); self:ProcessChildren(buffBarAnchor); ResizeCanvasPreview() end,
            })
            if not isDocked then
                table.insert(schema.controls, {
                    type = "slider", key = "Width", label = "Bar Width", min = 80, max = 400, step = 1, default = 200,
                    onChange = function(val) self:SetSetting(systemIndex, "Width", val); self:ProcessChildren(buffBarAnchor); ResizeCanvasPreview() end,
                })
            end
            table.insert(schema.controls, {
                type = "slider", key = "Spacing", label = "Spacing", min = -3, max = 20, step = 1, default = 2,
                onChange = function(val) self:SetSetting(systemIndex, "Spacing", val); self:ProcessChildren(buffBarAnchor) end,
            })
        elseif currentTab == "Colors" then
            local barColors = {
                { key = "BarColor1", label = "Bar 1", default = { pins = { { position = 0, color = { r = 0.3, g = 0.7, b = 1, a = 1 } } } } },
                { key = "BarColor2", label = "Bar 2", default = { pins = { { position = 0, color = { r = 0.4, g = 0.9, b = 0.4, a = 1 } } } } },
                { key = "BarColor3", label = "Bar 3", default = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0.3, a = 1 } } } } },
                { key = "BarColor4", label = "Bar 4", default = { pins = { { position = 0, color = { r = 0.9, g = 0.4, b = 0.9, a = 1 } } } } },
                { key = "BarColor5", label = "Bar 5", default = { pins = { { position = 0, color = { r = 1, g = 0.4, b = 0.4, a = 1 } } } } },
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

    if not isTracked then
        table.insert(schema.extraButtons, {
            text = "Cooldown Settings",
            callback = function()
                if EditModeManagerFrame and EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
                if CooldownViewerSettings then CooldownViewerSettings:Show() end
            end,
        })
    end

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Glow", "Colors", "Visibility" }, "Layout")

    if currentTab == "Layout" then
        if isInheriting then
            table.insert(schema.controls, { type = "label", text = "Layout settings inherited from anchor parent." })
        else
            table.insert(schema.controls, {
                type = "dropdown", key = "aspectRatio", label = "Icon Aspect Ratio",
                options = {
                    { text = "Square (1:1)", value = "1:1" }, { text = "Landscape (16:9)", value = "16:9" },
                    { text = "Landscape (4:3)", value = "4:3" }, { text = "Ultrawide (21:9)", value = "21:9" },
                },
                default = "1:1",
            })
            table.insert(schema.controls, {
                type = "slider", key = "IconSize", label = "Scale",
                min = 50, max = 200, step = 1,
                formatter = function(v) return v .. "%" end,
                default = Constants.Cooldown.DefaultIconSize,
                onChange = function(val)
                    self:SetSetting(systemIndex, "IconSize", val)
                    self:ApplySettings(systemFrame)
                end,
            })
            table.insert(schema.controls, { type = "slider", key = "IconPadding", label = "Icon Padding", min = 0, max = 15, step = 1, default = Constants.Cooldown.DefaultPadding })
        end
        if not isTracked then
            table.insert(schema.controls, { type = "slider", key = "IconLimit", label = "# Columns", min = 1, max = 20, step = 1, default = Constants.Cooldown.DefaultLimit })
        end
        if isTracked then
            table.insert(schema.controls, { type = "checkbox", key = "ShowActiveDuration", label = "Active Duration", default = true })
        end
    elseif currentTab == "Glow" then
        table.insert(schema.controls, { type = "checkbox", key = "ShowGCDSwipe", label = "Show GCD Swipe", default = true })
        table.insert(schema.controls, {
            type = "checkbox", key = "AssistedHighlight", label = "Assisted Highlight", default = false,
            onChange = function(val)
                self:SetSetting(systemIndex, "AssistedHighlight", val)
                SetCVar("assistedCombatHighlight", val and "1" or "0")
                if self.UpdateAssistedHighlights then self:UpdateAssistedHighlights() end
            end,
        })
        local GlowType = Constants.PandemicGlow.Type
        local GLOW_OPTIONS = {
            { text = "None", value = GlowType.None }, { text = "Pixel Glow", value = GlowType.Pixel },
            { text = "Proc Glow", value = GlowType.Proc }, { text = "Autocast Shine", value = GlowType.Autocast },
            { text = "Button Glow", value = GlowType.Button }, { text = "Blizzard", value = GlowType.Blizzard },
        }
        if not isTracked then
            table.insert(schema.controls, {
                type = "dropdown", key = "PandemicGlowType", label = "Pandemic Glow",
                options = GLOW_OPTIONS, default = Constants.PandemicGlow.DefaultType,
            })
            table.insert(schema.controls, {
                type = "dropdown", key = "ProcGlowType", label = "Proc Glow",
                options = GLOW_OPTIONS, default = Constants.PandemicGlow.DefaultType,
            })
        else
            table.insert(schema.controls, {
                type = "dropdown", key = "ActiveGlowType", label = "Active Glow",
                options = GLOW_OPTIONS, default = GlowType.None,
            })
        end
    elseif currentTab == "Colors" then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "ActiveSwipeColorCurve", label = "Active Swipe",
            default = { pins = { { position = 0, color = { r = 1, g = 0.95, b = 0.57, a = 0.7 } } } },
            singleColor = true,
        })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "CooldownSwipeColorCurve", label = "Cooldown Swipe",
            default = { pins = { { position = 0, color = { r = 0, g = 0, b = 0, a = 0.8 } } } },
            singleColor = true,
        })
        if not isTracked then
            SB:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "PandemicGlowColor", label = "Pandemic Glow Color", default = { r = 1, g = 0.8, b = 0, a = 1 },
            })
            SB:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "ProcGlowColor", label = "Proc Glow Color", default = { r = 1, g = 0.8, b = 0, a = 1 },
            })
        else
            SB:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "ActiveGlowColor", label = "Active Glow Color", default = { r = 0.3, g = 0.8, b = 1, a = 1 },
            })
        end
        if systemIndex ~= Constants.Cooldown.SystemIndex.BuffIcon and systemIndex ~= Constants.Cooldown.SystemIndex.BuffBar then
            SB:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "KeypressColor", label = "Keypress Flash",
                default = { r = 1, g = 1, b = 1, a = 0 },
            })
        end
    elseif currentTab == "Visibility" then
        SB:AddOpacitySettings(self, schema, systemIndex, systemFrame)
        table.insert(schema.controls, {
            type = "checkbox", key = "OutOfCombatFade", label = "Out of Combat Fade", default = false,
            tooltip = "Hide frame when out of combat with no target",
            onChange = function(val)
                self:SetSetting(systemIndex, "OutOfCombatFade", val)
                Orbit.OOCFadeMixin:RefreshAll()
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "MouseoverOnly", label = "Mouseover Only", default = false,
            tooltip = "Only show frame while mousing over it",
            onChange = function(val)
                self:SetSetting(systemIndex, "MouseoverOnly", val)
                local data = VIEWER_MAP[systemIndex]
                if data then
                    local target = data.isTracked and data.anchor or data.viewer
                    if target then
                        Orbit.OOCFadeMixin:ApplyOOCFade(target, self, systemIndex, "OutOfCombatFade", false)
                        Orbit.OOCFadeMixin:RefreshAll()
                    end
                end
            end,
        })
        if systemIndex == Constants.Cooldown.SystemIndex.BuffIcon then
            table.insert(schema.controls, {
                type = "checkbox", key = "AlwaysShow", label = "Always Show", default = false,
                tooltip = "Keep inactive buff icons visible but desaturated",
                onChange = function(val)
                    self:SetSetting(systemIndex, "AlwaysShow", val)
                    self:ApplyAll()
                    if dialog.orbitTabCallback then dialog.orbitTabCallback() end
                end,
            })
            if self:GetSetting(systemIndex, "AlwaysShow") then
                table.insert(schema.controls, {
                    type = "checkbox", key = "HideBorders", label = "Hide Borders", default = false,
                    tooltip = "Hide icon borders when inactive",
                    onChange = function(val) self:SetSetting(systemIndex, "HideBorders", val); self:ApplyAll() end,
                })
                table.insert(schema.controls, {
                    type = "slider", key = "InactiveAlpha", label = "Inactive Alpha", min = 20, max = 100, step = 1, default = 60,
                    onChange = function(val) self:SetSetting(systemIndex, "InactiveAlpha", val); self:ApplyAll() end,
                })
            end
        end
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ COMPONENT UTILITY ]-----------------------------------------------------------------------------
function CDM:IsComponentDisabled(componentKey, systemIndex)
    systemIndex = systemIndex or 1
    local Txn = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.Transaction
    local disabled = (Txn and Txn:IsActive() and Txn:GetPlugin() == self) and Txn:GetDisabledComponents() or self:GetSetting(systemIndex, "DisabledComponents") or {}
    for _, key in ipairs(disabled) do
        if key == componentKey then return true end
    end
    return false
end
