-- [ PLAYER RESOURCE SETTINGS UI ] -------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

local DIVIDER_SIZE_DEFAULT = Orbit.PlayerResourceConstants.DIVIDER_SIZE_DEFAULT
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
    if dialog.Title then dialog.Title:SetText(L.PLU_PRES_TITLE) end
    local schema = { hideNativeSettings = true, controls = {} }
    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_PRES_TAB_LAYOUT, L.PLU_PRES_TAB_BEHAVIOUR, L.PLU_PRES_TAB_COLOUR }, L.PLU_PRES_TAB_LAYOUT)

    if currentTab == L.PLU_PRES_TAB_LAYOUT then
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
        if not isAnchored then
            SB:AddSizeSettings(self, schema, SYSTEM_INDEX, systemFrame, { min = 100, max = 600, default = DEFAULTS.Width }, nil, nil)
        end
        SB:AddSizeSettings(self, schema, SYSTEM_INDEX, systemFrame, nil, { min = 5, max = 40, default = DEFAULTS.Height }, nil)
        table.insert(schema.controls, {
            type = "slider", key = "DividerSize", label = L.PLU_PRES_DIVIDER_SIZE,
            min = 0, max = 4, step = 1, default = DIVIDER_SIZE_DEFAULT,
            tooltip = L.PLU_PRES_DIVIDER_SIZE_TT,
            onChange = function(val)
                self:SetSetting(SYSTEM_INDEX, "DividerSize", val)
                self:ApplySettings()
            end,
        })
        table.insert(schema.controls, {
            type = "slider", key = "TickSize", label = L.PLU_PRES_TICK,
            min = 0, max = TICK_SIZE_MAX, step = 2, default = TICK_SIZE_DEFAULT,
            tooltip = L.PLU_PRES_TICK_TT,
            onChange = function(val)
                self:SetSetting(SYSTEM_INDEX, "TickSize", val)
                self:ApplySettings()
            end,
        })
    elseif currentTab == L.PLU_PRES_TAB_BEHAVIOUR then
        table.insert(schema.controls, {
            type = "checkbox", key = "SmoothAnimation", label = L.PLU_PRES_SMOOTH,
            default = true, tooltip = L.PLU_PRES_SMOOTH_TT,
            onChange = function(val) self:SetSetting(SYSTEM_INDEX, "SmoothAnimation", val) end,
        })
        table.insert(schema.controls, {
            type = "checkbox", key = "FrequentUpdates", label = L.PLU_PRES_FREQ_UPDATE,
            default = false, tooltip = L.PLU_PRES_FREQ_UPDATE_TT,
            onChange = function(val)
                self:SetSetting(SYSTEM_INDEX, "FrequentUpdates", val)
                self:RefreshFrequentUpdates()
            end,
        })
    elseif currentTab == L.PLU_PRES_TAB_COLOUR then
        local discreteLabels = {
            ROGUE = L.PLU_PRES_COMBO_COLOR, DRUID = L.PLU_PRES_COMBO_COLOR,
            PALADIN = L.PLU_PRES_HOLY_POWER_COLOR, WARLOCK = L.PLU_PRES_SOUL_SHARDS_COLOR,
            DEATHKNIGHT = L.PLU_PRES_RUNE_COLOR, EVOKER = L.PLU_PRES_ESSENCE_COLOR,
            MAGE = L.PLU_PRES_ARCANE_CHARGES_COLOR, MONK = L.PLU_PRES_CHI_COLOR,
        }
        local discreteLabel = discreteLabels[PLAYER_CLASS]
        if discreteLabel then
            table.insert(schema.controls, {
                type = "colorcurve", key = "BarColorCurve", label = discreteLabel,
                onChange = function(curveData)
                    self:SetSetting(SYSTEM_INDEX, "BarColorCurve", curveData)
                    self:UpdatePower()
                end,
            })
        end
        if PLAYER_CLASS == "ROGUE" or PLAYER_CLASS == "DRUID" then
            table.insert(schema.controls, {
                type = "color", key = "ChargedComboPointColor", label = L.PLU_PRES_CHARGED_COMBO,
                default = Orbit.Constants.Colors.PlayerResources.ChargedComboPoint or { r = 0.169, g = 0.733, b = 0.992 },
                onChange = function(val)
                    self:SetSetting(SYSTEM_INDEX, "ChargedComboPointColor", val)
                    self:UpdatePower()
                end,
            })
        end
        local curveControls = {
            { classes = { MONK = true }, key = "StaggerColorCurve", label = L.PLU_PRES_STAGGER_COLOR,
              tooltip = L.PLU_PRES_STAGGER_TT,
              default = { pins = { { position = 0, color = { r = 0.52, g = 1.0, b = 0.52, a = 1 } }, { position = 0.5, color = { r = 1.0, g = 0.98, b = 0.72, a = 1 } }, { position = 1, color = { r = 1.0, g = 0.42, b = 0.42, a = 1 } } } } },
            { classes = { DEMONHUNTER = true }, key = "SoulFragmentsColorCurve", label = L.PLU_PRES_SOUL_FRAGMENTS_COLOR,
              tooltip = L.PLU_PRES_GRADIENT_EMPTY_FULL_TT,
              default = { pins = { { position = 0, color = { r = 0.278, g = 0.125, b = 0.796, a = 1 } } } } },
            { classes = { EVOKER = true }, key = "EbonMightColorCurve", label = L.PLU_PRES_EBON_MIGHT_COLOR,
              tooltip = L.PLU_PRES_GRADIENT_EMPTY_FULL_TT,
              default = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.4, a = 1 } } } } },
            { classes = { DRUID = true, PRIEST = true, SHAMAN = true }, key = "ManaColorCurve", label = L.PLU_PRES_MANA_COLOR,
              tooltip = L.PLU_PRES_GRADIENT_EMPTY_FULL_TT,
              default = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } } },
            { classes = { SHAMAN = true }, key = "MaelstromWeaponColorCurve", label = L.PLU_PRES_MAELSTROM_COLOR,
              tooltip = L.PLU_PRES_GRADIENT_EMPTY_FULL_TT,
              default = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } } },
            { classes = { MAGE = true }, key = "IciclesColorCurve", label = L.PLU_PRES_ICICLES_COLOR,
              tooltip = L.PLU_PRES_GRADIENT_EMPTY_FULL_TT,
              default = { pins = { { position = 0, color = { r = 0.42, g = 0.8, b = 1.0, a = 1 } } } } },
            { classes = { HUNTER = true }, key = "TipOfTheSpearColorCurve", label = L.PLU_PRES_TIP_OF_SPEAR_COLOR,
              tooltip = L.PLU_PRES_GRADIENT_EMPTY_FULL_TT,
              default = { pins = { { position = 0, color = { r = 0.47, g = 0.78, b = 0.22, a = 1 } } } } },
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

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
