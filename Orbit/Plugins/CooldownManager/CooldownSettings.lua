---@type Orbit
local Orbit = Orbit
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
                type = "slider", key = "Height", label = "Height", min = 12, max = 40, step = 1, default = 20,
                onChange = function(val) self:SetSetting(systemIndex, "Height", val); self:ProcessChildren(buffBarAnchor); ResizeCanvasPreview() end,
            })
            if not isDocked then
                table.insert(schema.controls, {
                    type = "slider", key = "Width", label = "Width", min = 80, max = 400, step = 1, default = 200,
                    onChange = function(val) self:SetSetting(systemIndex, "Width", val); self:ProcessChildren(buffBarAnchor); ResizeCanvasPreview() end,
                })
            end
            table.insert(schema.controls, {
                type = "slider", key = "Spacing", label = "Spacing", min = 0, max = 30, step = 1, default = 2,
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

    table.insert(schema.extraButtons, {
        text = "Cooldown Settings",
        callback = function()
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
            if CooldownViewerSettings then CooldownViewerSettings:Show() end
        end,
    })

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local tabs = { "Layout", "Glow", "Colors" }
    if systemIndex == Constants.Cooldown.SystemIndex.BuffIcon then
        tabs = { "Layout", "Glow", "Colors", "Behaviour" }
    end
    local currentTab = SB:AddSettingsTabs(schema, dialog, tabs, "Layout")

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
            table.insert(schema.controls, { type = "slider", key = "IconLimit", label = "# Columns", min = 1, max = 20, step = 1, default = Constants.Cooldown.DefaultLimit })
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
        table.insert(schema.controls, {
            type = "dropdown", key = "PandemicGlowType", label = "Pandemic Glow",
            options = GLOW_OPTIONS, default = Constants.PandemicGlow.DefaultType,
            onChange = function(val) self:SetSetting(systemIndex, "PandemicGlowType", val); self:MarkPandemicDirty() end,
        })
        table.insert(schema.controls, {
            type = "dropdown", key = "ProcGlowType", label = "Proc Glow",
            options = GLOW_OPTIONS, default = Constants.PandemicGlow.DefaultType,
        })
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
        SB:AddColorSettings(self, schema, systemIndex, systemFrame, {
            key = "PandemicGlowColor", label = "Pandemic Glow Color", default = { r = 1, g = 0.8, b = 0, a = 1 },
            onChange = function() self:MarkPandemicDirty() end,
        })
        SB:AddColorSettings(self, schema, systemIndex, systemFrame, {
            key = "ProcGlowColor", label = "Proc Glow Color", default = { r = 1, g = 0.8, b = 0, a = 1 },
        })
        if systemIndex ~= Constants.Cooldown.SystemIndex.BuffIcon and systemIndex ~= Constants.Cooldown.SystemIndex.BuffBar then
            SB:AddColorSettings(self, schema, systemIndex, systemFrame, {
                key = "KeypressColor", label = "Keypress Flash",
                default = { r = 1, g = 1, b = 1, a = 0 },
            })
        end
    elseif currentTab == "Behaviour" then
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

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ COMPONENT UTILITY ] -------------------------------------------------------
function CDM:IsComponentDisabled(componentKey, systemIndex)
    systemIndex = systemIndex or 1
    local Txn = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.Transaction
    local disabled = (Txn and Txn:IsActive() and Txn:GetPlugin() == self) and Txn:GetDisabledComponents() or self:GetSetting(systemIndex, "DisabledComponents") or {}
    for _, key in ipairs(disabled) do
        if key == componentKey then return true end
    end
    return false
end
