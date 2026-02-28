-- [ PLAYER RESOURCE SETTINGS UI ]------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local DIVIDER_SIZE_DEFAULT = 2
local TICK_SIZE_DEFAULT = OrbitEngine.TickMixin.TICK_SIZE_DEFAULT
local TICK_SIZE_MAX = OrbitEngine.TickMixin.TICK_SIZE_MAX
local DEFAULTS = { Width = 200, Height = 12 }
local SYSTEM_INDEX = 1
local _, PLAYER_CLASS = UnitClass("player")

local Plugin = Orbit:GetPlugin("Orbit_PlayerResources")
if not Plugin then return end

function Plugin:AddSettings(dialog, systemFrame)
    if not self.frame then return end
    local Frame = self.frame

    local SB = OrbitEngine.SchemaBuilder
    if dialog.Title then dialog.Title:SetText("Player Resources") end
    local schema = { hideNativeSettings = true, controls = {} }
    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Visibility", "Colour" }, "Layout")

    if currentTab == "Layout" then
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
        if not isAnchored then
            SB:AddSizeSettings(self, schema, SYSTEM_INDEX, systemFrame, { default = DEFAULTS.Width }, nil, nil)
        end
        SB:AddSizeSettings(self, schema, SYSTEM_INDEX, systemFrame, nil, { min = 5, max = 20, default = DEFAULTS.Height }, nil)
        table.insert(schema.controls, {
            type = "slider", key = "DividerSize", label = "Divider Size",
            min = 0, max = 4, step = 1, default = DIVIDER_SIZE_DEFAULT,
            tooltip = "Width of dividers between resource segments",
            onChange = function(val)
                self:SetSetting(SYSTEM_INDEX, "DividerSize", val)
                self:ApplySettings()
            end,
        })
        table.insert(schema.controls, {
            type = "slider", key = "TickSize", label = "Tick",
            min = 0, max = TICK_SIZE_MAX, step = 2, default = TICK_SIZE_DEFAULT,
            tooltip = "Width of the leading-edge tick mark (0 = hidden)",
            onChange = function(val)
                self:SetSetting(SYSTEM_INDEX, "TickSize", val)
                self:ApplySettings()
            end,
        })
    elseif currentTab == "Visibility" then
        SB:AddOpacitySettings(self, schema, SYSTEM_INDEX, systemFrame)
        table.insert(schema.controls, {
            type = "checkbox", key = "OutOfCombatFade", label = "Out of Combat Fade",
            default = false, tooltip = "Hide frame when out of combat with no target",
            onChange = function(val)
                self:SetSetting(SYSTEM_INDEX, "OutOfCombatFade", val)
                Orbit.OOCFadeMixin:RefreshAll()
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end,
        })
        if self:GetSetting(SYSTEM_INDEX, "OutOfCombatFade") then
            table.insert(schema.controls, {
                type = "checkbox", key = "ShowOnMouseover", label = "Show on Mouseover",
                default = true, tooltip = "Reveal frame when mousing over it",
                onChange = function(val)
                    self:SetSetting(SYSTEM_INDEX, "ShowOnMouseover", val)
                    self:ApplySettings()
                end,
            })
        end
        table.insert(schema.controls, {
            type = "checkbox", key = "SmoothAnimation", label = "Smooth Animation",
            default = true, tooltip = "Smoothly animate bar value changes",
            onChange = function(val) self:SetSetting(SYSTEM_INDEX, "SmoothAnimation", val) end,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "FrequentUpdates", label = "Frequent Updates",
            default = false, tooltip = "Update resource bar every frame instead of on server ticks (smoother continuous bars)",
            onChange = function(val)
                self:SetSetting(SYSTEM_INDEX, "FrequentUpdates", val)
                self:RefreshFrequentUpdates()
            end,
        })
    elseif currentTab == "Colour" then
        local discreteLabels = {
            ROGUE = "Combo Points Colour", DRUID = "Combo Points Colour",
            PALADIN = "Holy Power Colour", WARLOCK = "Soul Shards Colour",
            DEATHKNIGHT = "Rune Colour", EVOKER = "Essence Colour",
            MAGE = "Arcane Charges Colour", MONK = "Chi Colour",
        }
        local discreteLabel = discreteLabels[PLAYER_CLASS]
        if discreteLabel then
            table.insert(schema.controls, {
                type = "colorcurve", key = "BarColorCurve", label = discreteLabel,
                onChange = function(curveData)
                    self:SetSetting(SYSTEM_INDEX, "BarColorCurve", curveData)
                    self:ApplyButtonVisuals()
                    self:UpdatePower()
                end,
            })
        end
        if PLAYER_CLASS == "ROGUE" or PLAYER_CLASS == "DRUID" then
            table.insert(schema.controls, {
                type = "color", key = "ChargedComboPointColor", label = "Charged Combo Point",
                default = Orbit.Constants.Colors.PlayerResources.ChargedComboPoint or { r = 0.169, g = 0.733, b = 0.992 },
                onChange = function(val)
                    self:SetSetting(SYSTEM_INDEX, "ChargedComboPointColor", val)
                    self:ApplyButtonVisuals()
                    self:UpdatePower()
                end,
            })
        end
        local curveControls = {
            { classes = { MONK = true }, key = "StaggerColorCurve", label = "Stagger Colour",
              tooltip = "Color gradient from low (left) to heavy (right) stagger",
              default = { pins = { { position = 0, color = { r = 0.52, g = 1.0, b = 0.52, a = 1 } }, { position = 0.5, color = { r = 1.0, g = 0.98, b = 0.72, a = 1 } }, { position = 1, color = { r = 1.0, g = 0.42, b = 0.42, a = 1 } } } } },
            { classes = { DEMONHUNTER = true }, key = "SoulFragmentsColorCurve", label = "Soul Fragments Colour",
              tooltip = "Color gradient from empty (left) to full (right)",
              default = { pins = { { position = 0, color = { r = 0.278, g = 0.125, b = 0.796, a = 1 } } } } },
            { classes = { EVOKER = true }, key = "EbonMightColorCurve", label = "Ebon Might Colour",
              tooltip = "Color gradient from empty (left) to full (right)",
              default = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.4, a = 1 } } } } },
            { classes = { DRUID = true, PRIEST = true, SHAMAN = true }, key = "ManaColorCurve", label = "Mana Colour",
              tooltip = "Color gradient from empty (left) to full (right)",
              default = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } } },
            { classes = { SHAMAN = true }, key = "MaelstromWeaponColorCurve", label = "Maelstrom Colour",
              tooltip = "Color gradient from empty (left) to full (right)",
              default = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } } },
        }
        for _, ctrl in ipairs(curveControls) do
            if ctrl.classes[PLAYER_CLASS] then
                table.insert(schema.controls, {
                    type = "colorcurve", key = ctrl.key, label = ctrl.label,
                    tooltip = ctrl.tooltip, default = ctrl.default,
                    onChange = function(curveData)
                        self:SetSetting(SYSTEM_INDEX, ctrl.key, curveData)
                        self:UpdatePower()
                    end,
                })
            end
        end
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end
