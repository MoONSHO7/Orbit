local _, Orbit = ...
local Engine = Orbit.Engine

---@class OrbitLayout
Engine.Layout = {}
local Layout = Engine.Layout

-- [ CONTROL POOLING ]-------------------------------------------------------------------------------

Layout.pool = Layout.pool or {}
Layout.sliderPool = Layout.sliderPool or {}
Layout.dropdownPool = Layout.dropdownPool or {}
Layout.buttonPool = Layout.buttonPool or {}
Layout.colorPool = Layout.colorPool or {}
Layout.fontPool = Layout.fontPool or {}
Layout.texturePool = Layout.texturePool or {}
Layout.containerControls = Layout.containerControls or {} -- Container -> List of controls

function Layout:Reset(container)
    -- Reset specific container
    local controls = self.containerControls[container]
    if controls then
        self:RecycleControls(controls)
        self.containerControls[container] = nil
    end

    -- Restore native UI if container is dialog
    if container and container.OrbitPanel then
        container.OrbitPanel:Hide()
    end

    if container and container.Buttons then
        container.Buttons:Show()
    end
    if container and container.Settings then
        container.Settings:Show()
    end

    if container and container.Layout and container.Settings and container.Settings:IsShown() then
        container:Layout()
    end
end

function Layout:RecycleControls(controls)
    if not controls then
        return
    end
    for _, control in ipairs(controls) do
        control:Hide()
        control:SetParent(nil)
        control:ClearAllPoints()

        if control.OrbitType == "Checkbox" then
            table.insert(self.pool, control)
        elseif control.OrbitType == "Slider" then
            if control.Slider and control.Slider.UnregisterCallback then
                control.Slider:UnregisterCallback("OnValueChanged", control)
            end
            control.OnOrbitChange = nil
            table.insert(self.sliderPool, control)
        elseif control.OrbitType == "Dropdown" then
            table.insert(self.dropdownPool, control)
        elseif control.OrbitType == "Button" then
            table.insert(self.buttonPool, control)
        elseif control.OrbitType == "Color" then
            table.insert(self.colorPool, control)
        elseif control.Label and control.Swatch then
            table.insert(self.colorPool, control)
        elseif control.OrbitType == "Font" then
            table.insert(self.fontPool, control)
        elseif control.OrbitType == "Texture" then
            table.insert(self.texturePool, control)
        end
    end
end

function Layout:AddControl(container, frame)
    frame:SetParent(container)
    frame:ClearAllPoints()
    frame:Show()

    -- Add to scoped list
    self.containerControls[container] = self.containerControls[container] or {}
    table.insert(self.containerControls[container], frame)
end

function Layout:Stack(container, startY, spacing)
    local y = startY or -10
    local gap = spacing or 10

    local controls = self.containerControls[container]
    if not controls then
        return 0
    end

    for _, child in ipairs(controls) do
        if child:IsShown() and child:GetParent() == container then
            child:SetPoint("TOPLEFT", container, "TOPLEFT", 10, y)
            local rightPadding = 10
            child:SetPoint("TOPRIGHT", container, "TOPRIGHT", -rightPadding, y)
            y = y - child:GetHeight() - gap
        end
    end

    return math.abs(y)
end

function Layout:ComputeGridPosition(index, limitPerLine, orientation, width, height, padding)
    -- index: 1-based index of item
    -- limitPerLine: number of items before wrapping (columns for Horizontal, rows for Vertical)
    -- orientation: 0 = Horizontal (Row-major), 1 = Vertical (Column-major)

    local row, col
    if orientation == 0 then
        -- Horizontal: Fill rows left-to-right, wrap to next row
        row = math.floor((index - 1) / limitPerLine)
        col = (index - 1) % limitPerLine
    else
        -- Vertical: Fill columns top-to-bottom, wrap to next column
        col = math.floor((index - 1) / limitPerLine)
        row = (index - 1) % limitPerLine
    end

    local x = col * (width + padding)
    local y = -row * (height + padding)

    return x, y
end

function Layout:ComputeGridContainerSize(numItems, limitPerLine, orientation, width, height, padding)
    -- numItems: Total number of items
    -- limitPerLine: number of items before wrapping (columns for Horizontal, rows for Vertical)
    -- orientation: 0 = Horizontal (Row-major), 1 = Vertical (Column-major)

    local numRows, numCols

    if orientation == 0 then
        -- Horizontal: limitPerLine is COLUMNS
        numCols = limitPerLine
        numRows = math.ceil(numItems / limitPerLine)
        -- Clamp columns to actual items if less in the last row?
        -- No, grid is strictly defined by limitPerLine cols usually, unless items < limit.
        if numItems < limitPerLine then
            numCols = numItems
        end
    else
        -- Vertical: limitPerLine is ROWS
        numRows = limitPerLine
        numCols = math.ceil(numItems / limitPerLine)
        if numItems < limitPerLine then
            numRows = numItems
        end
    end

    local finalW = (numCols * width) + ((math.max(0, numCols - 1)) * padding)
    local finalH = (numRows * height) + ((math.max(0, numRows - 1)) * padding)

    if finalW < 1 then
        finalW = width
    end
    if finalH < 1 then
        finalH = height
    end

    return finalW, finalH
