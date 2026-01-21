local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- Compatibility for 12.0 / Native Smoothing
local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function SafeUnitPowerPercent(unit, resource)
    if type(UnitPowerPercent) == "function" then
        local ok, pct
        if CurveConstants and CurveConstants.ScaleTo100 then
            ok, pct = pcall(UnitPowerPercent, unit, resource, false, CurveConstants.ScaleTo100)
        else
            ok, pct = pcall(UnitPowerPercent, unit, resource, false, true)
        end

        if not ok or pct == nil then
            ok, pct = pcall(UnitPowerPercent, unit, resource, false)
        end

        if ok and pct ~= nil then
            return pct
        end
    end

    if UnitPower and UnitPowerMax then
        local cur = UnitPower(unit, resource)
        local max = UnitPowerMax(unit, resource)
        if cur and max and max > 0 then
            return (cur / max) * 100
        end
    end
    return nil
end

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_FocusPower"
local SYSTEM_INDEX = 1 -- Independent plugin

local Plugin = Orbit:RegisterPlugin("Focus Power", SYSTEM_ID, {
    defaults = {
        Hidden = false,
        Width = 200,
        Height = 15,
        ShowText = false,
        ShowPercent = false,
        TextSize = 12,
        TextAlignment = "CENTER",
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

-- Frame references (created in OnLoad)
local Frame, PowerBar

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    if not Frame then
        return
    end

    local systemIndex = SYSTEM_INDEX
    local WL = OrbitEngine.WidgetLogic

    if dialog.Title then
        dialog.Title:SetText("Focus Power")
    end

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil

    -- Width (only when not anchored)
    if not isAnchored then
        WL:AddSizeSettings(self, schema, systemIndex, systemFrame, { default = 200 }, nil, nil)
    end

    -- Height
    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, { min = 5, max = 50, default = 15 }, nil)

    -- Show Text (Manual add to omit Size slider)
    table.insert(schema.controls, {
        type = "checkbox",
        key = "ShowText",
        label = "Show Text",
        default = false,
        onChange = function(val)
            self:SetSetting(systemIndex, "ShowText", val)
            self:ApplySettings()
            -- Re-render to show/hide alignment dropdown
            OrbitEngine.Layout:Reset(dialog)
            self:AddSettings(dialog, systemFrame)
        end,
    })

    -- Text Alignment (only shown when ShowText is enabled)
    local showText = self:GetSetting(systemIndex, "ShowText")
    if showText then
        table.insert(schema.controls, {
            type = "dropdown",
            key = "TextAlignment",
            label = "Text Position",
            options = {
                { text = "Left", value = "LEFT" },
                { text = "Center", value = "CENTER" },
                { text = "Right", value = "RIGHT" },
            },
            default = "CENTER",
            onChange = function(val)
                self:SetSetting(systemIndex, "TextAlignment", val)
                self:ApplySettings()
            end,
        })
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create frames ONLY when plugin is enabled (OnLoad is only called for enabled plugins)
    Frame, PowerBar = OrbitEngine.FrameFactory:CreateWithBar("FocusPower", self, {
        width = 200,
        height = 15,
        y = -200, -- Offset slightly differently
        systemIndex = SYSTEM_INDEX,
        template = "BackdropTemplate",
        anchorOptions = { horizontal = false, vertical = true, mergeBorders = true }, -- Vertical stacking only, merge borders
    })

    -- Text overlay
    OrbitEngine.FrameFactory:AddText(
        Frame,
        { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = -2, useOverlay = true }
    )

    -- Alias
    Frame.PowerBar = PowerBar

    self:ApplySettings()

    -- Events
    Frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "focus")
    Frame:RegisterUnitEvent("UNIT_MAXPOWER", "focus")
    Frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "focus")
    Frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    Frame:SetScript("OnEvent", function(f, event)
        if event == "PLAYER_FOCUS_CHANGED" then
            -- Visibility handled by UnitWatch
            self:UpdateAll()
        else
            self:UpdateAll()
        end
    end)

    Frame:SetScript("OnShow", function()
        self:UpdateAll()
    end)

    -- Edit Mode
    if OrbitEngine.EditMode then
        OrbitEngine.EditMode:RegisterEnterCallback(function()
            self:UpdateVisibility()
        end, self)

        OrbitEngine.EditMode:RegisterExitCallback(function()
            self:ApplySettings()
        end, self)
    end

    self:UpdateVisibility()
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Plugin:IsEnabled()
    -- Read EnableFocusPower setting from FocusFrame plugin
    local focusPlugin = Orbit:GetPlugin("Orbit_FocusFrame")
    local FOCUS_FRAME_INDEX = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Focus) or 3
    if focusPlugin and focusPlugin.GetSetting then
        local enabled = focusPlugin:GetSetting(FOCUS_FRAME_INDEX, "EnableFocusPower")
        return enabled == true
    end
    return false
