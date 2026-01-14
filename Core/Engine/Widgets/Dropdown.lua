local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

--[[
    Dropdown Widget
    3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]
]]
function Layout:CreateDropdown(parent, label, options, initialValue, callback)
    -- Pool retrieval
    if not self.dropdownPool then
        self.dropdownPool = {}
    end
    local frame = table.remove(self.dropdownPool)

    -- Frame creation
    if not frame then
        frame = CreateFrame("Frame", nil, parent, "EditModeSettingDropdownTemplate")
        frame.OrbitType = "Dropdown"
    end

    -- Set parent
    frame:SetParent(parent)

    -- Configure control logic
    if frame.Dropdown then
        frame.currentValue = initialValue

        local function GetTextForValue(val)
            local text = tostring(val)
            for _, opt in ipairs(options) do
                if opt.value == val then
                    text = opt.text or tostring(val)
                    break
                end
            end

            if #text > 22 then
                text = string.sub(text, 1, 20) .. ".."
            end
            return text
        end

        frame.Dropdown:SetText(GetTextForValue(initialValue))

        frame.Dropdown:SetupMenu(function(dropdown, rootDescription)
            rootDescription:SetTag("OrbitDropdown")

            for _, option in ipairs(options) do
                local text = option.text or tostring(option.value)
                local value = option.value

                local radio = rootDescription:CreateRadio(text, function(data)
                    return frame.currentValue == data
                end, function(data)
                    frame.currentValue = data
                    frame.Dropdown:SetText(GetTextForValue(data))
                    if callback then
                        callback(data)
                    end
                end, value)

                if option.font then
                    radio:AddInitializer(function(button, description, menu)
                        if button.fontString then
                            button.fontString:SetFont(option.font, 14)
                        end
                    end)
                end
            end
        end)

        -- Ensure dropdown menu closes if parent is hidden/recycled
        frame:SetScript("OnHide", function()
            if frame.Dropdown then
                frame.Dropdown:CloseMenu()
            end
        end)
    end

    -- Apply 3-column layout
    local C = Engine.Constants

    if frame.Label then
        frame.Label:SetText(label)
        frame.Label:SetFontObject(Orbit.Constants.UI.LabelFont)
        frame.Label:SetWidth(C.Widget.LabelWidth)
        frame.Label:SetJustifyH("LEFT")
        frame.Label:ClearAllPoints()
        frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    end

    if frame.Dropdown then
        frame.Dropdown:ClearAllPoints()
        frame.Dropdown:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
        frame.Dropdown:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
    end

    -- Value column reserved (empty for dropdown)

    frame:SetHeight(32)
    return frame
end
