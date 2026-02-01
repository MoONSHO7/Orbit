---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- Compatibility for 12.0 / Native Smoothing
local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function SafeUnitPowerPercent(unit, resource)
    if type(UnitPowerPercent) ~= "function" then
        return nil
    end
    if not CurveConstants or not CurveConstants.ScaleTo100 then
        return nil
    end
    local ok, pct = pcall(UnitPowerPercent, unit, resource, false, CurveConstants.ScaleTo100)
    if ok and pct ~= nil then
        return pct
    end
    return nil
end

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerPower"
local SYSTEM_INDEX = 1

local Plugin = Orbit:RegisterPlugin("Player Power", SYSTEM_ID, {
    canvasMode = true,
    defaults = {
        Enabled = true, -- Self-contained toggle when Orbit_UnitFrames not loaded
        Hidden = false,
        Width = 200,
        Height = 15,
        UseCustomColor = false,
        BarColor = { r = 1, g = 1, b = 1, a = 1 },
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
        dialog.Title:SetText("Player Power")
    end

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- Enable toggle (shown if Orbit_UnitFrames not loaded)
    local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
    if not playerPlugin then
        table.insert(schema.controls, {
            type = "checkbox",
            key = "Enabled",
            label = "Enable",
            default = true,
            onChange = function(val)
                self:SetSetting(systemIndex, "Enabled", val)
                self:UpdateVisibility()
            end,
        })
    end

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil

    -- Width (only when not anchored)
    if not isAnchored then
        WL:AddSizeSettings(self, schema, systemIndex, systemFrame, { default = 200 }, nil, nil)
    end

    -- Height
    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, { min = 5, max = 50, default = 15 }, nil)

    -- Custom Color Toggle
    table.insert(schema.controls, {
        type = "checkbox",
        key = "UseCustomColor",
        label = "Use Custom Color",
        default = false,
        onChange = function(val)
            self:SetSetting(systemIndex, "UseCustomColor", val)
            self:UpdateAll()
        end,
    })

    -- Bar Color Picker
    table.insert(schema.controls, {
        type = "color",
        key = "BarColor",
        label = "Bar Color",
        default = { r = 1, g = 1, b = 1, a = 1 },
        onChange = function(color)
            self:SetSetting(systemIndex, "BarColor", color)
            self:UpdateAll()
        end,
    })

    -- Note: Show Text is now controlled via Canvas Mode (drag Text to disabled dock)

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create frames ONLY when plugin is enabled (OnLoad is only called for enabled plugins)
    Frame, PowerBar = OrbitEngine.FrameFactory:CreateWithBar("PlayerPower", self, {
        width = 200,
        height = 15,
        y = -160,
        systemIndex = SYSTEM_INDEX,
        template = "BackdropTemplate",
        anchorOptions = { horizontal = false, vertical = true, mergeBorders = true }, -- Vertical stacking only, merge borders
    })
    self.frame = Frame  -- Expose for PluginMixin compatibility

    -- [ CANVAS PREVIEW ] -------------------------------------------------------------------------------
    function Frame:CreateCanvasPreview(options)
        local scale = options.scale or 1
        local borderSize = options.borderSize or 1
        
        -- Base container
        local preview = OrbitEngine.Preview.Frame:CreateBasePreview(self, scale, options.parent, borderSize)
        
        -- Create Power Bar visual
        local bar = CreateFrame("StatusBar", nil, preview)
        local inset = borderSize * scale
        bar:SetPoint("TOPLEFT", preview, "TOPLEFT", inset, -inset)
        bar:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -inset, inset)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        
        -- Appearance
        local textureName = Plugin:GetSetting(SYSTEM_INDEX, "Texture")
        local texturePath = "Interface\\Buttons\\WHITE8x8"
        if textureName and LSM then
            texturePath = LSM:Fetch("statusbar", textureName) or texturePath
        end
        bar:SetStatusBarTexture(texturePath)
        
        -- Color (use player class color or power color default)
        local powerType = UnitPowerType("player")
        local info = Orbit.Constants.Colors.PowerType[powerType]
        if info then
            bar:SetStatusBarColor(info.r, info.g, info.b)
        else
            bar:SetStatusBarColor(0.5, 0.5, 0.5)
        end
        
        preview.PowerBar = bar
        return preview
    end

    -- Text overlay
    OrbitEngine.FrameFactory:AddText(
        Frame,
        { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = -2, useOverlay = true }
    )

    -- Alias
    Frame.PowerBar = PowerBar

    self:ApplySettings()

    -- Events
    Frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    Frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    Frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    Frame:SetScript("OnEvent", function(f, event)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UpdateVisibility()
        else
            self:UpdateAll()
        end
    end)

    -- Edit Mode
    if OrbitEngine.EditMode then
        OrbitEngine.EditMode:RegisterCallbacks({
            Enter = function()
                self:UpdateVisibility()
            end,
            Exit = function()
                self:UpdateVisibility()
            end,
        }, self)
    end

    -- Canvas Mode: Register draggable components
    if OrbitEngine.ComponentDrag and Frame.Text then
        OrbitEngine.ComponentDrag:Attach(Frame.Text, Frame, {
            key = "Text",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = self:GetSetting(SYSTEM_INDEX, "ComponentPositions") or {}
                positions.Text = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                self:SetSetting(SYSTEM_INDEX, "ComponentPositions", positions)
            end
        })
    end

    self:UpdateVisibility()
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Plugin:IsEnabled()
    -- First check our own Enabled setting
    local localEnabled = self:GetSetting(SYSTEM_INDEX, "Enabled")
    if localEnabled == false then
        return false
    end

    -- If Orbit_UnitFrames is loaded, also respect its EnablePlayerPower setting
    local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
    local PLAYER_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Player
    if playerPlugin and playerPlugin.GetSetting then
        local enabled = playerPlugin:GetSetting(PLAYER_FRAME_INDEX, "EnablePlayerPower")
        -- Default to true if not set
        if enabled ~= nil then
            return enabled == true
        end
    end
    return true
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
        -- Always show in Edit Mode for positioning, but dim if disabled
        Frame:Show()
        if enabled then
            Frame:SetAlpha(1)
        else
            Frame:SetAlpha(0.5) -- Dimmed to indicate disabled
        end
        return
    end

    if enabled then
        Frame:Show()
        self:UpdateAll()
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
    else
        Frame:Hide()
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    if not Frame then
        return
    end

    local systemIndex = SYSTEM_INDEX

    -- Get settings (defaults handled by PluginMixin)
    local width = self:GetSetting(systemIndex, "Width")
    local height = self:GetSetting(systemIndex, "Height")
    local borderSize = self:GetSetting(systemIndex, "BorderSize")
    local textureName = self:GetSetting(systemIndex, "Texture")
    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)
    local fontName = self:GetSetting(systemIndex, "Font")

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil

    -- Size
    Frame:SetHeight(height)
    if not isAnchored then
        Frame:SetWidth(width)
    end

    -- Texture
    Orbit.Skin:SkinStatusBar(PowerBar, textureName, nil, true)

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

    -- Text (controlled via Canvas Mode)
    if OrbitEngine.ComponentDrag:IsDisabled(Frame.Text) then
        Frame.Text:Hide()
    else
        Frame.Text:Show()
        
        -- Get Canvas Mode overrides
        local positions = self:GetSetting(systemIndex, "ComponentPositions") or {}
        local textPos = positions.Text or {}
        local overrides = textPos.overrides or {}
        
        -- Apply font override
        local fontPath = LSM:Fetch("font", fontName)
        if overrides.Font and LSM then
            fontPath = LSM:Fetch("font", overrides.Font) or fontPath
        end
        
        -- Apply size override
        local finalSize = overrides.FontSize or textSize
        
        -- Apply font flags override
        local flags = "OUTLINE"
        if overrides.ShowShadow then
            flags = ""
        end
        
        Frame.Text:SetFont(fontPath, finalSize, flags)
        
        -- Apply shadow if needed
        if overrides.ShowShadow then
            Frame.Text:SetShadowOffset(1, -1)
            Frame.Text:SetShadowColor(0, 0, 0, 1)
        else
            Frame.Text:SetShadowOffset(0, 0)
        end
        
        -- Apply color override
        if overrides.CustomColor and overrides.CustomColorValue and type(overrides.CustomColorValue) == "table" then
            local c = overrides.CustomColorValue
            Frame.Text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
        end

        Frame.Text:ClearAllPoints()
        if height > (finalSize + 2) then
            Frame.Text:SetPoint("CENTER", Frame.Overlay, "CENTER", 0, 0)
        else
            Frame.Text:SetPoint("BOTTOM", Frame.Overlay, "BOTTOM", 0, -2)
        end
        Frame.Text:SetJustifyH("CENTER")
    end

    -- Restore Position
    OrbitEngine.Frame:RestorePosition(Frame, self, systemIndex)

    -- Restore component positions (Canvas Mode)
    local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
    if savedPositions and OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:RestoreFramePositions(Frame, savedPositions)
    end

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

    -- Check for Augmentation Evoker Ebon Might (takes priority over normal power)
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    if class == "EVOKER" and specID == 1473 then
        local current, max = Orbit.ResourceBarMixin:GetEbonMightState()
        if current and max and max > 0 then
            PowerBar:SetMinMaxValues(0, max)
            PowerBar:SetValue(current, SMOOTH_ANIM)
            
            -- Use Ebon Might color
            local color = Orbit.Colors.PlayerResources and Orbit.Colors.PlayerResources.EbonMight
            if color then
                PowerBar:SetStatusBarColor(color.r, color.g, color.b)
            else
                PowerBar:SetStatusBarColor(0.4, 0.6, 0.3) -- Fallback green
            end
            
            if Frame.Text:IsShown() then
                Frame.Text:SetFormattedText("%.0f", current)
            end
            return
        end
        -- If Ebon Might not active, fall through to show Mana
    end

    local powerType, powerToken = UnitPowerType("player")
    local cur = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)

    PowerBar:SetMinMaxValues(0, max)
    PowerBar:SetValue(cur, SMOOTH_ANIM)

    -- Color
    local useCustomColor = self:GetSetting(SYSTEM_INDEX, "UseCustomColor")
    local customColor = self:GetSetting(SYSTEM_INDEX, "BarColor")
    
    if useCustomColor and customColor then
        PowerBar:SetStatusBarColor(customColor.r, customColor.g, customColor.b)
    else
        -- Use Orbit's centralized colors instead of Blizzard's global PowerBarColor
        local info = Orbit.Constants.Colors.PowerType[powerType]
        if info then
            PowerBar:SetStatusBarColor(info.r, info.g, info.b)
        else
            PowerBar:SetStatusBarColor(0.5, 0.5, 0.5)
        end
    end

    -- Text
    if Frame.Text:IsShown() then
        if powerToken == "MANA" then
            local percent = SafeUnitPowerPercent("player", powerType)
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
