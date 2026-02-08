---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function CDM:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic

    local frame = self:GetFrameBySystemIndex(systemIndex)
    local isAnchored = frame and OrbitEngine.Frame:GetAnchorParent(frame) ~= nil
    local isTracked = frame and frame.isTrackedBar

    local schema = { hideNativeSettings = true, controls = {}, extraButtons = {} }

    -- Charge Bars get their own dedicated dialog
    if frame and frame.isChargeBar then
        WL:SetTabRefreshCallback(dialog, self, systemFrame)
        local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Colour", "Visibility" }, "Layout")

        if currentTab == "Layout" then
            if not isAnchored then
                table.insert(schema.controls, {
                    type = "slider", key = "Width", label = "Width", min = 100, max = 400, step = 1, default = 120,
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
        elseif currentTab == "Colour" then
            WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
                key = "BarColorCurve", label = "Bar Colour",
                onChange = function(curveData)
                    self:SetSetting(systemIndex, "BarColorCurve", curveData)
                    self:LayoutChargeBars()
                end,
            })
        elseif currentTab == "Visibility" then
            WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })
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
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Glow", "Visibility" }, "Layout")

    if currentTab == "Layout" then
        table.insert(schema.controls, {
            type = "dropdown", key = "aspectRatio", label = "Icon Aspect Ratio",
            options = {
                { text = "Square (1:1)", value = "1:1" }, { text = "Landscape (16:9)", value = "16:9" },
                { text = "Landscape (4:3)", value = "4:3" }, { text = "Ultrawide (21:9)", value = "21:9" },
            },
            default = "1:1",
        })
        WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
            key = "IconSize", label = "Scale", default = Constants.Cooldown.DefaultIconSize,
        })
        table.insert(schema.controls, { type = "slider", key = "IconPadding", label = "Icon Padding", min = -1, max = 10, step = 1, default = Constants.Cooldown.DefaultPadding })
        if not isTracked then
            table.insert(schema.controls, { type = "slider", key = "IconLimit", label = "# Columns", min = 1, max = 20, step = 1, default = Constants.Cooldown.DefaultLimit })
        end
    elseif currentTab == "Glow" then
        WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "SwipeColorCurve", label = "Swipe Colour",
            default = { pins = { { position = 0, color = { r = 0, g = 0, b = 0, a = 0.8 } } } },
            singleColor = true,
        })
        table.insert(schema.controls, { type = "checkbox", key = "ShowGCDSwipe", label = "Show GCD Swipe", default = true })
        if not isTracked then
            local GlowType = Constants.PandemicGlow.Type
            table.insert(schema.controls, {
                type = "dropdown", key = "PandemicGlowType", label = "Pandemic Glow",
                options = {
                    { text = "None", value = GlowType.None }, { text = "Pixel Glow", value = GlowType.Pixel },
                    { text = "Proc Glow", value = GlowType.Proc }, { text = "Autocast Shine", value = GlowType.Autocast },
                    { text = "Button Glow", value = GlowType.Button },
                },
                default = Constants.PandemicGlow.DefaultType,
            })
            WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "PandemicGlowColor", label = "Pandemic Glow Colour", default = { r = 1, g = 0.8, b = 0, a = 1 },
            })
            table.insert(schema.controls, {
                type = "dropdown", key = "ProcGlowType", label = "Proc Glow",
                options = {
                    { text = "None", value = GlowType.None }, { text = "Pixel Glow", value = GlowType.Pixel },
                    { text = "Proc Glow", value = GlowType.Proc }, { text = "Autocast Shine", value = GlowType.Autocast },
                    { text = "Button Glow", value = GlowType.Button },
                },
                default = Constants.PandemicGlow.DefaultType,
            })
            WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "ProcGlowColor", label = "Proc Glow Colour", default = { r = 1, g = 0.8, b = 0, a = 1 },
            })
        else
            local GlowType = Constants.PandemicGlow.Type
            table.insert(schema.controls, {
                type = "dropdown", key = "ActiveGlowType", label = "Active Glow",
                options = {
                    { text = "None", value = GlowType.None }, { text = "Pixel Glow", value = GlowType.Pixel },
                    { text = "Proc Glow", value = GlowType.Proc }, { text = "Autocast Shine", value = GlowType.Autocast },
                    { text = "Button Glow", value = GlowType.Button },
                },
                default = GlowType.None,
            })
            WL:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "ActiveGlowColor", label = "Active Glow Colour", default = { r = 0.3, g = 0.8, b = 1, a = 1 },
            })
        end
    elseif currentTab == "Visibility" then
        WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })
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
