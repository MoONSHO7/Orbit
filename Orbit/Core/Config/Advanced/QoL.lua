-- [ QOL CONTENT ]-----------------------------------------------------------------------------------
-- Expandable accordion sections for Quality of Life features.
local _, Orbit = ...
local Layout = Orbit.Engine.Layout
local A = Layout.Advanced
local math_floor = math.floor

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local STACK_GAP = 6
local SEARCH_WIDTH = 200
local SEARCH_HEIGHT = 30
local SEARCH_RIGHT_INSET = 34

-- [ HELPERS ]---------------------------------------------------------------------------------------
local function FmtDecimal(v) return string.format("%.2f", v) end

local function SetAccountSetting(key, val)
    if not Orbit.db.AccountSettings then Orbit.db.AccountSettings = {} end
    Orbit.db.AccountSettings[key] = val
end

local function GetAccountSetting(key, default)
    return Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings[key] or default
end

-- [ SECTION BUILDERS ]------------------------------------------------------------------------------
-- Each builder receives the body frame and returns the computed content height.

local function BuildMoveMore(body)
    local cb = Layout:CreateCheckbox(body, "Enable Move More", nil, GetAccountSetting("MoveMore", false), function(checked)
        SetAccountSetting("MoveMore", checked)
        if checked then Orbit.MoveMore:Enable() else Orbit.MoveMore:Disable() end
    end)
    Layout:AddControl(body, cb)
    local desc = Layout:CreateDescription(body, "Drag Blizzard frames freely. Positions reset when closed.", A.MUTED)
    Layout:AddControl(body, desc)
    return Layout:Stack(body, 0, STACK_GAP)
end

local function BuildMouse(body)
    local cb = Layout:CreateCheckbox(body, "Custom Cursor Tracker", nil, GetAccountSetting("CustomCursor", false), function(checked)
        SetAccountSetting("CustomCursor", checked)
        if checked then Orbit.Mouse:Enable() else Orbit.Mouse:Disable() end
    end)
    Layout:AddControl(body, cb)
    local desc = Layout:CreateDescription(body, "Adds a custom overlay to your mouse cursor for improved visibility.", A.MUTED)
    Layout:AddControl(body, desc)
    local s1 = Layout:CreateSlider(body, "Scale", 0.1, 2.0, 0.01, FmtDecimal, GetAccountSetting("CustomCursorScale", 0.55), function(val)
        SetAccountSetting("CustomCursorScale", val)
    end)
    Layout:AddControl(body, s1)
    local s2 = Layout:CreateSlider(body, "X Offset", -5, 5, 0.1, FmtDecimal, GetAccountSetting("CustomCursorX", 2.10), function(val)
        SetAccountSetting("CustomCursorX", val)
    end)
    Layout:AddControl(body, s2)
    local s3 = Layout:CreateSlider(body, "Y Offset", -5, 5, 0.1, FmtDecimal, GetAccountSetting("CustomCursorY", 1.40), function(val)
        SetAccountSetting("CustomCursorY", val)
    end)
    Layout:AddControl(body, s3)
    local cursorMap = { [0] = "32px", [1] = "48px", [2] = "64px", [3] = "96px", [4] = "128px" }
    local startCursor = tonumber(C_CVar.GetCVar("cursorSizePreferred")) or 0
    if startCursor < 0 then startCursor = 0 end
    local s4 = Layout:CreateSlider(body, "OS Pointer Size", 0, 4, 1, function(v)
        return cursorMap[math_floor(v + 0.5)] or tostring(v)
    end, startCursor, function(val)
        C_CVar.SetCVar("cursorSizePreferred", tostring(math_floor(val + 0.5)))
    end)
    Layout:AddControl(body, s4)
    return Layout:Stack(body, 0, STACK_GAP)
end