end

-- [ WIDGET FACTORY ]--------------------------------------------------------------------------------

Layout.creators = {}

function Layout:RegisterWidgetType(typeName, creator)
    local normalizedType = string.lower(typeName)
    self.creators[normalizedType] = creator
end

function Layout:HasWidgetType(typeName)
    local normalizedType = string.lower(typeName)
    return self.creators[normalizedType] ~= nil
end

function Layout:CreateWidget(container, def, getValue, callback)
    if not def or not def.type then
        return nil
    end

    local normalizedType = string.lower(def.type)
    local creator = self.creators[normalizedType]

    if not creator then
        print("Orbit Layout: Unknown widget type:", def.type)
        return nil
    end

    return creator(container, def, getValue, callback)
end

function Layout:GetRegisteredTypes()
    local types = {}
    for typeName in pairs(self.creators) do
        table.insert(types, typeName)
    end
    return types
end

-- Initialize default widget creators
function Layout:InitializeWidgetTypes()
    self:RegisterWidgetType("checkbox", function(container, def, getValue, callback)
        return self:CreateCheckbox(container, def.label, def.tooltip, getValue(), callback)
    end)

    self:RegisterWidgetType("slider", function(container, def, getValue, callback)
        return self:CreateSlider(container, def.label, def.min, def.max, def.step, def.formatter, getValue(), callback)
    end)

    self:RegisterWidgetType("dropdown", function(container, def, getValue, callback)
        local options = def.options
        if type(options) == "function" then
            options = options()
        end
        return self:CreateDropdown(container, def.label, options, getValue(), callback)
    end)

    self:RegisterWidgetType("color", function(container, def, getValue, callback)
        return self:CreateColorPicker(container, def.label, getValue(), callback)
    end)

    self:RegisterWidgetType("button", function(container, def, getValue, callback)
        return self:CreateButton(container, def.text, callback, def.width)
    end)

    self:RegisterWidgetType("texture", function(container, def, getValue, callback)
        return self:CreateTexturePicker(container, def.label, getValue(), callback, def.previewColor)
    end)

    self:RegisterWidgetType("font", function(container, def, getValue, callback)
        return self:CreateFontPicker(container, def.label, getValue(), callback)
    end)

    self:RegisterWidgetType("editbox", function(container, def, getValue, callback)
        return self:CreateEditBox(container, def.label, getValue(), callback, def.width, def.height, def.multiline)
    end)

    self:RegisterWidgetType("header", function(container, def)
        local frame = CreateFrame("Frame", nil, container)
        frame:SetHeight(30)
        frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
        frame.text:SetPoint("LEFT", 0, 0)
        frame.text:SetText(def.text or def.label)
        frame.OrbitType = "Header"
        return frame
    end)

    self:RegisterWidgetType("spacer", function(container, def)
        local frame = CreateFrame("Frame", nil, container)
        frame:SetHeight(def.height or 20)
        frame.OrbitType = "Spacer"
        return frame
    end)

    self:RegisterWidgetType("label", function(container, def)
        local frame = CreateFrame("Frame", nil, container)
        frame.text = frame:CreateFontString(nil, "ARTWORK", Orbit.Constants.UI.LabelFont)
        frame.text:SetPoint("TOPLEFT", 0, 0)
        frame.text:SetJustifyH("LEFT")
        frame.text:SetWordWrap(true)
        frame.text:SetNonSpaceWrap(true)
        local containerWidth = container:GetWidth() or 300
        frame.text:SetWidth(containerWidth - 20)
        frame.text:SetText(def.text or "")
        local textHeight = frame.text:GetStringHeight()
        frame:SetHeight(math.max(20, textHeight + 4))
        frame.OrbitType = "Label"
        return frame
    end)

    self:RegisterWidgetType("description", function(container, def)
        local frame = CreateFrame("Frame", nil, container)
        frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        frame.text:SetPoint("TOPLEFT", 0, 0)
        frame.text:SetJustifyH("LEFT")
        frame.text:SetWordWrap(true)
        frame.text:SetNonSpaceWrap(true)

        -- Calculate accurate width based on Constants to avoid layout race conditions
        local C = Orbit.Constants
        local width = C.Panel.Width - (C.Panel.ContentPadding * 2) - C.Panel.ScrollbarWidth - 10

        frame.text:SetWidth(width)
        frame.text:SetText(def.text or "")

        -- Color support
        if def.color then
            frame.text:SetTextColor(def.color.r, def.color.g, def.color.b, def.color.a or 1)
        else
            frame.text:SetTextColor(0.8, 0.8, 0.8, 1)
        end

        local textHeight = frame.text:GetStringHeight()
        frame:SetHeight(math.max(20, textHeight + 8))
        frame.OrbitType = "Description"
        return frame
    end)
end

-- Initialize on load
Layout:InitializeWidgetTypes()
