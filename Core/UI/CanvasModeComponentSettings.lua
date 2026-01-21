-- [ CANVAS MODE COMPONENT SETTINGS ]------------------------------------------------------------
-- Popout settings dialog for customizing component appearance in Canvas Mode
-- Similar to FontPicker pattern: FULLSCREEN_DIALOG strata, click-outside-to-close
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local DIALOG_WIDTH = 300  -- Compact width
local DIALOG_MIN_HEIGHT = 120
local WIDGET_HEIGHT = 28
local WIDGET_SPACING = 4
local PADDING = 20  -- More padding on left/right

-- [ COMPONENT TYPE SCHEMAS ]-------------------------------------------------------------------------

-- Define settings based on component family/type, not individual names

-- Family-based schemas (auto-detected from visual element type)
local TYPE_SCHEMAS = {
    -- FontString elements (Name, HealthText, LevelText, etc.)
    FontString = {
        controls = {
            { type = "font", key = "Font", label = "Font" },
            { type = "slider", key = "FontSize", label = "Size", min = 8, max = 24, step = 1 },
            { type = "checkbox", key = "ShowShadow", label = "Shadow" },
        },
    },
    -- Texture/Icon elements (CombatIcon, RareEliteIcon, etc.)
    Texture = {
        controls = {
            { type = "slider", key = "Scale", label = "Scale", min = 0.5, max = 2.0, step = 0.1 },
        },
    },
}

-- Display names for components (just for the title)
local COMPONENT_TITLES = {
    Name = "Name Text",
    HealthText = "Health Text",
    LevelText = "Level Text",
    CombatIcon = "Combat Icon",
    RareEliteIcon = "Classification Icon",
    RestingIcon = "Resting Icon",
}

-- Detect component family from visual element
local function GetComponentFamily(container)
    if not container or not container.visual then return nil end
    local visual = container.visual
    local objType = visual.GetObjectType and visual:GetObjectType()
    
    if objType == "FontString" then
        return "FontString"
    elseif objType == "Texture" then
        return "Texture"
    end
    
    return nil
end

-- [ CREATE DIALOG FRAME ]---------------------------------------------------------------------------

local Dialog = CreateFrame("Frame", "OrbitCanvasComponentSettings", UIParent)
Dialog:SetSize(DIALOG_WIDTH, DIALOG_MIN_HEIGHT)
Dialog:SetFrameStrata("FULLSCREEN_DIALOG")
Dialog:SetFrameLevel(500)  -- Above Canvas Mode dialog
Dialog:SetClampedToScreen(true)
Dialog:EnableMouse(true)
Dialog:Hide()

-- Border using Blizzard's high-quality template
Dialog.Border = CreateFrame("Frame", nil, Dialog, "DialogBorderTranslucentTemplate")
Dialog.Border:SetAllPoints(Dialog)
Dialog.Border:SetFrameLevel(Dialog:GetFrameLevel())

-- Title
Dialog.Title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
Dialog.Title:SetPoint("TOP", Dialog, "TOP", 0, -PADDING)

-- Content container for widgets
Dialog.Content = CreateFrame("Frame", nil, Dialog)
Dialog.Content:SetPoint("TOPLEFT", Dialog, "TOPLEFT", PADDING, -PADDING - 24)
Dialog.Content:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -PADDING, PADDING)

-- Widget pool
Dialog.widgets = {}

-- [ CLOSE BEHAVIOR ]-------------------------------------------------------------------------------

-- ESC key
Dialog:SetPropagateKeyboardInput(true)
Dialog:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        self:SetPropagateKeyboardInput(false)
        self:Hide()
        C_Timer.After(0.05, function()
            if not InCombatLockdown() then
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end
end)

-- Click outside to close (via OnUpdate check)
Dialog:SetScript("OnUpdate", function(self)
    if not self:IsMouseOver() and IsMouseButtonDown("LeftButton") then
        -- Check if clicking on the parent Canvas Mode dialog
        local canvasDialog = Orbit.CanvasModeDialog
        if canvasDialog and canvasDialog:IsMouseOver() then
            -- Clicked on canvas dialog, close this popout
            self:Hide()
        end
    end
end)

