---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

local Plugin = Orbit:GetPlugin("Orbit_Tracked")
if not Plugin then return end

local function RelayoutTrackedBars(plugin) Orbit.TrackedBarLayout:LayoutTrackedBars(plugin) end

-- [ SETTINGS UI ] -------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or 1
    local SB = OrbitEngine.SchemaBuilder

    local frame = systemFrame.systemFrame or systemFrame
    local isAnchored = frame and OrbitEngine.Frame:GetAnchorParent(frame) ~= nil

    local schema = { hideNativeSettings = true, controls = {}, extraButtons = {} }

    -- [ TRACKED BARS SETTINGS ] ----------------------------------------------------------------
    if frame and (frame.isChargeBar or frame.isTrackedBarFrame) then
        SB:SetTabRefreshCallback(dialog, self, systemFrame)
        local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Behaviour", "Colour" }, "Layout")

        if currentTab == "Layout" then
            if not isAnchored then
                SB:AddSizeSettings(self, schema, systemIndex, systemFrame, { 
                    min = 50, max = 400, default = 120, 
                    onChange = function(val) self:SetSetting(systemIndex, "Width", val); RelayoutTrackedBars(self) end 
                })
            end
            SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, { 
                min = 6, max = 40, default = 12,
                onChange = function(val) self:SetSetting(systemIndex, "Height", val); RelayoutTrackedBars(self) end 
            })
            
            table.insert(schema.controls, {
                type = "slider", key = "TickSize", label = "Tick", min = 0, max = 6, step = 2, default = 6,
                tooltip = "Width of the leading-edge tick mark (0 = hidden)",
                onChange = function(val) self:SetSetting(systemIndex, "TickSize", val); RelayoutTrackedBars(self) end,
            })
            table.insert(schema.controls, {
                type = "slider", key = "DividerSize", label = "Divider Size", min = 0, max = 50, step = 1, default = 2,
                onChange = function(val) self:SetSetting(systemIndex, "DividerSize", val); RelayoutTrackedBars(self) end,
            })
        elseif currentTab == "Colour" then
            SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
                key = "BarColorCurve", label = "Bar Colour",
                onChange = function(curveData)
                    self:SetSetting(systemIndex, "BarColorCurve", curveData)
                    RelayoutTrackedBars(self)
                end,
            })
        elseif currentTab == "Behaviour" then
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

    -- [ TRACKED ICONS SETTINGS ] ---------------------------------------------------------------
    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local tabs = { "Layout", "Glow", "Colors" }
    local currentTab = SB:AddSettingsTabs(schema, dialog, tabs, "Layout")

    if currentTab == "Layout" then
        if isAnchored then
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
        table.insert(schema.controls, { type = "checkbox", key = "ShowActiveDuration", label = "Active Duration", default = true })

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
            type = "dropdown", key = "ActiveGlowType", label = "Active Glow",
            options = GLOW_OPTIONS, default = GlowType.None,
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
            key = "ActiveGlowColor", label = "Active Glow Color", default = { r = 0.3, g = 0.8, b = 1, a = 1 },
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
