-- [ QOL CONTENT ]-----------------------------------------------------------------------------------
-- Expandable accordion sections for Quality of Life features.
local _, Orbit = ...
local Layout = Orbit.Engine.Layout
local A = Layout.Advanced
local math_floor = math.floor

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local STACK_GAP = 6

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
    -- Scrollable area
    local scrollFrame, scrollChild = Layout:CreateScrollArea(content)
    -- Section definitions: { name, builderFn }
    local sectionDefs = {
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
        section:SetParent(scrollChild)
        local body = section:GetBody()
        if def[2] then
            section:SetContentHeight(def[2](body))
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
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", 0, y)
            section:SetPoint("TOPRIGHT", 0, y)
            y = y - section:GetHeight() - A.SECTION_SPACING
        end
        scrollFrame:UpdateContentHeight(math.abs(y) + 10)
    end
    for _, section in ipairs(sections) do section._onToggle = LayoutSections end
    LayoutSections()
    return content
end