Dialog:SetScript("OnHide", function(self)
    -- Clear references
    self.componentKey = nil
    self.container = nil
    self.plugin = nil
    self.systemIndex = nil
    self.currentOverrides = nil
    
    -- Hide all widgets
    for _, widget in ipairs(self.widgets) do
        widget:Hide()
    end
end)

-- [ WIDGET CREATION HELPERS ]-----------------------------------------------------------------------

local function CreateSliderWidget(parent, control, currentValue, callback)
    if not Layout or not Layout.CreateSlider then
        return nil
    end
    
    local widget = Layout:CreateSlider(
        parent,
        control.label,
        control.min,
        control.max,
        control.step or 1,
        nil,  -- formatter (use default)
        currentValue or control.min,
        function(value)
            if callback then callback(control.key, value) end
        end
    )
    
    if widget then
        widget:SetHeight(32)
    end
    
    return widget
end

local function CreateCheckboxWidget(parent, control, currentValue, callback)
    if not Layout or not Layout.CreateCheckbox then
        return nil
    end
    
    local widget = Layout:CreateCheckbox(
        parent,
        control.label,
        nil,  -- tooltip
        currentValue or false,
        function(checked)
            if callback then callback(control.key, checked) end
        end
    )
    
    if widget then
        widget:SetHeight(30)
    end
    
    return widget
end

local function CreateFontPickerWidget(parent, control, currentValue, callback)
    if Layout and Layout.CreateFontPicker then
        local widget = Layout:CreateFontPicker(
            parent,
            control.label,
            currentValue,
            function(fontName)
                if callback then callback(control.key, fontName) end
            end
        )
        if widget then
            widget:SetHeight(32)
        end
        return widget
    end
    
    -- Fallback: simple label if FontPicker not available
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(WIDGET_HEIGHT)
    frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Label:SetText(control.label .. ": " .. (currentValue or "Default"))
    return frame
end

-- [ OPEN DIALOG ]-----------------------------------------------------------------------------------

function Dialog:Open(componentKey, container, plugin, systemIndex)
    if InCombatLockdown() then return end
    
    -- Store references
    self.componentKey = componentKey
    self.container = container
    self.plugin = plugin
    self.systemIndex = systemIndex or 1
    
    -- Auto-detect component family from visual element
    local family = GetComponentFamily(container)
    local schema = family and TYPE_SCHEMAS[family]
    
    if not schema then
        -- Unknown component type, show generic message
        local title = COMPONENT_TITLES[componentKey] or componentKey
        self.Title:SetText(title .. " (no settings)")
        self:SetHeight(80)
        
        -- Position to the LEFT of the Canvas Mode dialog
        self:ClearAllPoints()
        local canvasDialog = Orbit.CanvasModeDialog
        if canvasDialog and canvasDialog:IsShown() then
            self:SetPoint("TOPRIGHT", canvasDialog, "TOPLEFT", -10, 0)
        else
            self:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
        end
        
        self:Show()
        return
    end
    
    -- Set title from component name lookup or use key
    local title = COMPONENT_TITLES[componentKey] or componentKey
    self.Title:SetText(title)
    
    -- Get current overrides: first check container's in-memory state, then fall back to saved
    if container.pendingOverrides then
        -- Overrides set during this session (not yet saved)
        self.currentOverrides = container.pendingOverrides
    elseif container.existingOverrides then
        -- Overrides loaded from saved data when container was created
        self.currentOverrides = container.existingOverrides
    else
        -- Fall back to plugin saved data
        local savedPositions = plugin and plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        local posData = savedPositions[componentKey] or {}
        self.currentOverrides = posData.overrides or {}
    end
    
    -- Hide all existing widgets
    for _, widget in ipairs(self.widgets) do
        widget:Hide()
    end
    
    -- Create widgets for each control
    local yOffset = 0
    local widgetIndex = 0
    
    for _, control in ipairs(schema.controls) do
        widgetIndex = widgetIndex + 1
        local widget = nil
        
        local currentValue = self.currentOverrides[control.key]
        
        -- Get default value from plugin defaults if no override
        if currentValue == nil and plugin and plugin.defaults then
            local compDefaults = plugin.defaults.ComponentSettings and plugin.defaults.ComponentSettings[componentKey]
            if compDefaults then
                currentValue = compDefaults[control.key]
            end
        end
        
        local callback = function(key, value)
            self:OnValueChanged(key, value)
        end
        
        -- Use Orbit Layout widgets for consistent styling
        if control.type == "slider" then
            widget = CreateSliderWidget(self.Content, control, currentValue or control.min, callback)
        elseif control.type == "checkbox" then
            widget = CreateCheckboxWidget(self.Content, control, currentValue, callback)
        elseif control.type == "font" then
            widget = CreateFontPickerWidget(self.Content, control, currentValue, callback)
        end
        
        if widget then
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -yOffset)
            widget:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", 0, -yOffset)
            widget:Show()
            
            self.widgets[widgetIndex] = widget
            yOffset = yOffset + widget:GetHeight() + WIDGET_SPACING
        end
    end
    
    -- Size dialog to fit content
    local contentHeight = yOffset + PADDING * 2 + 24  -- padding + title
    self:SetHeight(math.max(DIALOG_MIN_HEIGHT, contentHeight + 20))
    
    -- Position to the LEFT of the Canvas Mode dialog
    self:ClearAllPoints()
    local canvasDialog = Orbit.CanvasModeDialog
    if canvasDialog and canvasDialog:IsShown() then
        self:SetPoint("TOPRIGHT", canvasDialog, "TOPLEFT", -10, 0)
    elseif container then
        self:SetPoint("TOPRIGHT", container, "TOPLEFT", -10, 0)
    else
        self:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    end
    
    self:Show()
