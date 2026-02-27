local _, Orbit = ...
local Engine = Orbit.Engine

---@class OrbitConfig
Engine.Config = {}
local Config = Engine.Config
local Layout = Engine.Layout

function Config:Render(dialog, systemFrame, plugin, schema, tabKey)
    local systemIndex = systemFrame.systemIndex or plugin.system or 1
    local Constants = Engine.Constants

    local footerHeight = Constants.Footer.TopPadding + Constants.Footer.ButtonHeight + Constants.Footer.BottomPadding
    local contentWidthWithScroll = Constants.Panel.Width - Constants.Panel.ScrollbarWidth - (Constants.Panel.ContentPadding * 2)
    local contentWidthNoScroll = Constants.Panel.Width - (Constants.Panel.ContentPadding * 2)

    local headerHeight = schema.headerHeight or Constants.Panel.ContentPadding

    if not dialog.OrbitPanel then
        local panel = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
        panel:SetWidth(Constants.Panel.Width)
        panel:SetPoint("TOP", dialog.Title, "BOTTOM", 0, -Constants.Panel.ContentPadding)

        local header = CreateFrame("Frame", nil, panel)
        header:SetHeight(headerHeight)
        header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
        panel.Header = header

        panel.ScrollFrame = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
        panel.ScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", Constants.Panel.ContentPadding, -headerHeight)
        panel.ScrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -Constants.Panel.ScrollbarWidth, footerHeight)

        local content = CreateFrame("Frame", nil, panel.ScrollFrame)
        content:SetWidth(contentWidthWithScroll)
        content:SetHeight(1) -- Opens with 1, grows with content
        panel.ScrollFrame:SetScrollChild(content)
        panel.Content = content

        panel.Tabs = {} -- Storage for cached tab containers

        local footer = CreateFrame("Frame", nil, panel)
        footer:SetHeight(footerHeight)
        footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
        footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

        panel.Footer = footer

        local footerDivider = footer:CreateTexture(nil, "ARTWORK")
        footerDivider:SetSize(Constants.Panel.DividerWidth, Constants.Panel.DividerHeight)
        footerDivider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
        footerDivider:SetPoint("TOP", footer, "TOP", 0, Constants.Footer.DividerOffset)

        dialog.OrbitPanel = panel
    end




    local panel = dialog.OrbitPanel
    panel:Show()

    if panel.Header then
        panel.Header:SetHeight(headerHeight)
    end

    local targetContent

    if tabKey then
        if panel.Content then
            panel.Content:Hide()
        end

        for k, v in pairs(panel.Tabs) do
            if k ~= tabKey then
                v:Hide()
            end
        end

        if not panel.Tabs[tabKey] then
            local newContent = CreateFrame("Frame", nil, panel.ScrollFrame)
            newContent:SetWidth(contentWidthWithScroll)
            newContent:SetHeight(1)
            panel.Tabs[tabKey] = newContent
        end
        targetContent = panel.Tabs[tabKey]

        panel.CurrentTabKey = tabKey
    else
        targetContent = panel.Content

        if panel.Tabs then
            for _, v in pairs(panel.Tabs) do
                v:Hide()
            end
        end

        panel.CurrentTabKey = nil
    end

    targetContent:Show()
    panel.ScrollFrame:SetScrollChild(targetContent)



    local needsRender = true
    if tabKey and tabKey ~= "Profiles" and tabKey ~= "Colors" and targetContent.OrbitRendered then
        needsRender = false
        targetContent:Show()
    end

    local renderedFooterHeight = footerHeight

    if needsRender then
        Layout:Reset(targetContent)
        Layout:Reset(panel.Footer)

        local controls = schema.controls or schema
        for _, def in ipairs(controls) do
            local shouldRender = true
            if def.visibleIf and type(def.visibleIf) == "function" then
                shouldRender = def.visibleIf()
            end
            if shouldRender then
                self:RenderControl(targetContent, systemFrame, plugin, systemIndex, def)
            end
        end

        renderedFooterHeight = self:RenderFooter(panel.Footer, systemFrame, plugin, systemIndex, schema)

        local height = Layout:Stack(targetContent, 0, Constants.Panel.ContentPadding)
        targetContent:SetHeight(height)
        targetContent.OrbitContentHeight = height

        targetContent.OrbitRendered = true
    else
        Layout:Reset(panel.Footer)
        renderedFooterHeight = self:RenderFooter(panel.Footer, systemFrame, plugin, systemIndex, schema)
    end

    local height = targetContent.OrbitContentHeight or targetContent:GetHeight()
    panel.ScrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -Constants.Panel.ScrollbarWidth, renderedFooterHeight)

    local availableHeight = height + renderedFooterHeight + headerHeight
    local clampedHeight = math.min(availableHeight, Constants.Panel.MaxHeight)

    panel:SetHeight(clampedHeight)

    local scrollbarVisible = availableHeight > Constants.Panel.MaxHeight
    if panel.ScrollFrame and panel.ScrollFrame.ScrollBar then
        panel.ScrollFrame:ClearAllPoints()
        panel.ScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", Constants.Panel.ContentPadding, -headerHeight)

        if scrollbarVisible then
            panel.ScrollFrame.ScrollBar:Show()
            panel.ScrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -Constants.Panel.ScrollbarWidth, renderedFooterHeight)
            targetContent:SetWidth(contentWidthWithScroll)
        else
            panel.ScrollFrame.ScrollBar:Hide()
            panel.ScrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -Constants.Panel.ContentPadding, renderedFooterHeight)
            targetContent:SetWidth(contentWidthNoScroll)
        end

        Layout:Stack(targetContent, 0, Constants.Panel.ContentPadding)
    end

    local titlePadding = Constants.Panel.TitlePadding
    local finalDialogHeight = clampedHeight + titlePadding
    dialog:SetHeight(math.max(finalDialogHeight, Constants.Panel.MinDialogHeight))
    dialog:SetWidth(Constants.Panel.DialogWidth)

    RunNextFrame(function()
        if dialog and dialog:IsShown() and dialog.OrbitPanel and dialog.OrbitPanel:IsShown() then
            dialog:SetHeight(math.max(finalDialogHeight, Constants.Panel.MinDialogHeight))
        end
    end)