end

function Plugin:UpdateVisibility()
    if not Frame then
        return
    end

    local enabled = self:IsEnabled()
    local isEditMode = EditModeManagerFrame
        and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive()

    if isEditMode then
        UnregisterUnitWatch(Frame)

        -- Use SafeAction
        Orbit:SafeAction(function()
            if enabled then
                Frame:Show()
                Frame:SetAlpha(1)
            else
                Frame:Hide()
            end
        end)
        return
    end

    -- Normal Play
    if enabled then
        Frame:SetAttribute("unit", "focus")
        RegisterUnitWatch(Frame) -- Handles secure visibility
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
    else
        UnregisterUnitWatch(Frame)
        Orbit:SafeAction(function()
            Frame:Hide()
        end)
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    if not Frame then
        return
    end

    local systemIndex = SYSTEM_INDEX

    -- Settings
    local width = self:GetSetting(systemIndex, "Width")
    local height = self:GetSetting(systemIndex, "Height")
    local borderSize = self:GetSetting(systemIndex, "BorderSize")
    local textureName = self:GetSetting(systemIndex, "Texture")
    local showText = self:GetSetting(systemIndex, "ShowText")
    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 18, 1)
    local fontName = self:GetSetting(systemIndex, "Font")

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil

    -- Size
    Frame:SetHeight(height)
    if not isAnchored then
        Frame:SetWidth(width)
    end

    -- Texture
    -- Texture
    Orbit.Skin:SkinStatusBar(PowerBar, textureName)

    -- Border
    Frame:SetBorder(borderSize)

    -- Backdrop Color
    local backdropColor = self:GetSetting(systemIndex, "BackdropColour")
    if backdropColor and Frame.bg then
        Frame.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a or 0.9)
    elseif Frame.bg then
        local c = Orbit.Constants.Colors.Background
        Frame.bg:SetColorTexture(c.r, c.g, c.b, c.a or 0.9)
    end

    -- Text
    if showText then
        Frame.Text:Show()
        local fontPath = LSM:Fetch("font", fontName)
        Frame.Text:SetFont(fontPath, textSize, "OUTLINE")

        local alignment = self:GetSetting(systemIndex, "TextAlignment") or "CENTER"
        local padding = Orbit.Constants.UnitFrame.TextPadding

        Frame.Text:ClearAllPoints()
        if alignment == "LEFT" then
            Frame.Text:SetPoint("LEFT", Frame.Overlay, "LEFT", padding, 0)
            Frame.Text:SetJustifyH("LEFT")
        elseif alignment == "RIGHT" then
            Frame.Text:SetPoint("RIGHT", Frame.Overlay, "RIGHT", -padding, 0)
            Frame.Text:SetJustifyH("RIGHT")
        else
            -- Center (default)
            Frame.Text:SetPoint("CENTER", Frame.Overlay, "CENTER", 0, 0)
            Frame.Text:SetJustifyH("CENTER")
        end
    else
        Frame.Text:Hide()
    end

    -- Restore Position
    OrbitEngine.Frame:RestorePosition(Frame, self, systemIndex)

    if OrbitEngine.Frame.ForceUpdateSelection then
        OrbitEngine.Frame:ForceUpdateSelection(Frame)
    end

    self:UpdateVisibility()
end

-- [ POWER UPDATE ]----------------------------------------------------------------------------------
function Plugin:UpdateAll()
    if not Frame or not PowerBar then
        return
    end
    if not Frame:IsShown() then
        return
    end

    if not UnitExists("focus") then
        return
    end

    local powerType, powerToken = UnitPowerType("focus")
    local cur = UnitPower("focus", powerType)
    local max = UnitPowerMax("focus", powerType)

    PowerBar:SetMinMaxValues(0, max)
    PowerBar:SetValue(cur, SMOOTH_ANIM)

    -- Color
    -- Use Orbit's centralized colors instead of Blizzard's global PowerBarColor
    local info = Orbit.Constants.Colors.PowerType[powerType]
    if info then
        PowerBar:SetStatusBarColor(info.r, info.g, info.b)
    else
        PowerBar:SetStatusBarColor(0.5, 0.5, 0.5)
    end

    -- Text
    if Frame.Text:IsShown() then
        if powerToken == "MANA" then
            local percent = SafeUnitPowerPercent("focus", powerType)
            if percent then
                Frame.Text:SetFormattedText("%.0f", percent)
            else
                Frame.Text:SetText(cur)
            end
        else
            Frame.Text:SetText(cur)
        end
    end
end
