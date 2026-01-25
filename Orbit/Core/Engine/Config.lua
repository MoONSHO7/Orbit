local _, Orbit = ...
local Engine = Orbit.Engine

---@class OrbitConfig
Engine.Config = {}
local Config = Engine.Config
local Layout = Engine.Layout

function Config:Render(dialog, systemFrame, plugin, schema, tabKey)
    local systemIndex = systemFrame.systemIndex or plugin.system or 1
    local Constants = Engine.Constants

    -- Calculate derived values from constants
    local footerHeight = Constants.Footer.TopPadding + Constants.Footer.ButtonHeight + Constants.Footer.BottomPadding
    local contentWidthWithScroll = Constants.Panel.Width
        - Constants.Panel.ScrollbarWidth
        - (Constants.Panel.ContentPadding * 2)
    local contentWidthNoScroll = Constants.Panel.Width - (Constants.Panel.ContentPadding * 2)

    -- Dynamic Header Height (Default to padding for standard plugins, or custom for Tabs)
    local headerHeight = schema.headerHeight or Constants.Panel.ContentPadding

    -- Create Overlay Panel
    if not dialog.OrbitPanel then
        local panel = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
        panel:SetWidth(Constants.Panel.Width)
        panel:SetPoint("TOP", dialog.Title, "BOTTOM", 0, -Constants.Panel.ContentPadding)

        -- Create Header Container (Fixed at Top)
        local header = CreateFrame("Frame", nil, panel)
        header:SetHeight(headerHeight)
        header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
        panel.Header = header

        -- Create ScrollFrame (Modern Template "ScrollFrameTemplate")
        panel.ScrollFrame = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
        -- Anchor Top of ScrollFrame to Bottom of Header
        panel.ScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", Constants.Panel.ContentPadding, -headerHeight)
        panel.ScrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -Constants.Panel.ScrollbarWidth, footerHeight)

        -- Create default Content (Standard view)
        local content = CreateFrame("Frame", nil, panel.ScrollFrame)
        content:SetWidth(contentWidthWithScroll)
        content:SetHeight(1) -- Opens with 1, grows with content
        panel.ScrollFrame:SetScrollChild(content)
        panel.Content = content

        panel.Tabs = {} -- Storage for cached tab containers

        -- Footer Container (Fixed at Bottom)
        local footer = CreateFrame("Frame", nil, panel)
        footer:SetHeight(footerHeight)
        footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
        footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

        panel.Footer = footer

        -- Footer Divider
        local footerDivider = footer:CreateTexture(nil, "ARTWORK")
        footerDivider:SetSize(Constants.Panel.DividerWidth, Constants.Panel.DividerHeight)
        footerDivider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
        footerDivider:SetPoint("TOP", footer, "TOP", 0, Constants.Footer.DividerOffset)

        dialog.OrbitPanel = panel
    end

    -- SAFETY: Ensure the specific Header Divider from OrbitOptionsPanel is hidden
    -- unless we are explicitly in the Orbit Options menu.
    if dialog.OrbitHeaderDivider then
        local isOrbitMenu = false
        if dialog.Title and dialog.Title:GetText() == "Orbit Options" then
            isOrbitMenu = true
        end

        -- Also check tab state in OrbitOptionsPanel as backup
        if Orbit.OptionsPanel and Orbit.OptionsPanel.currentTab then
            isOrbitMenu = true
        end

        if not isOrbitMenu then
            dialog.OrbitHeaderDivider:Hide()
        end
    end

    local panel = dialog.OrbitPanel
    panel:Show()

    -- Update Header Size (in case it changed between calls/tabs)
    if panel.Header then
        panel.Header:SetHeight(headerHeight)
    end

    -- Resolve Content Container (Tab Caching or Default)
    local targetContent

    if tabKey then
        -- Hide Default Content
        if panel.Content then
            panel.Content:Hide()
        end

        -- Hide all other cached tabs (detach from scrollframe visually)
        for k, v in pairs(panel.Tabs) do
            if k ~= tabKey then
                v:Hide()
            end
        end

        -- Get or Create Tab Container
        if not panel.Tabs[tabKey] then
            local newContent = CreateFrame("Frame", nil, panel.ScrollFrame)
            newContent:SetWidth(contentWidthWithScroll)
            newContent:SetHeight(1)
            panel.Tabs[tabKey] = newContent
        end
        targetContent = panel.Tabs[tabKey]

        -- Mark as current
        panel.CurrentTabKey = tabKey
    else
        -- Using Default Content
        targetContent = panel.Content

        -- Hide All Tabs
        if panel.Tabs then
            for _, v in pairs(panel.Tabs) do
                v:Hide()
            end
        end

        panel.CurrentTabKey = nil
    end

    targetContent:Show()
    panel.ScrollFrame:SetScrollChild(targetContent)

    -- Only Render if not already rendered (for Tabs) or if Reset forced
    -- We assume if targetContent.OrbitRendered is true, we don't need to rebuild controls
    -- Exception: Profiles tab is never cached because its content is dynamic

    local needsRender = true
    if tabKey and tabKey ~= "Profiles" and targetContent.OrbitRendered then
        needsRender = false
        targetContent:Show()
    end

    local renderedFooterHeight = footerHeight

    if needsRender then
        -- Reset Layout (only target container)
        Layout:Reset(targetContent)
        Layout:Reset(panel.Footer) -- Always reset footer as it is shared

        -- Render Settings
        local controls = schema.controls or schema
        for _, def in ipairs(controls) do
            -- Check visibleIf condition (skip if function returns false)
            local shouldRender = true
            if def.visibleIf and type(def.visibleIf) == "function" then
                shouldRender = def.visibleIf()
            end
            if shouldRender then
                self:RenderControl(targetContent, systemFrame, plugin, systemIndex, def)
            end
        end

        -- Render Footer
        renderedFooterHeight = self:RenderFooter(panel.Footer, systemFrame, plugin, systemIndex, schema)

        -- Determine Stack Height
        local height = Layout:Stack(targetContent, 0, Constants.Panel.ContentPadding)
        targetContent:SetHeight(height)
        targetContent.OrbitContentHeight = height

        targetContent.OrbitRendered = true
    else
        -- If cached, just need footer re-layout if shared footer changes?
        -- Actually, Footer IS shared, so we MUST re-render Footer every time.
        Layout:Reset(panel.Footer)
        renderedFooterHeight = self:RenderFooter(panel.Footer, systemFrame, plugin, systemIndex, schema)
    end

    -- Stack and Resize (height might be cached)
    local height = targetContent.OrbitContentHeight or targetContent:GetHeight()

    -- Update ScrollFrame bottom anchor based on new footer height
    panel.ScrollFrame:SetPoint(
        "BOTTOMRIGHT",
        panel,
        "BOTTOMRIGHT",
        -Constants.Panel.ScrollbarWidth,
        renderedFooterHeight
    )

    -- Resize Dialog to fit our content + Footer
    -- Wireframe: Max height of 800px.
    -- If usedHeight < 800, shrink fit. If > 800, cap at 800 and scroll.

    -- Tighter calculation: Content Height + Header + Footer.
    -- Removing extra padding buffer as Content Height already includes stack padding.
    local availableHeight = height + renderedFooterHeight + headerHeight
    local clampedHeight = math.min(availableHeight, Constants.Panel.MaxHeight)

    panel:SetHeight(clampedHeight)

    -- Hide scrollbar if content fits within MaxHeight and adjust padding
    local scrollbarVisible = availableHeight > Constants.Panel.MaxHeight
    if panel.ScrollFrame and panel.ScrollFrame.ScrollBar then
        panel.ScrollFrame:ClearAllPoints()
        -- Respect dynamic headerHeight for Top Anchor
        panel.ScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", Constants.Panel.ContentPadding, -headerHeight)

        if scrollbarVisible then
            panel.ScrollFrame.ScrollBar:Show()
            panel.ScrollFrame:SetPoint(
                "BOTTOMRIGHT",
                panel,
                "BOTTOMRIGHT",
                -Constants.Panel.ScrollbarWidth,
                renderedFooterHeight
            )
            targetContent:SetWidth(contentWidthWithScroll)
        else
            panel.ScrollFrame.ScrollBar:Hide()
            panel.ScrollFrame:SetPoint(
                "BOTTOMRIGHT",
                panel,
                "BOTTOMRIGHT",
                -Constants.Panel.ContentPadding,
                renderedFooterHeight
            )
            targetContent:SetWidth(contentWidthNoScroll)
        end

        -- Re-stack controls to apply new content width
        Layout:Stack(targetContent, 0, Constants.Panel.ContentPadding)
    end

    local titlePadding = Constants.Panel.TitlePadding
    local finalDialogHeight = clampedHeight + titlePadding
    dialog:SetHeight(math.max(finalDialogHeight, 150))
    dialog:SetWidth(Constants.Panel.DialogWidth)

    RunNextFrame(function()
        if dialog and dialog:IsShown() and dialog.OrbitPanel and dialog.OrbitPanel:IsShown() then
            dialog:SetHeight(math.max(finalDialogHeight, 150))
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
            return function(val)
                def.onChange(val)
            end
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
