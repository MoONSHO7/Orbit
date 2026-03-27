-- [ QOL CONTENT ]-----------------------------------------------------------------------------------
-- Expandable accordion sections for Quality of Life features.
local _, Orbit = ...
local Layout = Orbit.Engine.Layout
local math_floor = math.floor

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local PADDING = 16
local HEADER_HEIGHT = 40
local TITLE_Y = -(HEADER_HEIGHT + 30)
local CONTENT_START_Y = -(HEADER_HEIGHT + 80)
local QOL_SECTION_SPACING = 2
local STACK_GAP = 6
local MUTED = { r = 0.53, g = 0.53, b = 0.53 }

-- [ FORMATTERS ]------------------------------------------------------------------------------------
local function FmtDecimal(v) return string.format("%.2f", v) end

-- [ SECTION BUILDERS ]------------------------------------------------------------------------------
-- Each builder receives the body frame and returns the computed content height.

local function BuildMoveMore(body)
    local db = Orbit.db and Orbit.db.AccountSettings or {}
    local cb = Layout:CreateCheckbox(body, "Enable Move More", nil, db.MoveMore or false, function(checked)
        if not Orbit.db.AccountSettings then Orbit.db.AccountSettings = {} end
        Orbit.db.AccountSettings.MoveMore = checked
        if checked then Orbit.MoveMore:Enable() else Orbit.MoveMore:Disable() end
    end)
    Layout:AddControl(body, cb)
    local desc = Layout:CreateDescription(body, "Drag Blizzard frames freely. Positions reset when closed.", MUTED)
    Layout:AddControl(body, desc)
    return Layout:Stack(body, 0, STACK_GAP)
end

local function BuildMouse(body)
    local db = Orbit.db and Orbit.db.AccountSettings or {}
    -- Enable checkbox
    local cb = Layout:CreateCheckbox(body, "Custom Cursor Tracker", nil, db.CustomCursor or false, function(checked)
        if not Orbit.db.AccountSettings then Orbit.db.AccountSettings = {} end
        Orbit.db.AccountSettings.CustomCursor = checked
        if checked then Orbit.Mouse:Enable() else Orbit.Mouse:Disable() end
    end)
    Layout:AddControl(body, cb)
    local desc = Layout:CreateDescription(body, "Adds a custom overlay to your mouse cursor for improved visibility.", MUTED)
    Layout:AddControl(body, desc)
    -- Scale slider
    local s1 = Layout:CreateSlider(body, "Scale", 0.1, 2.0, 0.01, FmtDecimal, db.CustomCursorScale or 0.55, function(val)
        if not Orbit.db.AccountSettings then Orbit.db.AccountSettings = {} end
        Orbit.db.AccountSettings.CustomCursorScale = val
    end)
    Layout:AddControl(body, s1)
    -- X Offset slider
    local s2 = Layout:CreateSlider(body, "X Offset", -5, 5, 0.1, FmtDecimal, db.CustomCursorX or 2.10, function(val)
        if not Orbit.db.AccountSettings then Orbit.db.AccountSettings = {} end
        Orbit.db.AccountSettings.CustomCursorX = val
    end)
    Layout:AddControl(body, s2)
    -- Y Offset slider
    local s3 = Layout:CreateSlider(body, "Y Offset", -5, 5, 0.1, FmtDecimal, db.CustomCursorY or 1.40, function(val)
        if not Orbit.db.AccountSettings then Orbit.db.AccountSettings = {} end
        Orbit.db.AccountSettings.CustomCursorY = val
    end)
    Layout:AddControl(body, s3)
    -- OS Pointer Size (CVar slider)
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
    -- Title + subtitle via Layout widgets
    local header = Layout:CreateSectionHeader(content, "Quality of Life")
    header:SetPoint("TOPLEFT", PADDING, TITLE_Y)
    header:SetPoint("TOPRIGHT", -PADDING, TITLE_Y)
    local desc = Layout:CreateDescription(content, "Miscellaneous quality-of-life improvements.", MUTED)
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
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
        local section = Layout:CreateAccordion(content, def[1])
        section:SetParent(content)
        local body = section._body
        if def[2] then
            local h = def[2](body)
            section._contentHeight = h
            body:SetHeight(h)
        else
            -- Placeholder for unimplemented sections
            local placeholder = Layout:CreateDescription(body, "No settings yet.", MUTED)
            Layout:AddControl(body, placeholder)
            local h = Layout:Stack(body, 0, STACK_GAP)
            section._contentHeight = h
            body:SetHeight(h)
        end
        table.insert(sections, section)
    end
    -- Layout + reflow
    local function LayoutSections()
        local y = CONTENT_START_Y
        for _, section in ipairs(sections) do
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", PADDING, y)
            section:SetPoint("TOPRIGHT", -PADDING, y)
            y = y - section:GetHeight() - QOL_SECTION_SPACING
        end
    end
    for _, section in ipairs(sections) do section._onToggle = LayoutSections end
    LayoutSections()
    return content
end
