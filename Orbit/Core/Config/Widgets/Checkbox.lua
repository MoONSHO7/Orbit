local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

-- [ CHECKBOX WIDGET ]-------------------------------------------------------------------------------
function Layout:CreateCheckbox(parent, label, tooltip, initialValue, callback)
    -- Pool retrieval
    if not self.checkboxPool then
        self.checkboxPool = {}
    end
    local frame = table.remove(self.checkboxPool)

    -- Frame creation
    if not frame then
        frame = CreateFrame("Frame", nil, parent, "EditModeSettingCheckboxTemplate")
        frame.OrbitType = "Checkbox"
    end

    -- Set parent
    frame:SetParent(parent)

    -- Configure control logic
    if frame.Button then
        frame.Button:SetChecked(initialValue)
        frame.Button:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            if callback then
                callback(checked)
            end
        end)
    end

    -- Apply 3-column layout
    local C = Engine.Constants

    if frame.Button then
        -- Checkbox LEFT aligned in the Label column space
        frame.Button:ClearAllPoints()
        frame.Button:SetPoint("LEFT", frame, "LEFT", 0, 0)
    end

    if frame.Label then
        frame.Label:SetText(label)
        frame.Label:SetFontObject(Orbit.Constants.UI.LabelFont)
        -- Label now behaves like a control, allow it to span width
        frame.Label:SetWidth(0)
        frame.Label:SetJustifyH("LEFT")
        frame.Label:ClearAllPoints()
        -- Align with where sliders/dropdowns start
        frame.Label:SetPoint("LEFT", frame, "LEFT", C.Widget.LabelWidth + C.Widget.LabelGap, 0)
        frame.Label:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    end

    frame:SetHeight(30)
    return frame
end
