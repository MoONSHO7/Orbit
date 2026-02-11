---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- Compatibility for 12.0 / Native Smoothing
local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local FRAME_LEVEL_BOOST = 10

-- [ HELPERS ]----------------------------------------------------------------------------------------
local CanUseUnitPowerPercent = (type(UnitPowerPercent) == "function" and CurveConstants and CurveConstants.ScaleTo100)
local function SafeUnitPowerPercent(unit, resource)
    if not CanUseUnitPowerPercent then
        return nil
    end
    local ok, pct = pcall(UnitPowerPercent, unit, resource, false, CurveConstants.ScaleTo100)
    return (ok and pct) or nil
end

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_TargetPower"
local SYSTEM_INDEX = 1

local Plugin = Orbit:RegisterPlugin("Target Power", SYSTEM_ID, {
    canvasMode = true, -- Enable Canvas Mode for component editing
    defaults = {
        Hidden = false,
        Width = 200,
        Height = 15,
        ShowPercent = false,
        TextSize = 12,
        TextAlignment = "CENTER",
        ComponentPositions = {
            Text = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
        },
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
    local schema = { hideNativeSettings = true, controls = {} }
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
    Frame:SetFrameLevel(Frame:GetFrameLevel() + FRAME_LEVEL_BOOST)

    -- [ CANVAS PREVIEW ] -------------------------------------------------------------------------------
    function Frame:CreateCanvasPreview(options)
        options = options or {}
        local parent = options.parent or UIParent
        local globalSettings = Orbit.db.GlobalSettings or {}
        local borderSize = globalSettings.BorderSize or 1
        local textureName = Plugin:GetSetting(SYSTEM_INDEX, "Texture") or globalSettings.Texture
        local width = self:GetWidth()
        local height = self:GetHeight()

        -- Container
        local preview = CreateFrame("Frame", nil, parent)
        preview:SetSize(width, height)
        preview.sourceFrame = self
        preview.sourceWidth = width
        preview.sourceHeight = height
        preview.previewScale = 1
        preview.components = {}

        -- Background (gradient-aware)
        preview.bg = preview:CreateTexture(nil, "BACKGROUND", nil, Orbit.Constants.Layers and Orbit.Constants.Layers.BackdropDeep or -8)
        preview.bg:SetAllPoints()
        Orbit.Skin:ApplyGradientBackground(preview, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)

        -- Borders (discrete edge textures)
        Orbit.Skin:SkinBorder(preview, preview, borderSize)

        -- Power Bar
        local inset = preview.borderPixelSize or OrbitEngine.Pixel:Snap(borderSize, self:GetEffectiveScale() or 1)
        local bar = CreateFrame("StatusBar", nil, preview)
        bar:SetPoint("TOPLEFT", inset, -inset)
        bar:SetPoint("BOTTOMRIGHT", -inset, inset)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar:SetFrameLevel(preview:GetFrameLevel() + 2)
        Orbit.Skin:SkinStatusBar(bar, textureName, nil, true)

        -- Color (Mana blue default)
        local info = Orbit.Constants.Colors.PowerType[0]
        bar:SetStatusBarColor(info and info.r or 0, info and info.g or 0.5, info and info.b or 1)
        preview.PowerBar = bar

        -- Text component with draggable handle
        local savedPositions = Plugin:GetSetting(SYSTEM_INDEX, "ComponentPositions") or {}
        local textSaved = savedPositions.Text or {}
        local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 18, 1)
        local fontPath = LSM:Fetch("font", Plugin:GetSetting(SYSTEM_INDEX, "Font") or globalSettings.Font) or STANDARD_TEXT_FONT

        local textFrame = CreateFrame("Frame", nil, preview)
        textFrame:SetAllPoints(bar)
        textFrame:SetFrameLevel(bar:GetFrameLevel() + 5)

        local fs = textFrame:CreateFontString(nil, "OVERLAY", nil, 7)
        fs:SetFont(fontPath, textSize, Orbit.Skin:GetFontOutline())
        fs:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
        fs:SetJustifyH("CENTER")
        fs:SetText("100%")

        -- Apply overrides
        if textSaved.overrides and OrbitEngine.OverrideUtils then
            OrbitEngine.OverrideUtils.ApplyOverrides(fs, textSaved.overrides, { fontSize = textSize, fontPath = fontPath })
        end

        -- Font color from curve
        local fontColor = (OrbitEngine.WidgetLogic and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(globalSettings.FontColorCurve)) or { r = 1, g = 1, b = 1, a = 1 }
        fs:SetTextColor(fontColor.r, fontColor.g, fontColor.b, fontColor.a or 1)

        -- Draggable component
        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
        if CreateDraggableComponent then
            local compData = {
                anchorX = textSaved.anchorX or "CENTER", anchorY = textSaved.anchorY or "CENTER",
                offsetX = textSaved.offsetX or 0, offsetY = textSaved.offsetY or 0,
                justifyH = textSaved.justifyH or "CENTER", overrides = textSaved.overrides,
            }
            local comp = CreateDraggableComponent(preview, "Text", fs, textSaved.posX or 0, textSaved.posY or 0, compData)
            if comp then
                comp:SetFrameLevel(textFrame:GetFrameLevel() + 1)
                preview.components["Text"] = comp
                fs:Hide()
            end
        end

        return preview
    end

    -- Text overlay
    OrbitEngine.FrameFactory:AddText(Frame, { point = "CENTER", relativePoint = "CENTER", x = 0, y = 2, useOverlay = true })

    -- Alias
    Frame.PowerBar = PowerBar
    self.frame = Frame -- Expose for PluginMixin compatibility

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
            end,
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
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function()
            self:UpdateVisibility()
        end)
        return
    end
    local enabled = self:IsEnabled()
    local isEditMode = Orbit:IsEditMode()

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
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function()
            self:ApplySettings()
        end)
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
    local fontPath = LSM:Fetch("font", fontName)

    -- Get Canvas Mode overrides
    local positions = self:GetSetting(systemIndex, "ComponentPositions") or {}
    local textPos = positions.Text or {}
    local overrides = textPos.overrides or {}

    if OrbitEngine.ComponentDrag:IsDisabled(Frame.Text) then
        Frame.Text:Hide()
    else
        Frame.Text:Show()

        -- Apply font, size, and color overrides
        local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 18, 1)
        OrbitEngine.OverrideUtils.ApplyOverrides(Frame.Text, overrides, { fontSize = textSize, fontPath = fontPath })

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
    if not Frame or not PowerBar or not Frame:IsShown() then
        return
    end
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