end

function Config:RenderControl(container, systemFrame, plugin, systemIndex, def)
    local key = def.key
    local default = def.default

    local function GetVal()
        -- Support custom getValue for controls that read from non-standard sources
        if def.getValue then
            local val = def.getValue()
            if val == nil then
                return default
            end
            return val
        end

        local val = plugin:GetSetting(systemIndex, key)
        if val == nil then
            return default
        end
        return val
    end

    -- Helper builder for callback
    local function MakeCallback()
        if def.onChange then
            return def.onChange
        else
            return function(val)
                plugin:SetSetting(systemIndex, key, val)
                if plugin.ApplySettings then
                    plugin:ApplySettings(systemFrame)
                end
            end
        end
    end

    -- Special handling for button (different signature)
    local control
    if def.type == "button" then
        control = Layout:CreateButton(container, def.text, function(btn)
            if def.onClick then
                def.onClick(plugin, btn)
            end
        end, def.width)
    else
        -- Use Layout for all other widget types (Open/Closed Principle)
        control = Layout:CreateWidget(container, def, GetVal, MakeCallback())
    end

    if control then
        Layout:AddControl(container, control)
    end
end

function Config:RenderFooter(footer, systemFrame, plugin, systemIndex, schema)
    -- 1. Create Buttons
    local buttons = {}

    -- Default Reset Button (unless hidden by schema)
    if not schema.hideResetButton then
        local resetBtn = Layout:CreateButton(footer, "Reset to Defaults", function()
            -- Reset Logic
            if schema.controls then
                for _, def in ipairs(schema.controls) do
                    if def.key then
                        plugin:SetSetting(systemIndex, def.key, nil)
                    end
                end
            end
            if schema.onReset then
                schema.onReset()
            end

            if plugin.ApplySettings then
                plugin:ApplySettings(systemFrame)
            end

            -- Refresh UI
            local dialog = footer:GetParent():GetParent()
            Layout:Reset(dialog) -- Reset Dialog
            self:Render(dialog, systemFrame, plugin, schema)
        end)
        table.insert(buttons, resetBtn)
    end

    -- Extra Buttons
    if schema.extraButtons then
        for _, btnDef in ipairs(schema.extraButtons) do
            local b = Layout:CreateButton(footer, btnDef.text, btnDef.callback)
            table.insert(buttons, b)
        end
    end

    -- 2. Layout Logic (Stretch Grid)
    -- Max 3 per row.
    -- Row 1: 1-3 buttons.
    -- Row 2: Overflow (1-3 buttons).
    -- Rules: Buttons in a row fill the available width evenly.

    local Constants = Engine.Constants

    local buttonCount = #buttons
    local maxPerRow = 3
    local rows = math.ceil(buttonCount / maxPerRow)

    local paddingH = Constants.Footer.SidePadding
    local spacingH = Constants.Footer.ButtonSpacing
    local availableWidth = Constants.Panel.Width - (paddingH * 2)

    -- Vertical Metrics
    local topPadding = Constants.Footer.TopPadding
    local btnHeight = Constants.Footer.ButtonHeight
    local rowSpacing = Constants.Footer.RowSpacing
    local bottomPadding = Constants.Footer.BottomPadding

    local currentY = -topPadding

    for r = 1, rows do
        -- Determine buttons in this row
        local startIndex = (r - 1) * maxPerRow + 1
        local endIndex = math.min(r * maxPerRow, buttonCount)
        local countInRow = endIndex - startIndex + 1

        -- Calculate Width per button
        -- Width = (Total - (spcaing * (n-1))) / n
        local totalSpacing = spacingH * (countInRow - 1)
        local btnWidth = (availableWidth - totalSpacing) / countInRow

        local currentX = paddingH

        for i = startIndex, endIndex do
            local btn = buttons[i]
            Layout:AddControl(footer, btn)

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", footer, "TOPLEFT", currentX, currentY)
            btn:SetWidth(btnWidth)
            btn:SetHeight(btnHeight)

            currentX = currentX + btnWidth + spacingH
        end

        currentY = currentY - btnHeight - rowSpacing
    end

    -- Calculate final height
    -- currentY is negative total height used including last spacing
    -- Real used height = abs(currentY + rowSpacing) + bottomPadding
    -- Simplified: topPadding + (rows * btnHeight) + ((rows-1) * rowSpacing) + bottomPadding

    local totalHeight = topPadding + (rows * btnHeight) + (math.max(0, rows - 1) * rowSpacing) + bottomPadding

    footer:SetHeight(totalHeight)

    return totalHeight
end