end

-- [ VALUE CHANGE HANDLER ]--------------------------------------------------------------------------

function Dialog:OnValueChanged(key, value)
    if not self.componentKey then return end
    
    -- Update current overrides
    self.currentOverrides = self.currentOverrides or {}
    self.currentOverrides[key] = value
    
    -- Store on container for Apply to pick up
    if self.container then
        self.container.pendingOverrides = self.currentOverrides
    end
    
    -- Apply preview immediately if possible
    self:PreviewChange(key, value)
end

function Dialog:PreviewChange(key, value)
    local container = self.container
    if not container or not container.visual then return end
    
    local visual = container.visual
    
    -- Apply preview based on key
    if key == "FontSize" and visual.SetFont then
        local font, _, flags = visual:GetFont()
        visual:SetFont(font, value, flags)
    elseif key == "Font" and visual.SetFont then
        local fontPath = LSM:Fetch("font", value)
        if fontPath then
            local _, size, flags = visual:GetFont()
            visual:SetFont(fontPath, size or 12, flags)
        end
    elseif key == "ShowShadow" and visual.SetShadowOffset then
        if value then
            visual:SetShadowOffset(1, -1)
            visual:SetShadowColor(0, 0, 0, 0.8)
        else
            visual:SetShadowOffset(0, 0)
        end
    elseif key == "Scale" then
        -- For textures, use SetSize (textures don't have SetScale)
        if visual.GetObjectType and visual:GetObjectType() == "Texture" then
            -- Store original size on first scale change
            if not container.originalVisualWidth then
                container.originalVisualWidth = visual:GetWidth()
                container.originalVisualHeight = visual:GetHeight()
            end
            local origW = container.originalVisualWidth or 18
            local origH = container.originalVisualHeight or 18
            
            -- Must clear all-points anchoring first (textures are set with SetAllPoints)
            visual:ClearAllPoints()
            visual:SetPoint("CENTER", container, "CENTER", 0, 0)
            visual:SetSize(origW * value, origH * value)
        elseif visual.SetScale then
            visual:SetScale(value)
        end
    end
end

-- [ EXPORT ]----------------------------------------------------------------------------------------

Orbit.CanvasComponentSettings = Dialog
OrbitEngine.CanvasComponentSettings = Dialog
