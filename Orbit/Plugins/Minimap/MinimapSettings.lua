---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Minimap"
local DEFAULT_SIZE = Orbit.MinimapConstants.DEFAULT_SIZE
local MIN_SIZE = Orbit.MinimapConstants.MIN_SIZE
local MAX_SIZE = Orbit.MinimapConstants.MAX_SIZE

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
local Plugin = Orbit:GetPlugin(SYSTEM_ID)

local CLICK_ACTION_OPTIONS = {
    { value = "none", label = L.PLU_MINIMAP_ACT_NONE },
    { value = "worldmap", label = L.PLU_MINIMAP_ACT_MAP },
    { value = "tracking", label = L.PLU_MINIMAP_ACT_TRACK },
    { value = "calendar", label = L.PLU_MINIMAP_ACT_CAL },
    { value = "time", label = L.PLU_MINIMAP_ACT_TIME },
    { value = "addons", label = L.PLU_MINIMAP_ACT_ADDONS },
}

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_MINIMAP_TAB_MINIMAP, L.PLU_MINIMAP_TAB_BEHAVIOUR, L.PLU_MINIMAP_TAB_HUD }, L.PLU_MINIMAP_TAB_MINIMAP, self)

    if currentTab == L.PLU_MINIMAP_TAB_MINIMAP then
        -- Shape
        table.insert(schema.controls, {
            type = "dropdown",
            key = "Shape",
            label = L.PLU_MINIMAP_SHAPE,
            options = {
                { value = "square", label = L.PLU_MINIMAP_SQUARE },
                { value = "round", label = L.PLU_MINIMAP_ROUND },
                { value = "splatter", label = L.PLU_MINIMAP_SPLATTER },
            },
            default = "square",
            onChange = function(val)
                self:SetSetting(SYSTEM_ID, "Shape", val)
                self:ApplySettings()
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end,
        })

        -- Border Ring (round shape only)
        table.insert(schema.controls, {
            type = "dropdown",
            key = "BorderRing",
            label = L.PLU_MINIMAP_BORDER_RING,
            options = {
                { value = "none",        label = L.PLU_MINIMAP_BORDER_RING_NONE },
                { value = "blizzard",    label = L.PLU_MINIMAP_BORDER_RING_BLIZZARD },
                { value = "round",       label = L.PLU_MINIMAP_BORDER_RING_ROUND },
                { value = "fadedcircle", label = L.PLU_MINIMAP_BORDER_RING_FADED_CIRCLE },
                { value = "void",        label = L.PLU_MINIMAP_BORDER_RING_VOID },
            },
            default = "none",
            visibleIf = function() return self:GetSetting(SYSTEM_ID, "Shape") == "round" end,
            onChange = function(val)
                self:SetSetting(SYSTEM_ID, "BorderRing", val)
                self:ApplySettings()
            end,
        })

        -- Size
        table.insert(schema.controls, {
            type = "slider",
            key = "Size",
            label = L.PLU_MINIMAP_SIZE,
            min = MIN_SIZE,
            max = MAX_SIZE,
            step = 1,
            default = DEFAULT_SIZE,
        })

        -- Border Colour
        table.insert(schema.controls, {
            type = "color",
            key = "BorderColor",
            label = L.PLU_MINIMAP_BORDER,
            default = { r = 0, g = 0, b = 0, a = 1 },
            onChange = function(val)
                self:SetSetting(SYSTEM_ID, "BorderColor", val)
                self:ApplySettings()
            end,
        })
    elseif currentTab == L.PLU_MINIMAP_TAB_BEHAVIOUR then
        -- Click Actions
        table.insert(schema.controls, { type = "dropdown", key = "LeftClickAction",   label = L.PLU_MINIMAP_LEFT_CLICK,  options = CLICK_ACTION_OPTIONS, default = "none" })
        table.insert(schema.controls, { type = "dropdown", key = "MiddleClickAction", label = L.PLU_MINIMAP_MID_CLICK,   options = CLICK_ACTION_OPTIONS, default = "none" })
        table.insert(schema.controls, { type = "dropdown", key = "RightClickAction",  label = L.PLU_MINIMAP_RIGHT_CLICK, options = CLICK_ACTION_OPTIONS, default = "tracking" })

        -- Rotate Minimap
        table.insert(schema.controls, {
            type = "checkbox",
            key = "RotateMinimap",
            label = L.PLU_MINIMAP_ROTATE,
            default = false,
            visibleIf = function()
                local shape = self:GetSetting(SYSTEM_ID, "Shape")
                return shape == "round" or shape == "splatter"
            end,
            onChange = function(val)
                self:SetSetting(SYSTEM_ID, "RotateMinimap", val)
                self:ApplySettings()
            end,
        })

        -- Auto Zoom-out
        table.insert(schema.controls, {
            type = "checkbox",
            key = "AutoZoomOut",
            label = L.PLU_MINIMAP_AUTO_ZOOM,
            tooltip = L.PLU_MINIMAP_AUTO_ZOOM_TT,
            default = true,
        })
    elseif currentTab == L.PLU_MINIMAP_TAB_HUD then
        -- HUD Size (used when View = "hud", toggled via the bindable hotkey)
        table.insert(schema.controls, {
            type = "slider",
            key = "Hud_Size",
            label = L.PLU_MINIMAP_HUD_SIZE,
            min = 600,
            max = 1000,
            step = 10,
            default = 800,
            onChange = function(val)
                self:SetSetting(SYSTEM_ID, "Hud_Size", val)
                if (self:GetSetting(SYSTEM_ID, "View") or "minimap") == "hud" then self:ApplySettings() end
            end,
        })

        -- HUD Opacity (0-100, applied as frame alpha 0-1 in HUD view)
        table.insert(schema.controls, {
            type = "slider",
            key = "Hud_Opacity",
            label = L.PLU_MINIMAP_HUD_OPACITY,
            min = 0,
            max = 100,
            step = 5,
            default = 30,
            onChange = function(val)
                self:SetSetting(SYSTEM_ID, "Hud_Opacity", val)
                if (self:GetSetting(SYSTEM_ID, "View") or "minimap") == "hud" then self:ApplySettings() end
            end,
        })

        -- Rotate HUD (drives the rotateMinimap CVar while HUD view is active)
        table.insert(schema.controls, {
            type = "checkbox",
            key = "Hud_Rotate",
            label = L.PLU_MINIMAP_HUD_ROTATE,
            default = false,
            onChange = function(val)
                self:SetSetting(SYSTEM_ID, "Hud_Rotate", val)
                if (self:GetSetting(SYSTEM_ID, "View") or "minimap") == "hud" then self:ApplySettings() end
            end,
        })

        -- Footer: HUD Keybind button — opens Blizzard's keybinds panel scrolled to the Orbit section.
        schema.extraButtons = {
            {
                text = L.PLU_MINIMAP_HUD_KEYBIND,
                callback = function()
                    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
                        securecall("HideUIPanel", EditModeManagerFrame)
                    end
                    if Orbit.SettingsDialog then Orbit.SettingsDialog:Hide() end
                    C_Timer.After(0.1, function()
                        if Settings and Settings.KEYBINDINGS_CATEGORY_ID then
                            Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, BINDING_HEADER_ORBIT)
                        end
                    end)
                end,
            },
        }
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
