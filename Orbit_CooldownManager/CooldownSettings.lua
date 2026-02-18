---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap
local CooldownUtils = OrbitEngine.CooldownUtils

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function CDM:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic

    local frame = self:GetFrameBySystemIndex(systemIndex)
    local isAnchored = frame and OrbitEngine.Frame:GetAnchorParent(frame) ~= nil
    local isTracked = frame and frame.isTrackedBar
    local isInheriting = frame and CooldownUtils:IsInheritingLayout(self, frame, VIEWER_MAP)

    local schema = { hideNativeSettings = true, controls = {}, extraButtons = {} }

    -- Charge Bars get their own dedicated dialog
    if frame and frame.isChargeBar then
        WL:SetTabRefreshCallback(dialog, self, systemFrame)
        local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Colors", "Visibility" }, "Layout")

        if currentTab == "Layout" then
            if not isAnchored then
                table.insert(schema.controls, {
                    type = "slider", key = "Width", label = "Width", min = 50, max = 400, step = 1, default = 120,
                    onChange = function(val) self:SetSetting(systemIndex, "Width", val); self:LayoutChargeBars() end,
                })
            end
            table.insert(schema.controls, {
                type = "slider", key = "Height", label = "Height", min = 6, max = 40, step = 1, default = 12,
                onChange = function(val) self:SetSetting(systemIndex, "Height", val); self:LayoutChargeBars() end,
            })
            table.insert(schema.controls, {
                type = "slider", key = "Spacing", label = "Spacing", min = 0, max = 10, step = 1, default = 0,
                onChange = function(val) self:SetSetting(systemIndex, "Spacing", val); self:LayoutChargeBars() end,
            })
        elseif currentTab == "Colors" then
            WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
                key = "BarColorCurve", label = "Bar Color",
                onChange = function(curveData)
                    self:SetSetting(systemIndex, "BarColorCurve", curveData)
                    self:LayoutChargeBars()
                end,
            })
        elseif currentTab == "Visibility" then
            WL:AddOpacitySettings(self, schema, systemIndex, systemFrame)
            table.insert(schema.controls, {
                type = "checkbox", key = "OutOfCombatFade", label = "Out of Combat Fade", default = false,
                tooltip = "Hide frame when out of combat with no target",
                onChange = function(val)
                    self:SetSetting(systemIndex, "OutOfCombatFade", val)
                    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
                    if dialog.orbitTabCallback then dialog.orbitTabCallback() end
                end,
            })
            if self:GetSetting(systemIndex, "OutOfCombatFade") then
                table.insert(schema.controls, {
                    type = "checkbox", key = "ShowOnMouseover", label = "Show on Mouseover", default = true,
                    tooltip = "Reveal frame when mousing over it",
                    onChange = function(val)
                        self:SetSetting(systemIndex, "ShowOnMouseover", val)
                        local data = VIEWER_MAP[systemIndex]
                        if data and data.anchor and Orbit.OOCFadeMixin then
                            Orbit.OOCFadeMixin:ApplyOOCFade(data.anchor, self, systemIndex, "OutOfCombatFade", val)
                            Orbit.OOCFadeMixin:RefreshAll()
                        end
                    end,
                })
            end
        end

        Orbit.Config:Render(dialog, systemFrame, self, schema)
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

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Glow", "Colors", "Visibility" }, "Layout")

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
            table.insert(schema.controls, { type = "slider", key = "IconPadding", label = "Icon Padding", min = -1, max = 10, step = 1, default = Constants.Cooldown.DefaultPadding })
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
            { text = "Button Glow", value = GlowType.Button },
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
        WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "SwipeColorCurve", label = "Swipe Color",
            default = { pins = { { position = 0, color = { r = 0, g = 0, b = 0, a = 0.8 } } } },
            singleColor = true,
        })
        if not isTracked then
            WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "PandemicGlowColor", label = "Pandemic Glow Color", default = { r = 1, g = 0.8, b = 0, a = 1 },
            })
            WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "ProcGlowColor", label = "Proc Glow Color", default = { r = 1, g = 0.8, b = 0, a = 1 },
            })
        else
            WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "ActiveGlowColor", label = "Active Glow Color", default = { r = 0.3, g = 0.8, b = 1, a = 1 },
            })
        end
        if systemIndex ~= Constants.Cooldown.SystemIndex.BuffIcon then
            WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "KeypressColor", label = "Keypress Flash",
                default = { r = 1, g = 1, b = 1, a = 0 },
            })
        end
    elseif currentTab == "Visibility" then
        WL:AddOpacitySettings(self, schema, systemIndex, systemFrame)
        table.insert(schema.controls, {
            type = "checkbox", key = "OutOfCombatFade", label = "Out of Combat Fade", default = false,
            tooltip = "Hide frame when out of combat with no target",
            onChange = function(val)
                self:SetSetting(systemIndex, "OutOfCombatFade", val)
                if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end,
        })
        if self:GetSetting(systemIndex, "OutOfCombatFade") then
            table.insert(schema.controls, {
                type = "checkbox", key = "ShowOnMouseover", label = "Show on Mouseover", default = true,
                tooltip = "Reveal frame when mousing over it",
                onChange = function(val)
                    self:SetSetting(systemIndex, "ShowOnMouseover", val)
                    local data = VIEWER_MAP[systemIndex]
                    if data then
                        local target = data.isTracked and data.anchor or data.viewer
                        if target and Orbit.OOCFadeMixin then
                            Orbit.OOCFadeMixin:ApplyOOCFade(target, self, systemIndex, "OutOfCombatFade", val)
                            Orbit.OOCFadeMixin:RefreshAll()
                        end
                    end
                end,
            })
        end
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

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ COMPONENT UTILITY ]-----------------------------------------------------------------------------
function CDM:IsComponentDisabled(componentKey, systemIndex)
    systemIndex = systemIndex or 1
    local disabled = self:GetSetting(systemIndex, "DisabledComponents") or {}
    for _, key in ipairs(disabled) do
        if key == componentKey then return true end
    end
    return false
end
