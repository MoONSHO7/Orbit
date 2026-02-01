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
local SYSTEM_ID = "Orbit_TargetPower"
local SYSTEM_INDEX = 1

local Plugin = Orbit:RegisterPlugin("Target Power", SYSTEM_ID, {
    canvasMode = true,  -- Enable Canvas Mode for component editing
    defaults = {
        Hidden = false,
        Width = 200,
        Height = 15,
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
        dialog.Title:SetText("Target Power")
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

    -- Note: Show Text is now controlled via Canvas Mode (drag Text to disabled dock)

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create frames ONLY when plugin is enabled (OnLoad is only called for enabled plugins)
    Frame, PowerBar = OrbitEngine.FrameFactory:CreateWithBar("TargetPower", self, {
        width = 200,
        height = 15,
        y = -180, -- Offset slightly differently than player
        systemIndex = SYSTEM_INDEX,
        template = "BackdropTemplate",
        anchorOptions = { horizontal = false, vertical = true, mergeBorders = true }, -- Vertical stacking only, merge borders
    })

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
        
        -- Color
        -- Default to Mana blue for target preview since we don't have a unit
        local info = Orbit.Constants.Colors.PowerType[0] -- Mana
        if info then
            bar:SetStatusBarColor(info.r, info.g, info.b)
        else
            bar:SetStatusBarColor(0, 0.5, 1)
        end
        
        preview.PowerBar = bar
        return preview
    end

    -- Text overlay
    OrbitEngine.FrameFactory:AddText(
        Frame,
        { point = "CENTER", relativePoint = "CENTER", x = 0, y = 2, useOverlay = true }
    )

    -- Alias
    Frame.PowerBar = PowerBar
    self.frame = Frame  -- Expose for PluginMixin compatibility

    self:ApplySettings()

    -- Events
    Frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "target")
    Frame:RegisterUnitEvent("UNIT_MAXPOWER", "target")
    Frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target")
    Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    Frame:SetScript("OnEvent", function(f, event)
        if event == "PLAYER_TARGET_CHANGED" then
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
    -- Read EnableTargetPower setting from TargetFrame plugin
    local targetPlugin = Orbit:GetPlugin("Orbit_TargetFrame")
    local TARGET_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Target
    if targetPlugin and targetPlugin.GetSetting then
        local enabled = targetPlugin:GetSetting(TARGET_FRAME_INDEX, "EnableTargetPower")
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
        -- UnregisterUnitWatch is protected - defer if in combat
        if not InCombatLockdown() then
            UnregisterUnitWatch(Frame)
        end

        -- Use SafeAction just in case we are in combat while toggling Edit Mode (rare but possible)
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
        -- RegisterUnitWatch and SetAttribute are protected - defer if in combat
        if not InCombatLockdown() then
            Frame:SetAttribute("unit", "target")
            RegisterUnitWatch(Frame) -- Handles secure visibility
        end
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
    else
        -- UnregisterUnitWatch is protected - defer if in combat
        if not InCombatLockdown() then
            UnregisterUnitWatch(Frame)
        end
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

        -- Check for Canvas Mode overrides for Font Size
        local textSize = nil
        local positions = self:GetSetting(systemIndex, "ComponentPositions")
        if positions and positions.Text and positions.Text.overrides and positions.Text.overrides.FontSize then
            textSize = positions.Text.overrides.FontSize
        end

        -- Fallback to adaptive size
        if not textSize then
            textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 18, 1)
        end

        local fontPath = LSM:Fetch("font", fontName)
        Frame.Text:SetFont(fontPath, textSize, "OUTLINE")

        Frame.Text:ClearAllPoints()
        Frame.Text:SetPoint("CENTER", Frame.Overlay, "CENTER", 0, 0)
        Frame.Text:SetJustifyH("CENTER")
    end

    -- Restore Position
    OrbitEngine.Frame:RestorePosition(Frame, self, systemIndex)

    -- Restore Component Positions (Canvas Mode)
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

    -- Double check existence just in case, though Visibility handles it mostly
    if not UnitExists("target") then
        return
    end

    local powerType, powerToken = UnitPowerType("target")
    local cur = UnitPower("target", powerType)
    local max = UnitPowerMax("target", powerType)

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
            local percent = SafeUnitPowerPercent("target", powerType)
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