local function BuildColors(body)
    local desc = Layout:CreateDescription(body, "Override Blizzard's native class and reaction colors across the entire interface.", A.MUTED)
    Layout:AddControl(body, desc)
    desc:SetPoint("TOPLEFT", body, "TOPLEFT", 10, -8)
    desc:SetPoint("TOPRIGHT", body, "TOPRIGHT", -10, -8)

    local yPos = -40 -- Fixed estimate since desc:GetHeight() is asynchronous
    local allPickers = {}

    local headerClasses = Layout:CreateSectionHeader(body, "Class Colors")
    Layout:AddControl(body, headerClasses)
    headerClasses:SetPoint("TOPLEFT", body, "TOPLEFT", 10, yPos)
    headerClasses:SetPoint("TOPRIGHT", body, "TOPRIGHT", -10, yPos)
    yPos = yPos - 30

    local classes = {
        "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", 
        "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", 
        "DRUID", "DEMONHUNTER", "EVOKER"
    }

    local startX = 10
    local limitsPerLine = 4
    local colWidth = 115
    local rowHeight = 35
    local padding = 5

    -- Build Classes Grid
    local CC = Orbit.Engine.ClassColor
    for i, classFile in ipairs(classes) do
        local colorData = CC:GetOverrides(classFile)
        local locClass = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] or (classFile:sub(1,1) .. classFile:sub(2):lower())

        local picker
        picker = Layout:CreateColorPicker(body, locClass, colorData, function(c)
            CC:SetOverride(classFile, c)
            if not c then
                local res = CC:GetOverrides(classFile)
                picker:SetColorQuiet(res.r, res.g, res.b, res.a)
            end
        end, { compact = true, allowClear = true })

        local dx, dy = Layout:ComputeGridPosition(i, limitsPerLine, 0, colWidth, rowHeight, padding)
        Layout:AddControl(body, picker)
        picker:SetPoint("TOPLEFT", body, "TOPLEFT", startX + dx, yPos + dy)
        allPickers[#allPickers + 1] = { type = "class", key = classFile, picker = picker }
    end

    local _, gridH = Layout:ComputeGridContainerSize(#classes, limitsPerLine, 0, colWidth, rowHeight, padding)
    yPos = yPos - gridH - 20

    local headerReactions = Layout:CreateSectionHeader(body, "Reaction Colors")
    Layout:AddControl(body, headerReactions)
    headerReactions:SetPoint("TOPLEFT", body, "TOPLEFT", 10, yPos)
    headerReactions:SetPoint("TOPRIGHT", body, "TOPRIGHT", -10, yPos)
    yPos = yPos - 30

    local RC = Orbit.Engine.ReactionColor
    local reactions = { "HOSTILE", "NEUTRAL", "FRIENDLY" }
    for i, reaction in ipairs(reactions) do
        local colorData = RC:GetOverride(reaction)
        local locReaction = reaction:sub(1,1) .. reaction:sub(2):lower()
        local picker
        picker = Layout:CreateColorPicker(body, locReaction, colorData, function(c)
            RC:SetOverride(reaction, c)
            if not c then
                local res = RC:GetOverride(reaction)
                picker:SetColorQuiet(res.r, res.g, res.b, res.a)
            end
        end, { compact = true, allowClear = true })

        local dx, dy = Layout:ComputeGridPosition(i, limitsPerLine, 0, colWidth, rowHeight, padding)
        Layout:AddControl(body, picker)
        picker:SetPoint("TOPLEFT", body, "TOPLEFT", startX + dx, yPos + dy)
        allPickers[#allPickers + 1] = { type = "reaction", key = reaction, picker = picker }
    end

    local _, gridH2 = Layout:ComputeGridContainerSize(#reactions, limitsPerLine, 0, colWidth, rowHeight, padding)
    yPos = yPos - gridH2 - 15

    -- Reset to Defaults button
    local resetBtn = Layout:CreateButton(body, "Reset to Defaults", function()
        local acct = Orbit.db and Orbit.db.AccountSettings
        if acct then
            for _, classFile in ipairs(classes) do acct["ClassColor_" .. classFile] = nil end
            for _, reaction in ipairs(reactions) do acct["ReactionColor_" .. reaction] = nil end
        end
        for _, entry in ipairs(allPickers) do
            local c = entry.type == "class" and CC:GetOverrides(entry.key) or RC:GetOverride(entry.key)
            entry.picker:SetColorQuiet(c.r, c.g, c.b, c.a)
        end
        Orbit.EventBus:Fire("COLORS_CHANGED")
    end)
    Layout:AddControl(body, resetBtn)
    resetBtn:SetPoint("TOPLEFT", body, "TOPLEFT", startX, yPos)
    yPos = yPos - 30

    return math.abs(yPos)
end

local function BuildMetaTalents(body)
    local desc = Layout:CreateDescription(body, "Displays Warcraft Logs Top 100 talent pick-rates on spell tooltips and the talent tree. Data updates weekly via CI.", A.MUTED)
    Layout:AddControl(body, desc)
    local initialState = GetAccountSetting("MetaTalentsTooltip", false) or GetAccountSetting("MetaTalentsTree", false)
    local currentState = initialState
    local reloadBtn
    local function UpdateReloadButton()
        if not reloadBtn then return end
        local dirty = currentState ~= initialState
        reloadBtn:SetEnabled(dirty)
        reloadBtn:GetFontString():SetTextColor(dirty and 1 or 0.4, dirty and 0.82 or 0.4, dirty and 0 or 0.4)
        reloadBtn:SetAlpha(dirty and 1 or 0.5)
    end
    local cb = Layout:CreateCheckbox(body, "Enable Meta Talents", nil, initialState, function(checked)
        currentState = checked
        SetAccountSetting("MetaTalentsTooltip", checked)
        SetAccountSetting("MetaTalentsTree", checked)
        if checked then C_AddOns.EnableAddOn("OrbitData") else C_AddOns.DisableAddOn("OrbitData") end
        UpdateReloadButton()
    end)
    Layout:AddControl(body, cb)
    reloadBtn = Layout:CreateButton(body, "Requires Reload", function() ReloadUI() end, 140)
    Layout:AddControl(body, reloadBtn)
    UpdateReloadButton()
    return Layout:Stack(body, 0, STACK_GAP)
end

-- [ BUILD ]-----------------------------------------------------------------------------------------
function Orbit._AC.CreateQoLContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    content:Hide()
    -- Title + subtitle (fixed, non-scrolling)
    local header = Layout:CreateSectionHeader(content, "Quality of Life")
    header:SetPoint("TOPLEFT", A.PADDING, A.TITLE_Y)
    header:SetPoint("TOPRIGHT", -A.PADDING, A.TITLE_Y)
    local desc = Layout:CreateDescription(content, "Miscellaneous quality-of-life improvements.", A.MUTED)
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)

    -- Search Box Container matches Orbit EditBox
    local searchContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    searchContainer:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
    searchContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -A.PADDING - SEARCH_RIGHT_INSET, A.TITLE_Y + 4)
    searchContainer:SetBackdrop(Layout.ORBIT_INPUT_BACKDROP)
    searchContainer:SetBackdropColor(0, 0, 0, 0.5)
    searchContainer:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local searchBox = CreateFrame("EditBox", nil, searchContainer, "SearchBoxTemplate")
    searchBox:SetPoint("TOPLEFT", searchContainer, "TOPLEFT", 8, 0)
    searchBox:SetPoint("BOTTOMRIGHT", searchContainer, "BOTTOMRIGHT", -4, 0)
    searchBox:SetFontObject(ChatFontNormal)
    searchBox:SetAutoFocus(false)
    if searchBox.Left then searchBox.Left:Hide() end
    if searchBox.Middle then searchBox.Middle:Hide() end
    if searchBox.Right then searchBox.Right:Hide() end

    -- Scrollable area
    local scrollFrame, scrollChild = Layout:CreateScrollArea(content)
    -- Section definitions: { name, builderFn }
    local sectionDefs = {
        { "Colors", BuildColors },
        { "Meta Talents", BuildMetaTalents },
        { "Move More", BuildMoveMore },
        { "Mouse", BuildMouse },
        { "Keys", nil },
        { "Markers", nil },
        { "Inventory", nil },
    }
    -- Build accordion sections
    local sections = {}
    for _, def in ipairs(sectionDefs) do
        local section = Layout:CreateAccordion(scrollChild, def[1])
        section.searchName = def[1]:lower()
        section:SetParent(scrollChild)
        local body = section:GetBody()
        if def[2] then
            section:SetContentHeight(def[2](body))
            -- Index all visible text within the section for search
            local controls = Layout.containerControls and Layout.containerControls[body]
            if controls then
                local parts = { section.searchName }
                for _, c in ipairs(controls) do
                    if c.Label and c.Label.GetText then parts[#parts + 1] = (c.Label:GetText() or ""):lower() end
                    if c.text and c.text.GetText then parts[#parts + 1] = (c.text:GetText() or ""):lower() end
                    if c.Text and c.Text.GetText then parts[#parts + 1] = (c.Text:GetText() or ""):lower() end
                end
                section.searchName = table.concat(parts, " ")
            end
        else
            local placeholder = Layout:CreateDescription(body, "No settings yet.", A.MUTED)
            Layout:AddControl(body, placeholder)
            section:SetContentHeight(Layout:Stack(body, 0, STACK_GAP))
        end
        table.insert(sections, section)
    end
    -- Layout + reflow
    local function LayoutSections()
        local y = 0
        for _, section in ipairs(sections) do
            if section:IsShown() then
                section:ClearAllPoints()
                section:SetPoint("TOPLEFT", 0, y)
                section:SetPoint("TOPRIGHT", 0, y)
                y = y - section:GetHeight() - A.SECTION_SPACING
            end
        end
        scrollFrame:UpdateContentHeight(math.abs(y) + 10)
    end
    for _, section in ipairs(sections) do section._onToggle = LayoutSections end
    LayoutSections()

    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        local query = self:GetText():lower()
        local isSearching = query ~= ""

        for _, section in ipairs(sections) do
            if isSearching then
                if string.find(section.searchName, query, 1, true) then
                    section:Show()
                    section:SetExpanded(true)
                else
                    section:Hide()
                end
            else
                section:Show()
                section:SetExpanded(false)
            end
        end
        LayoutSections()
    end)
    return content
end
